from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional

from app.schemas.diet_plan import DietPlanRequest, DietPlanResponse
from app.core.security import get_current_user
from app.db.database import get_db
from app.db.models import DietPlanRecord
from app.db.store import get_user_preferences
from app.services.diet_plan_engine import (
    generate_diet_plan,
    get_or_create_plan,
    apply_plan_modifications,
    suggest_replacement_meal,
)
from app.services.lab_result_service import get_lab_results_for_user

router = APIRouter()


class MealDislikeRequest(BaseModel):
    day: int
    meal_type: str
    reason: Optional[str] = None
    add_to_dislikes: bool = True


class IngredientSwapRequest(BaseModel):
    swap_from: str
    swap_to: str
    apply_to_all_days: bool = True


class PreferencesUpdate(BaseModel):
    dietary_preference: Optional[str] = None
    dislikes: Optional[List[str]] = None
    cuisine_preferences: Optional[List[str]] = None
    allergies: Optional[List[str]] = None
    regenerate_plan: bool = True


@router.get("/preferences")
async def get_preferences(current_user: dict = Depends(get_current_user)):
    prefs = get_user_preferences(int(current_user["id"]))
    return {
        "dietary_preference": prefs.get("dietary_preference", current_user.get("dietary_preference", "omnivore")),
        "dislikes": prefs.get("dislikes", []),
        "cuisine_preferences": prefs.get("cuisine_preferences", []),
        "allergies": prefs.get("allergies", current_user.get("allergies", [])),
        "favorites": prefs.get("favorites", []),
        "substitutions": prefs.get("substitutions", {}),
    }


@router.get("/current", response_model=DietPlanResponse)
async def get_current_diet_plan(current_user: dict = Depends(get_current_user)):
    return get_or_create_plan(current_user)


@router.get("/history")
async def get_diet_plan_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(DietPlanRecord)
        .filter(DietPlanRecord.user_id == int(current_user["id"]))
        .order_by(DietPlanRecord.created_at.desc())
        .all()
    )
    return [row.payload for row in rows]


@router.post("/generate", response_model=DietPlanResponse, status_code=status.HTTP_201_CREATED)
async def generate_diet_plan_endpoint(
    request: DietPlanRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user["subscription_tier"] == "basic" and request.duration_days > 7:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Basic tier limited to 7-day plans.",
        )

    # Persist preference overrides for world-class personalization
    prefs = get_user_preferences(int(current_user["id"]))
    if request.dietary_preference:
        prefs["dietary_preference"] = request.dietary_preference
        current_user = {**current_user, "dietary_preference": request.dietary_preference}
    if request.allergies:
        prefs["allergies"] = request.allergies
        current_user = {**current_user, "allergies": request.allergies}

    lab_summary = None
    if request.lab_result_id:
        labs = get_lab_results_for_user(db, int(current_user["id"]))
        lab = next((r for r in labs if r["id"] == request.lab_result_id), None)
        if lab:
            lab_summary = lab.get("interpretation", {}).get("summary")

    return generate_diet_plan(
        user=current_user,
        duration_days=request.duration_days,
        goals_override=request.goals if request.goals else None,
        lab_summary=lab_summary,
    )


@router.post("/swap-ingredient", response_model=DietPlanResponse)
async def swap_ingredient(
    request: IngredientSwapRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        return apply_plan_modifications(
            int(current_user["id"]),
            request.swap_from,
            request.swap_to,
            request.apply_to_all_days,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/dislike-meal", response_model=DietPlanResponse)
async def dislike_meal(
    request: MealDislikeRequest,
    current_user: dict = Depends(get_current_user),
):
    """Replace a meal the user doesn't like and learn the preference."""
    try:
        return suggest_replacement_meal(
            user=current_user,
            day=request.day,
            meal_type=request.meal_type,
            reason=request.reason,
            add_to_dislikes=request.add_to_dislikes,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put("/preferences")
async def update_preferences(
    request: PreferencesUpdate,
    current_user: dict = Depends(get_current_user),
):
    user_id = int(current_user["id"])
    prefs = get_user_preferences(user_id)
    if request.dietary_preference is not None:
        prefs["dietary_preference"] = request.dietary_preference
    if request.dislikes is not None:
        prefs["dislikes"] = [d.strip().lower() for d in request.dislikes if d.strip()]
    if request.cuisine_preferences is not None:
        prefs["cuisine_preferences"] = request.cuisine_preferences
    if request.allergies is not None:
        prefs["allergies"] = request.allergies

    plan = None
    if request.regenerate_plan:
        user = {
            **current_user,
            "dietary_preference": prefs.get("dietary_preference", "omnivore"),
            "allergies": prefs.get("allergies", []),
        }
        plan = generate_diet_plan(user=user, duration_days=7)

    return {
        "preferences": {
            "dietary_preference": prefs.get("dietary_preference", "omnivore"),
            "dislikes": prefs.get("dislikes", []),
            "cuisine_preferences": prefs.get("cuisine_preferences", []),
            "allergies": prefs.get("allergies", []),
            "favorites": prefs.get("favorites", []),
            "substitutions": prefs.get("substitutions", {}),
        },
        "plan_regenerated": plan is not None,
        "plan": plan,
    }


@router.get("/{plan_id}", response_model=DietPlanResponse)
async def get_diet_plan_by_id(plan_id: int, current_user: dict = Depends(get_current_user)):
    plan = get_or_create_plan(current_user)
    if plan["id"] != plan_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Diet plan not found.")
    return plan
