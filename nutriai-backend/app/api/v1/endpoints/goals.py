from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.schemas.goal import GoalListResponse, GoalPriorityUpdate, GoalAddRequest
from app.core.security import get_current_user
from app.db.database import get_db
from app.db.store import set_user_goals
from app.services.goal_service import (
    derive_goals_from_labs,
    get_goals_for_user,
    update_goal_priorities,
    add_user_goal,
    remove_user_goal,
    list_catalog_goals,
)
from app.services.lab_result_service import get_lab_results_for_user
from app.services.diet_plan_engine import generate_diet_plan

router = APIRouter()


@router.get("/catalog")
async def get_goal_catalog():
    """Preset goals users can tap — plus free-text is always allowed."""
    return {"goals": list_catalog_goals()}


@router.get("", response_model=GoalListResponse)
async def get_user_goals_endpoint(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    goals = get_goals_for_user(current_user["id"], current_user, db=db)
    return {"goals": goals, "total": len(goals)}


@router.post("/derive", response_model=GoalListResponse)
async def derive_goals_from_lab_results(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    labs = get_lab_results_for_user(db, int(current_user["id"]))
    if not labs:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No lab results yet — load labs first",
        )
    goals = derive_goals_from_labs(labs, current_user)
    set_user_goals(current_user["id"], goals)
    return {"goals": goals, "total": len(goals)}


@router.post("/add")
async def add_goal(
    request: GoalAddRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Add any goal — catalog type or free text like 'build muscle' / 'lower blood pressure' /
    'improve skin and nails' / anything new — then regenerate the meal plan around it.

    If OPENAI_API_KEY or ANTHROPIC_API_KEY is set, unknown free-text goals are interpreted
    by AI into calories/macros/tags; the catalog engine still builds the 7-day meals.
    """
    try:
        goals = add_user_goal(
            int(current_user["id"]),
            text=request.text,
            goal_type=request.goal_type,
            make_primary=request.make_primary,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    ordered = [g["goal_type"] for g in goals]
    plan = generate_diet_plan(current_user, goals_override=ordered)
    primary = next((g for g in goals if g.get("priority") == 1), goals[0] if goals else {})
    return {
        "goals": goals,
        "total": len(goals),
        "plan_regenerated": True,
        "plan_title": plan.get("title"),
        "primary_goal": plan.get("primary_goal"),
        "target_calories": plan.get("target_calories"),
        "macro_targets": plan.get("macro_targets"),
        "goal_source": primary.get("source"),
        "ai_interpreted": bool((primary.get("nutrition_profile") or {}).get("ai_interpreted")),
    }


@router.delete("/{goal_type}", response_model=GoalListResponse)
async def delete_goal(
    goal_type: str,
    current_user: dict = Depends(get_current_user),
):
    goals = remove_user_goal(int(current_user["id"]), goal_type)
    if goals:
        generate_diet_plan(current_user, goals_override=[g["goal_type"] for g in goals])
    return {"goals": goals, "total": len(goals)}


@router.put("/priorities", response_model=GoalListResponse)
async def update_priorities(
    request: GoalPriorityUpdate,
    current_user: dict = Depends(get_current_user),
):
    goals = update_goal_priorities(current_user["id"], request.ordered_goal_types)
    generate_diet_plan(current_user, goals_override=request.ordered_goal_types)
    return {"goals": goals, "total": len(goals)}
