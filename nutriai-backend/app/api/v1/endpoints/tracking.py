from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from app.schemas.tracking import TrackingCreate, TrackingResponse, ProgressResponse
from app.core.security import get_current_user
from app.db.database import get_db
from app.db import repository as repo

router = APIRouter()


def _normalize_entry(user_id: int, data: dict, entry_id: Optional[int] = None) -> dict:
    mood = data.get("mood")
    if isinstance(mood, str):
        mood_map = {"poor": 2, "fair": 4, "good": 6, "great": 8, "excellent": 10}
        mood = mood_map.get(mood.lower(), 5)
    glucose = data.get("blood_glucose")
    if glucose is None:
        glucose = data.get("glucose_mg_dl")
    return {
        "id": entry_id or data.get("id") or 0,
        "user_id": user_id,
        "date": data["date"],
        "weight_lbs": data.get("weight_lbs"),
        "systolic_bp": data.get("systolic_bp"),
        "diastolic_bp": data.get("diastolic_bp"),
        "blood_glucose": glucose,
        "water_intake_oz": data.get("water_intake_oz"),
        "sleep_hours": data.get("sleep_hours"),
        "exercise_minutes": data.get("exercise_minutes"),
        "mood": mood,
        "notes": data.get("notes"),
        "adherence_percent": data.get("adherence_percent"),
        "source": data.get("source", "manual"),
        "milestone": data.get("milestone"),
    }


@router.post("/daily", response_model=TrackingResponse, status_code=status.HTTP_201_CREATED)
async def add_daily_tracking(
    tracking_data: TrackingCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    raw = tracking_data.model_dump() if hasattr(tracking_data, "model_dump") else tracking_data.dict()
    # Accept Flutter field names
    if raw.get("blood_glucose") is None and raw.get("glucose_mg_dl") is not None:
        raw["blood_glucose"] = raw["glucose_mg_dl"]
    entry = _normalize_entry(int(current_user["id"]), raw)
    entry["adherence_percent"] = entry.get("adherence_percent") or 85.0
    entry["source"] = "manual"
    saved = repo.upsert_tracking_entry(db, int(current_user["id"]), entry)
    return saved


@router.get("/daily", response_model=list[TrackingResponse])
async def get_daily_tracking(
    days: int = 1500,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entries = repo.get_tracking_entries(db, int(current_user["id"]), days=days)
    return [_normalize_entry(int(current_user["id"]), e, e.get("id")) for e in entries]


@router.get("/progress", response_model=ProgressResponse)
async def get_progress(
    days: int = 1500,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    entries = repo.get_tracking_entries(db, user_id, days=days)
    if not entries:
        raise HTTPException(status_code=404, detail="No biometric history yet")

    weights = [e["weight_lbs"] for e in entries if e.get("weight_lbs") is not None]
    glucoses = [e["blood_glucose"] for e in entries if e.get("blood_glucose") is not None]
    moods = [e["mood"] for e in entries if isinstance(e.get("mood"), (int, float))]
    systolic = [e["systolic_bp"] for e in entries if e.get("systolic_bp") is not None]

    weight_change = round(weights[-1] - weights[0], 1) if len(weights) >= 2 else 0.0
    bp_change = round(systolic[-1] - systolic[0], 1) if len(systolic) >= 2 else 0.0
    glucose_change = round(glucoses[-1] - glucoses[0], 1) if len(glucoses) >= 2 else 0.0

    # Lab marker improvements from stored labs (LDL / A1c)
    labs = repo.get_lab_results(db, user_id)
    ldl_series = []
    a1c_series = []
    for lab in sorted(labs, key=lambda r: r.get("test_date") or ""):
        for t in lab.get("results", {}).get("tests", []):
            name = (t.get("name") or "").lower()
            val = t.get("value")
            if not isinstance(val, (int, float)):
                continue
            if name.startswith("ldl") and "vldl" not in name:
                ldl_series.append({"date": lab["test_date"], "value": val})
            if "hemoglobin a1c" in name or name.strip() in ("a1c", "hba1c"):
                a1c_series.append({"date": lab["test_date"], "value": val})
            elif "a1c" in name and "please" not in name:
                a1c_series.append({"date": lab["test_date"], "value": val})

    highlights = []
    if len(weights) >= 2:
        highlights.append(f"Weight {weights[0]:.0f} → {weights[-1]:.0f} lbs ({weight_change:+.1f})")
    if len(systolic) >= 2:
        highlights.append(f"Systolic BP {systolic[0]} → {systolic[-1]} ({bp_change:+.0f})")
    if len(glucoses) >= 2:
        highlights.append(f"Glucose {glucoses[0]} → {glucoses[-1]} mg/dL ({glucose_change:+.0f})")
    if len(ldl_series) >= 2:
        highlights.append(f"LDL {ldl_series[0]['value']} → {ldl_series[-1]['value']} mg/dL")
    if len(a1c_series) >= 2:
        highlights.append(f"A1c {a1c_series[0]['value']}% → {a1c_series[-1]['value']}%")

    tracking_data = [
        {
            "id": e.get("id", 0),
            "user_id": user_id,
            "date": e["date"],
            "weight_lbs": e.get("weight_lbs"),
            "systolic_bp": e.get("systolic_bp"),
            "diastolic_bp": e.get("diastolic_bp"),
            "blood_glucose": e.get("blood_glucose"),
            "mood": e.get("mood") if isinstance(e.get("mood"), int) else None,
            "notes": e.get("notes"),
            "milestone": e.get("milestone"),
            "source": e.get("source"),
        }
        for e in entries
    ]

    return {
        "tracking_data": tracking_data,
        "weight_change": weight_change,
        "avg_adherence": 0,
        "days_tracked": len(entries),
        "avg_blood_glucose": round(sum(glucoses) / len(glucoses), 1) if glucoses else None,
        "avg_mood": round(sum(moods) / len(moods), 1) if moods else None,
        "bp_change": bp_change,
        "glucose_change": glucose_change,
        "highlights": highlights,
        "lab_markers": {"ldl": ldl_series, "a1c": a1c_series},
        "story": (
            "Biometrics improved alongside your NutriAI meal plans between lab draws. "
            "Each milestone marks a plan period or wellness checkup."
            if highlights
            else "Log metrics regularly to see trends."
        ),
    }
