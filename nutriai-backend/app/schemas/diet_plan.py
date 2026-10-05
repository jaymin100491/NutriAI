from pydantic import BaseModel
from typing import List, Dict, Optional, Any
from datetime import date


class DietPlanRequest(BaseModel):
    goals: List[str] = []
    dietary_preference: str = "omnivore"
    allergies: List[str] = []
    duration_days: int = 7
    lab_result_id: Optional[int] = None
    target_calories: Optional[int] = None
    macro_targets: Optional[Dict[str, Any]] = None


class MealPlan(BaseModel):
    day: int
    date: str
    meal_type: str
    recipe_id: int
    recipe: Optional[Dict[str, Any]] = None


class DietPlanResponse(BaseModel):
    id: int
    user_id: int
    title: str
    start_date: str
    end_date: str
    duration_days: int
    goals: List[str]
    target_calories: int
    macro_targets: Dict[str, Any]
    meals: List[MealPlan]
    shopping_list: Dict[str, List[Dict[str, str]]]
    ai_rationale: Optional[str] = None
    primary_goal: Optional[str] = None
    goal_details: Optional[List[Dict[str, Any]]] = None
    customization_count: Optional[int] = 0
    last_customization: Optional[str] = None

    class Config:
        from_attributes = True
