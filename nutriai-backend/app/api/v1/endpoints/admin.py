"""
Admin panel APIs — manage all users, labs, plans, biometrics.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import get_current_user, get_password_hash
from app.db.database import get_db
from app.db import repository as repo
from app.db.models import User, DietPlanRecord, LabResultRecord, TrackingRecord, GoalRecord
from app.services.weekly_plan_service import friday_release_next_week, generate_weekly_plan

router = APIRouter()


def require_admin(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    user = repo.get_user_by_id(db, int(current_user["id"]))
    if not user or getattr(user, "role", "user") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    if getattr(user, "is_active", True) is False:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": user.role,
        "subscription_tier": user.subscription_tier,
    }


class AdminUserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    subscription_tier: Optional[str] = None
    reset_password: Optional[str] = None


def _user_summary(user: User, db: Session) -> Dict[str, Any]:
    labs = db.query(LabResultRecord).filter(LabResultRecord.user_id == user.id).count()
    plans = db.query(DietPlanRecord).filter(DietPlanRecord.user_id == user.id).count()
    tracking = db.query(TrackingRecord).filter(TrackingRecord.user_id == user.id).count()
    goals = db.query(GoalRecord).filter(GoalRecord.user_id == user.id).count()
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": getattr(user, "role", "user") or "user",
        "is_active": getattr(user, "is_active", True),
        "subscription_tier": user.subscription_tier,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "stats": {
            "lab_results": labs,
            "diet_plans": plans,
            "tracking_entries": tracking,
            "goals": goals,
        },
    }


@router.get("/me")
async def admin_me(admin: dict = Depends(require_admin)):
    return admin


@router.get("/users")
async def list_users(
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
    q: Optional[str] = None,
):
    query = db.query(User)
    if q:
        like = f"%{q.lower()}%"
        query = query.filter(
            (User.email.ilike(like))
            | (User.first_name.ilike(like))
            | (User.last_name.ilike(like))
        )
    users = query.order_by(User.id.desc()).all()
    return {"users": [_user_summary(u, db) for u in users], "total": len(users)}


@router.get("/users/{user_id}")
async def get_user_detail(
    user_id: int,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    labs = repo.get_lab_results(db, user_id)
    plans = (
        db.query(DietPlanRecord)
        .filter(DietPlanRecord.user_id == user_id)
        .order_by(DietPlanRecord.created_at.desc())
        .all()
    )
    tracking = repo.get_tracking_entries(db, user_id, days=400)
    goals = repo.get_goals(db, user_id) or []
    prefs = repo.get_user_preferences(db, user_id)

    return {
        "user": _user_summary(user, db),
        "preferences": prefs,
        "goals": goals,
        "lab_results": labs,
        "diet_plans": [
            {
                "id": p.id,
                "is_current": p.is_current,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "payload": p.payload,
            }
            for p in plans
        ],
        "tracking": tracking,
    }


@router.patch("/users/{user_id}")
async def update_user(
    user_id: int,
    body: AdminUserUpdate,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if body.first_name is not None:
        user.first_name = body.first_name
    if body.last_name is not None:
        user.last_name = body.last_name
    if body.role is not None:
        if body.role not in ("user", "admin"):
            raise HTTPException(status_code=400, detail="role must be user or admin")
        user.role = body.role
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.subscription_tier is not None:
        user.subscription_tier = body.subscription_tier
    if body.reset_password:
        user.password_hash = get_password_hash(body.reset_password)
    db.commit()
    db.refresh(user)
    return _user_summary(user, db)


@router.post("/users/{user_id}/generate-week")
async def admin_generate_week(
    user_id: int,
    next_week: bool = False,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    payload = {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "subscription_tier": user.subscription_tier,
        "dietary_preference": "omnivore",
        "allergies": [],
    }
    plan = friday_release_next_week(payload) if next_week else generate_weekly_plan(payload)
    return {"plan": plan, "message": "Weekly plan generated"}


@router.get("/stats")
async def admin_stats(admin: dict = Depends(require_admin), db: Session = Depends(get_db)):
    return {
        "users": db.query(User).count(),
        "active_users": db.query(User).filter(User.is_active.is_(True)).count(),
        "lab_results": db.query(LabResultRecord).count(),
        "diet_plans": db.query(DietPlanRecord).count(),
        "tracking_entries": db.query(TrackingRecord).count(),
    }
