"""
Admin panel APIs — manage all users, labs, plans, biometrics.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta
from statistics import mean
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import get_current_user, get_password_hash
from app.db.database import get_db
from app.db import repository as repo
from app.db.models import User, DietPlanRecord, LabResultRecord, TrackingRecord, GoalRecord
from app.services.weekly_plan_service import friday_release_next_week, generate_weekly_plan

router = APIRouter()


def _num(entry: Dict[str, Any], *keys: str) -> Optional[float]:
    for key in keys:
        val = entry.get(key)
        if val is None:
            continue
        try:
            return float(val)
        except (TypeError, ValueError):
            continue
    return None


def _monday(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _parse_day(value: Any) -> Optional[date]:
    if not value:
        return None
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def build_biometric_summary(tracking: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Daily + weekly biometric rollups for admin patient workspace."""
    daily = sorted(
        [dict(e) for e in tracking if isinstance(e, dict)],
        key=lambda e: str(e.get("date") or ""),
        reverse=True,
    )
    chron = list(reversed(daily))
    latest = daily[0] if daily else None
    prior = daily[1] if len(daily) > 1 else None

    def delta(key: str) -> Optional[float]:
        if not latest or not prior:
            return None
        a = _num(latest, key)
        b = _num(prior, key)
        if a is None or b is None:
            return None
        return round(a - b, 2)

    weeks: Dict[str, List[Dict[str, Any]]] = {}
    for entry in chron:
        day = _parse_day(entry.get("date"))
        if not day:
            continue
        start = _monday(day)
        weeks.setdefault(start.isoformat(), []).append(entry)

    weekly: List[Dict[str, Any]] = []
    for start_s, rows in sorted(weeks.items(), key=lambda x: x[0], reverse=True):
        start = date.fromisoformat(start_s)
        end = start + timedelta(days=6)

        def avg_of(*keys: str) -> Optional[float]:
            vals = [_num(r, *keys) for r in rows]
            vals = [v for v in vals if v is not None]
            return round(mean(vals), 2) if vals else None

        weekly.append(
            {
                "week_start": start.isoformat(),
                "week_end": end.isoformat(),
                "label": f"{start.strftime('%b %d')} – {end.strftime('%b %d, %Y')}",
                "entries": len(rows),
                "avg_weight_lbs": avg_of("weight_lbs", "weight"),
                "avg_systolic_bp": avg_of("systolic_bp", "systolic"),
                "avg_diastolic_bp": avg_of("diastolic_bp", "diastolic"),
                "avg_blood_glucose": avg_of("blood_glucose", "glucose"),
                "avg_sleep_hours": avg_of("sleep_hours", "sleep"),
                "avg_adherence_percent": avg_of("adherence_percent", "adherence"),
                "avg_mood": avg_of("mood"),
            }
        )

    first = chron[0] if chron else None
    last = chron[-1] if chron else None

    def span_delta(key: str) -> Optional[float]:
        if not first or not last:
            return None
        a = _num(last, key)
        b = _num(first, key)
        if a is None or b is None:
            return None
        return round(a - b, 2)

    return {
        "entry_count": len(daily),
        "latest": latest,
        "prior": prior,
        "first": first,
        "deltas": {
            "vs_prior": {
                "weight_lbs": delta("weight_lbs"),
                "systolic_bp": delta("systolic_bp"),
                "diastolic_bp": delta("diastolic_bp"),
                "blood_glucose": delta("blood_glucose"),
                "sleep_hours": delta("sleep_hours"),
                "adherence_percent": delta("adherence_percent"),
            },
            "vs_baseline": {
                "weight_lbs": span_delta("weight_lbs"),
                "systolic_bp": span_delta("systolic_bp"),
                "diastolic_bp": span_delta("diastolic_bp"),
                "blood_glucose": span_delta("blood_glucose"),
                "adherence_percent": span_delta("adherence_percent"),
            },
        },
        "weekly": weekly,
        "daily": daily,
    }


def require_admin(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    user = repo.get_user_by_id(db, int(current_user["id"]))
    if not user or getattr(user, "role", "user") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    if getattr(user, "is_active", True) is False:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": user.role,
        "subscription_tier": user.subscription_tier,
    }


class AdminUserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    subscription_tier: Optional[str] = None
    reset_password: Optional[str] = None


def _user_summary(user: User, db: Session) -> Dict[str, Any]:
    labs = db.query(LabResultRecord).filter(LabResultRecord.user_id == user.id).count()
    plans = db.query(DietPlanRecord).filter(DietPlanRecord.user_id == user.id).count()
    tracking_q = db.query(TrackingRecord).filter(TrackingRecord.user_id == user.id)
    tracking = tracking_q.count()
    goals = db.query(GoalRecord).filter(GoalRecord.user_id == user.id).count()
    latest_track = tracking_q.order_by(TrackingRecord.date.desc()).first()
    latest_payload = (latest_track.payload if latest_track else None) or {}
    prefs = repo.get_user_preferences(db, user.id) or {}
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": getattr(user, "role", "user") or "user",
        "is_active": getattr(user, "is_active", True),
        "subscription_tier": user.subscription_tier,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "outcome_arc": prefs.get("outcome_arc"),
        "retest_ready": bool(prefs.get("retest_ready")),
        "dietary_preference": prefs.get("dietary_preference"),
        "last_checkin": latest_track.date if latest_track else None,
        "latest_weight_lbs": _num(latest_payload, "weight_lbs", "weight"),
        "latest_systolic_bp": _num(latest_payload, "systolic_bp", "systolic"),
        "latest_glucose": _num(latest_payload, "blood_glucose", "glucose"),
        "stats": {
            "lab_results": labs,
            "diet_plans": plans,
            "tracking_entries": tracking,
            "goals": goals,
        },
    }


@router.get("/me")
async def admin_me(admin: dict = Depends(require_admin)):
    return admin


@router.get("/users")
async def list_users(
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
    q: Optional[str] = None,
):
    query = db.query(User)
    if q:
        like = f"%{q.lower()}%"
        query = query.filter(
            (User.email.ilike(like))
            | (User.first_name.ilike(like))
            | (User.last_name.ilike(like))
        )
    users = query.order_by(User.id.desc()).all()
    return {"users": [_user_summary(u, db) for u in users], "total": len(users)}


@router.get("/users/{user_id}")
async def get_user_detail(
    user_id: int,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    labs = repo.get_lab_results(db, user_id)
    plans = (
        db.query(DietPlanRecord)
        .filter(DietPlanRecord.user_id == user_id)
        .order_by(DietPlanRecord.created_at.desc())
        .all()
    )
    tracking = repo.get_tracking_entries(db, user_id, days=None)
    goals = repo.get_goals(db, user_id) or []
    prefs = repo.get_user_preferences(db, user_id)
    biometric = build_biometric_summary(tracking)
    current_plan = next((p for p in plans if p.is_current), plans[0] if plans else None)

    return {
        "user": _user_summary(user, db),
        "preferences": prefs,
        "goals": goals,
        "lab_results": labs,
        "diet_plans": [
            {
                "id": p.id,
                "is_current": p.is_current,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "payload": p.payload,
            }
            for p in plans
        ],
        "current_plan_summary": (
            {
                "id": current_plan.id,
                "title": (current_plan.payload or {}).get("title"),
                "week_start": (current_plan.payload or {}).get("week_start")
                or (current_plan.payload or {}).get("start_date"),
                "week_end": (current_plan.payload or {}).get("week_end")
                or (current_plan.payload or {}).get("end_date"),
                "target_calories": (current_plan.payload or {}).get("target_calories"),
                "meal_count": len((current_plan.payload or {}).get("meals") or []),
                "is_current": current_plan.is_current,
            }
            if current_plan
            else None
        ),
        "tracking": tracking,
        "biometric_summary": biometric,
        "generated_at": datetime.utcnow().isoformat() + "Z",
    }


@router.patch("/users/{user_id}")
async def update_user(
    user_id: int,
    body: AdminUserUpdate,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if body.first_name is not None:
        user.first_name = body.first_name
    if body.last_name is not None:
        user.last_name = body.last_name
    if body.role is not None:
        if body.role not in ("user", "admin"):
            raise HTTPException(status_code=400, detail="role must be user or admin")
        user.role = body.role
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.subscription_tier is not None:
        user.subscription_tier = body.subscription_tier
    if body.reset_password:
        user.password_hash = get_password_hash(body.reset_password)
    db.commit()
    db.refresh(user)
    return _user_summary(user, db)


@router.post("/users/{user_id}/generate-week")
async def admin_generate_week(
    user_id: int,
    next_week: bool = False,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    payload = {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "subscription_tier": user.subscription_tier,
        "dietary_preference": "omnivore",
        "allergies": [],
    }
    plan = friday_release_next_week(payload) if next_week else generate_weekly_plan(payload)
    return {"plan": plan, "message": "Weekly plan generated"}


@router.get("/stats")
async def admin_stats(admin: dict = Depends(require_admin), db: Session = Depends(get_db)):
    from app.db.seed_cohort import cohort_summary

    cohort = cohort_summary(db)
    return {
        "users": db.query(User).count(),
        "active_users": db.query(User).filter(User.is_active.is_(True)).count(),
        "lab_results": db.query(LabResultRecord).count(),
        "diet_plans": db.query(DietPlanRecord).count(),
        "tracking_entries": db.query(TrackingRecord).count(),
        "cohort": {
            "total": cohort.get("total", 0),
            "retest_ready": cohort.get("retest_ready", 0),
            "with_meal_swap": cohort.get("with_meal_swap", 0),
            "by_arc": cohort.get("by_arc", {}),
            "version": cohort.get("version"),
        },
    }


@router.get("/cohort")
async def get_cohort(
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
    arc: Optional[str] = None,
    retest_ready: Optional[bool] = None,
):
    """Illustrative multi-persona demo cohort (not clinical research)."""
    from app.db.seed_cohort import cohort_summary

    data = cohort_summary(db)
    users = data.get("users") or []
    if arc:
        users = [u for u in users if u.get("arc") == arc]
    if retest_ready is not None:
        users = [u for u in users if bool(u.get("retest_ready")) is retest_ready]
    data["users"] = users
    data["filtered_total"] = len(users)
    return data


@router.post("/cohort/seed")
async def seed_cohort_endpoint(
    force: bool = False,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Seed or refresh the 55-user demo cohort."""
    from app.db.seed_cohort import seed_demo_cohort

    return seed_demo_cohort(db, force=force)


@router.get("/users/{user_id}/lab-order")
async def get_sample_lab_order(
    user_id: int,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Sample Labcorp-style wellness lab order page (DEMO ONLY).
    Use for retest-ready personas — does not place a real order.
    """
    from app.services.lab_order_service import build_sample_lab_order

    try:
        return build_sample_lab_order(db, user_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
