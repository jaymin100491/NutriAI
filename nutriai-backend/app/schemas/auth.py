from pydantic import BaseModel, EmailStr
from typing import Optional


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


class AuthResponse(BaseModel):
    user: dict
    tokens: TokenResponse
    okta_access_token: Optional[str] = None


class OktaAuthorizeResponse(BaseModel):
    authorization_url: str
    state: str
    redirect_uri: str


class OktaCallbackRequest(BaseModel):
    code: str
    state: str
