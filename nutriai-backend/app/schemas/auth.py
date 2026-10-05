from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=4, max_length=128)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(default="", max_length=100)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


class AuthResponse(BaseModel):
    user: dict
    tokens: TokenResponse
    okta_access_token: Optional[str] = None
    needs_lab_import: bool = False


class RefreshRequest(BaseModel):
    refresh_token: str


class OktaAuthorizeResponse(BaseModel):
    authorization_url: str
    state: str
    redirect_uri: str


class OktaCallbackRequest(BaseModel):
    code: str
    state: str
