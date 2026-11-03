from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional
from app.schemas.recipe import RecipeResponse, RecipeListResponse
from app.core.security import get_current_user
from app.services.recipe_catalog import get_recipe_by_id, search_recipes

router = APIRouter()


@router.get("", response_model=RecipeListResponse)
async def get_recipes(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    dietary_type: Optional[str] = None,
    meal_type: Optional[str] = None,
    health_goal: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """Get recipes from catalog of 1,500+ personalized options."""
    result = search_recipes(
        meal_type=meal_type,
        dietary_type=dietary_type,
        health_goal=health_goal,
        exclude_allergens=current_user.get("allergies"),
        page=page,
        limit=limit,
    )
    return result


@router.get("/search/{query}", response_model=RecipeListResponse)
async def search_recipes_endpoint(
    query: str,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    meal_type: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """Search 1,500+ recipes by name, ingredient, or description."""
    return search_recipes(
        query=query,
        meal_type=meal_type,
        exclude_allergens=current_user.get("allergies"),
        page=page,
        limit=limit,
    )


@router.get("/favorites")
async def get_favorite_recipes(current_user: dict = Depends(get_current_user)):
    """Favorite recipes for the current user (empty list until favorites UX is wired)."""
    # Must be declared before /{recipe_id} so "favorites" is not parsed as an int.
    return []


@router.post("/{recipe_id}/favorite")
async def toggle_favorite_recipe(
    recipe_id: int,
    current_user: dict = Depends(get_current_user),
):
    """Toggle favorite — stub success for demo clients."""
    recipe = get_recipe_by_id(recipe_id)
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipe not found",
        )
    return {"ok": True, "recipe_id": recipe_id, "favorited": True}


@router.get("/{recipe_id}", response_model=RecipeResponse)
async def get_recipe_detail(
    recipe_id: int,
    current_user: dict = Depends(get_current_user),
):
    """Get detailed recipe information (catalog, professional, or current plan embed)."""
    recipe = get_recipe_by_id(recipe_id)
    if not recipe:
        # Fall back to recipe embedded in the user's current diet plan (AI / plan-only ids)
        try:
            from app.db.store import get_user_plan

            plan = get_user_plan(int(current_user["id"])) or {}
            for meal in plan.get("meals") or []:
                if int(meal.get("recipe_id") or 0) == recipe_id and meal.get("recipe"):
                    recipe = meal["recipe"]
                    break
        except Exception:
            recipe = None
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipe not found",
        )
    return recipe
