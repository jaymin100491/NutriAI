from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.user import UserResponse, UserUpdate
from app.core.security import get_current_user
from app.db.mock_data import MOCK_USERS

router = APIRouter()


@router.get("/profile", response_model=UserResponse)
async def get_user_profile(current_user: dict = Depends(get_current_user)):
    """Get current user profile."""
    user = next((u for u in MOCK_USERS if u["id"] == current_user["id"]), None)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user


@router.put("/profile", response_model=UserResponse)
async def update_user_profile(
    update_data: UserUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update user profile."""
    user = next((u for u in MOCK_USERS if u["id"] == current_user["id"]), None)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Update user data
    update_dict = update_data.dict(exclude_unset=True)
    for key, value in update_dict.items():
        if key in user:
            user[key] = value

    return user


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current authenticated user information."""
    user = next((u for u in MOCK_USERS if u["id"] == current_user["id"]), None)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user
