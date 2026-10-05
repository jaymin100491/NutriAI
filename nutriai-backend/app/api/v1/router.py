from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth,
    users,
    lab_results,
    diet_plans,
    tracking,
    recipes,
    goals,
    chat,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(lab_results.router, prefix="/lab-results", tags=["Lab Results"])
api_router.include_router(diet_plans.router, prefix="/diet-plans", tags=["Diet Plans"])
api_router.include_router(tracking.router, prefix="/tracking", tags=["Tracking"])
api_router.include_router(recipes.router, prefix="/recipes", tags=["Recipes"])
api_router.include_router(goals.router, prefix="/goals", tags=["Health Goals"])
api_router.include_router(chat.router, prefix="/chat", tags=["AI Dietitian Chat"])
