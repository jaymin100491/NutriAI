from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta
import secrets

from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    OktaAuthorizeResponse,
    OktaCallbackRequest,
    SignupRequest,
    TokenResponse,
)
from app.core.security import (
    create_access_token,
    get_current_user,
    get_password_hash,
    verify_password,
)
from app.core.config import settings
from app.db.database import get_db
from app.db import repository as repo
from app.db.mock_data import MOCK_USERS
from app.services.okta_service import (
    build_authorization_url,
    exchange_code_for_tokens,
    generate_pkce_pair,
    portal_login,
)

router = APIRouter()

# Short-lived PKCE state store (use Redis in production)
_pkce_store: dict[str, str] = {}


def _issue_tokens(user) -> dict:
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "email": user.email,
            "subscription_tier": user.subscription_tier,
        },
        expires_delta=access_token_expires,
    )
    refresh_token = create_access_token(
        data={"sub": str(user.id), "type": "refresh"},
        expires_delta=timedelta(days=7),
    )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


def _user_payload(user) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "subscription_tier": user.subscription_tier,
        "labcorp_patient_id": user.labcorp_patient_id,
    }


def _needs_lab_import(db: Session, user_id: int) -> bool:
    return len(repo.get_lab_results(db, user_id)) == 0


@router.get("/okta/authorize", response_model=OktaAuthorizeResponse)
async def okta_authorize():
    """
    Start Okta PKCE login — same redirect URI as patient-website-ui QA.
    Flutter web on https://patient-local.labcorp.com:4200/callback
    """
    state = secrets.token_urlsafe(24)
    code_verifier, code_challenge = generate_pkce_pair()
    _pkce_store[state] = code_verifier

    return {
        "authorization_url": build_authorization_url(state, code_challenge),
        "state": state,
        "redirect_uri": settings.OKTA_REDIRECT_URI,
    }


@router.post("/okta/callback", response_model=AuthResponse)
async def okta_callback(request: OktaCallbackRequest, db: Session = Depends(get_db)):
    """Exchange Okta auth code for NutriAI session + Labcorp portal session."""
    code_verifier = _pkce_store.pop(request.state, None)
    if not code_verifier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired login state — restart sign-in",
        )

    try:
        token_payload = await exchange_code_for_tokens(request.code, code_verifier)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Okta token exchange failed: {exc}",
        ) from exc

    access_token = token_payload.get("access_token")
    if not access_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No access token from Okta")

    try:
        portal_patient, portal_cookies = await portal_login(access_token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Labcorp portal login failed: {exc}",
        ) from exc

    email = portal_patient.get("loginEmail") or portal_patient.get("email") or "patient@labcorp.com"
    okta_sub = str(portal_patient.get("id") or email)

    user = repo.upsert_okta_user(
        db,
        okta_sub=okta_sub,
        email=email,
        first_name=portal_patient.get("firstName"),
        last_name=portal_patient.get("lastName"),
        access_token=access_token,
        portal_patient=portal_patient,
        portal_cookies=portal_cookies,
    )

    return {
        "user": _user_payload(user),
        "tokens": _issue_tokens(user),
        "okta_access_token": access_token,
        "needs_lab_import": _needs_lab_import(db, user.id),
    }


@router.post("/signup", response_model=AuthResponse)
async def signup(request: SignupRequest, db: Session = Depends(get_db)):
    """Create an account — next step is paste lab results into NutriAI."""
    email = request.email.strip().lower()
    if repo.get_user_by_email(db, email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists. Please sign in.",
        )

    user = repo.create_password_user(
        db,
        email=email,
        password_hash=get_password_hash(request.password),
        first_name=request.first_name,
        last_name=request.last_name,
    )
    return {
        "user": _user_payload(user),
        "tokens": _issue_tokens(user),
        "needs_lab_import": True,
    }


@router.post("/login", response_model=AuthResponse)
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Email/password login. Demo account works when DEMO_MODE=true."""
    from app.db.models import User as UserModel
    from app.db.seed_demo import DEMO_EMAIL, DEMO_PASSWORD_HINT, seed_demo_workspace

    email = request.email.strip().lower()
    password = request.password

    if settings.DEMO_MODE and email == DEMO_EMAIL:
        if password != DEMO_PASSWORD_HINT:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
            )
        db_user = seed_demo_workspace(db)
        if not db_user.password_hash:
            db_user.password_hash = get_password_hash(DEMO_PASSWORD_HINT)
            db.commit()
            db.refresh(db_user)
        return {
            "user": _user_payload(db_user),
            "tokens": _issue_tokens(db_user),
            "needs_lab_import": False,
        }

    db_user = repo.get_user_by_email(db, email)
    if db_user and db_user.password_hash:
        if not verify_password(password, db_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
            )
        return {
            "user": _user_payload(db_user),
            "tokens": _issue_tokens(db_user),
            "needs_lab_import": _needs_lab_import(db, db_user.id),
        }

    if settings.DEMO_MODE:
        user = next((u for u in MOCK_USERS if u["email"].lower() == email), None)
        if user:
            if not db_user:
                db_user = UserModel(
                    email=user["email"],
                    first_name=user["first_name"],
                    last_name=user["last_name"],
                    subscription_tier=user["subscription_tier"],
                    password_hash=get_password_hash(password),
                )
                db.add(db_user)
                db.commit()
                db.refresh(db_user)
            return {
                "user": _user_payload(db_user),
                "tokens": _issue_tokens(db_user),
                "needs_lab_import": _needs_lab_import(db, db_user.id),
            }

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect email or password",
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    from app.core.security import decode_token

    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user = repo.get_user_by_id(db, int(payload.get("sub")))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    tokens = _issue_tokens(user)
    return tokens


@router.get("/me")
async def auth_me(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = repo.get_user_by_id(db, int(current_user["id"]))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    payload = _user_payload(user)
    payload["needs_lab_import"] = _needs_lab_import(db, user.id)
    return payload
