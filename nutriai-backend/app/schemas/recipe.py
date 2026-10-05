from pydantic import BaseModel
from typing import List, Dict, Optional


class RecipeIngredient(BaseModel):
    item: str
    quantity: str
    unit: str
    notes: Optional[str] = ""


class RecipeNutrition(BaseModel):
    calories: int
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    sugar_g: float
    sodium_mg: int
    cholesterol_mg: int


class RecipeResponse(BaseModel):
    id: int
    name: str
    slug: str
    description: str
    cuisine_type: str
    meal_type: List[str]
    dietary_tags: List[str]
    health_tags: List[str]
    prep_time_minutes: int
    cook_time_minutes: int
    servings: int
    difficulty: str
    image_url: str
    ingredients: List[RecipeIngredient]
    instructions: List[str]
    nutrition: RecipeNutrition

    class Config:
        from_attributes = True


class RecipeListResponse(BaseModel):
    recipes: List[RecipeResponse]
    total: int
    page: int
    limit: int
