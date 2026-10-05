"""
Okta PKCE + Labcorp patient portal session management.
Mirrors patient-website-ui auth flow against QA environment.
"""
from __future__ import annotations

import base64
import hashlib
import json
import secrets
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlencode

import httpx

from app.core.config import settings
from app.core.crypto import decrypt_value, encrypt_value


def generate_pkce_pair() -> Tuple[str, str]:
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip("=")
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).decode().rstrip("=")
    return verifier, challenge


def build_authorization_url(state: str, code_challenge: str) -> str:
    params = {
        "client_id": settings.OKTA_CLIENT_ID,
        "response_type": "code",
        "scope": settings.OKTA_SCOPES,
        "redirect_uri": settings.OKTA_REDIRECT_URI,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    return f"{settings.OKTA_ISSUER}/v1/authorize?{urlencode(params)}"


async def exchange_code_for_tokens(code: str, code_verifier: str) -> Dict[str, Any]:
    token_url = f"{settings.OKTA_ISSUER}/v1/token"
    data = {
        "grant_type": "authorization_code",
        "client_id": settings.OKTA_CLIENT_ID,
        "redirect_uri": settings.OKTA_REDIRECT_URI,
        "code": code,
        "code_verifier": code_verifier,
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            token_url,
            data=data,
            headers={"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"},
        )
        response.raise_for_status()
        return response.json()


async def portal_login(access_token: str) -> Tuple[Dict[str, Any], httpx.Cookies]:
    """Establish portal-api session — same as patient portal POST /login."""
    url = f"{settings.LABCORP_PORTAL_API_URL}/protected/patients/current/login"
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        response.raise_for_status()
        return response.json(), response.cookies


def serialize_cookies(cookies: httpx.Cookies) -> str:
    items = []
    for cookie in cookies.jar:
        items.append(
            {
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain or "",
                "path": cookie.path or "/",
            }
        )
    return encrypt_value(json.dumps(items))


def deserialize_cookies(encoded: str) -> httpx.Cookies:
    raw = json.loads(decrypt_value(encoded))
    cookies = httpx.Cookies()
    portal_host = httpx.URL(settings.LABCORP_PORTAL_API_URL).host

    # Legacy name -> value map from earlier builds
    if isinstance(raw, dict):
        for name, value in raw.items():
            cookies.set(name, value, domain=portal_host, path="/")
        return cookies

    for item in raw:
        domain = item.get("domain") or portal_host
        cookies.set(
            item["name"],
            item["value"],
            domain=domain,
            path=item.get("path", "/"),
        )
    return cookies


def build_cookie_header(cookies: httpx.Cookies) -> str:
    return "; ".join(f"{cookie.name}={cookie.value}" for cookie in cookies.jar)


def encrypt_access_token(token: str) -> str:
    return encrypt_value(token)


def decrypt_access_token(enc: str) -> str:
    return decrypt_value(enc)
