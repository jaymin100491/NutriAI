from pydantic import BaseModel, Field
from typing import Optional, List, Any, Union


class TrackingCreate(BaseModel):
    date: str
    weight_lbs: Optional[float] = None
    systolic_bp: Optional[int] = None
    diastolic_bp: Optional[int] = None
    glucose_mg_dl: Optional[int] = None
    blood_glucose: Optional[int] = None
    water_intake_oz: Optional[int] = None
    sleep_hours: Optional[float] = None
    exercise_minutes: Optional[int] = None
    mood: Optional[Union[int, str]] = None
    notes: Optional[str] = None
    adherence_percent: Optional[float] = None
    milestone: Optional[str] = None
    source: Optional[str] = None


class TrackingResponse(BaseModel):
    id: int
    user_id: int
    date: str
    weight_lbs: Optional[float] = None
    systolic_bp: Optional[int] = None
    diastolic_bp: Optional[int] = None
    blood_glucose: Optional[int] = None
    water_intake_oz: Optional[int] = None
    sleep_hours: Optional[float] = None
    exercise_minutes: Optional[int] = None
    mood: Optional[Union[int, str]] = None
    notes: Optional[str] = None
    adherence_percent: Optional[float] = None
    milestone: Optional[str] = None
    source: Optional[str] = None

    class Config:
        from_attributes = True


class ProgressDataPoint(BaseModel):
    id: int = 0
    user_id: int = 0
    date: str
    weight_lbs: Optional[float] = None
    systolic_bp: Optional[int] = None
    diastolic_bp: Optional[int] = None
    blood_glucose: Optional[int] = None
    mood: Optional[int] = None
    notes: Optional[str] = None
    milestone: Optional[str] = None
    source: Optional[str] = None


class ProgressResponse(BaseModel):
    tracking_data: List[ProgressDataPoint]
    weight_change: float
    avg_adherence: float = 0
    days_tracked: int
    avg_blood_glucose: Optional[float] = None
    avg_mood: Optional[float] = None
    bp_change: Optional[float] = None
    glucose_change: Optional[float] = None
    highlights: List[str] = Field(default_factory=list)
    lab_markers: dict = Field(default_factory=dict)
    story: Optional[str] = None
