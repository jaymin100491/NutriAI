from pydantic import BaseModel
from typing import List, Optional, Any


class GoalResponse(BaseModel):
    id: int
    user_id: Optional[int] = None
    goal_type: str
    label: Optional[str] = None
    description: Optional[str] = None
    target_value: Optional[float] = None
    current_value: Optional[float] = None
    unit: Optional[str] = ""
    status: str = "active"
    priority: int
    source: Optional[str] = None
    triggered_by: Optional[str] = None


class GoalListResponse(BaseModel):
    goals: List[GoalResponse]
    total: int


class GoalPriorityUpdate(BaseModel):
    ordered_goal_types: List[str]


class GoalDeriveRequest(BaseModel):
    lab_result_id: Optional[int] = None


class GoalAddRequest(BaseModel):
    """Add a catalog goal and/or free-text goal (e.g. 'build muscle', 'sleep better')."""
    text: Optional[str] = None
    goal_type: Optional[str] = None
    make_primary: bool = True
