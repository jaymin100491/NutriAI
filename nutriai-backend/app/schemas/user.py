from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime


class UserBase(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str


class UserCreate(UserBase):
    password: str
    date_of_birth: str
    gender: Optional[str] = None
    height_inches: Optional[float] = None


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    dietary_preference: Optional[str] = None
    allergies: Optional[List[str]] = None
    medical_conditions: Optional[List[str]] = None


class UserResponse(UserBase):
    id: int
    date_of_birth: str
    gender: Optional[str]
    height_inches: Optional[float]
    current_weight_lbs: Optional[float]
    subscription_tier: str
    dietary_preference: str
    allergies: List[str]
    medical_conditions: List[str]
    created_at: str

    class Config:
        from_attributes = True


class UserProfile(UserResponse):
    """Extended user profile with additional details."""
    pass
