"""
Self-improving nutrition calibrations.

Every weekly plan decision is stored. When biometrics/labs show outcomes,
segment calibrations are updated so targets improve over time without code changes.

Segments = primary_goal | sex | bmi_bucket | activity
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.db.models import NutritionCalibrationRecord, NutritionDecisionRecord
from app.services.nutrition_engine import NutritionTargets, compute_nutrition_targets

logger = logging.getLogger("nutriai.nutrition_learning")

# Learning rates — small so millions of samples converge smoothly
_LR_CALORIE = 0.05
_LR_MACRO = 0.02
_MAX_CALORIE_BIAS = 250
_MAX_MACRO_BIAS = 5.0


def get_calibration(db: Session, segment: str) -> Dict[str, float]:
    row = (
        db.query(NutritionCalibrationRecord)
        .filter(NutritionCalibrationRecord.segment == segment)
        .first()
    )
    if not row:
        return {
            "calorie_bias": 0.0,
            "protein_pct_bias": 0.0,
            "carb_pct_bias": 0.0,
            "fat_pct_bias": 0.0,
            "sample_count": 0,
        }
    payload = row.payload or {}
    return {
        "calorie_bias": float(payload.get("calorie_bias") or 0),
        "protein_pct_bias": float(payload.get("protein_pct_bias") or 0),
        "carb_pct_bias": float(payload.get("carb_pct_bias") or 0),
        "fat_pct_bias": float(payload.get("fat_pct_bias") or 0),
        "sample_count": int(payload.get("sample_count") or 0),
    }


def record_decision(
    db: Session,
    *,
    user_id: int,
    plan_id: Optional[int],
    targets: NutritionTargets,
    generation_source: str,
) -> None:
    """Persist the exact targets used for a plan (training data for future learning)."""
    db.add(
        NutritionDecisionRecord(
            user_id=user_id,
            plan_id=plan_id,
            segment=targets.segment,
            payload={
                "targets": targets.as_engine_payload(),
                "generation_source": generation_source,
                "recorded_at": datetime.now(timezone.utc).isoformat(),
            },
        )
    )
    db.commit()


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def update_calibration_from_outcome(
    db: Session,
    *,
    segment: str,
    weight_delta_lbs: Optional[float],
    goal_type: str,
    adherence_percent: Optional[float] = None,
) -> Dict[str, float]:
    """
    Online update:
    - weight_loss goal but weight up → lower calorie_bias
    - weight_loss goal and weight down too fast (<-2.5 lbs/week) → raise calories
    - muscle/weight_gain with flat/down weight → raise calorie_bias
    - low adherence → slight protein bias up (more satiating / simpler focus signal)
    """
    cal = get_calibration(db, segment)
    calorie_bias = cal["calorie_bias"]
    protein_bias = cal["protein_pct_bias"]
    carb_bias = cal["carb_pct_bias"]
    fat_bias = cal["fat_pct_bias"]
    n = cal["sample_count"] + 1

    if weight_delta_lbs is not None:
        if goal_type in ("weight_loss", "lower_cholesterol", "manage_diabetes", "lower_blood_pressure"):
            if weight_delta_lbs > 0.8:
                calorie_bias -= _LR_CALORIE * 100
            elif weight_delta_lbs < -2.5:
                calorie_bias += _LR_CALORIE * 80
        elif goal_type in ("muscle_gain", "weight_gain", "athletic_performance"):
            if weight_delta_lbs < 0.2:
                calorie_bias += _LR_CALORIE * 100
            elif weight_delta_lbs > 2.5:
                calorie_bias -= _LR_CALORIE * 60

    if adherence_percent is not None and adherence_percent < 65:
        protein_bias += _LR_MACRO
        carb_bias -= _LR_MACRO * 0.5

    calorie_bias = _clamp(calorie_bias, -_MAX_CALORIE_BIAS, _MAX_CALORIE_BIAS)
    protein_bias = _clamp(protein_bias, -_MAX_MACRO_BIAS, _MAX_MACRO_BIAS)
    carb_bias = _clamp(carb_bias, -_MAX_MACRO_BIAS, _MAX_MACRO_BIAS)
    fat_bias = _clamp(fat_bias, -_MAX_MACRO_BIAS, _MAX_MACRO_BIAS)

    payload = {
        "calorie_bias": round(calorie_bias, 3),
        "protein_pct_bias": round(protein_bias, 3),
        "carb_pct_bias": round(carb_bias, 3),
        "fat_pct_bias": round(fat_bias, 3),
        "sample_count": n,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    row = (
        db.query(NutritionCalibrationRecord)
        .filter(NutritionCalibrationRecord.segment == segment)
        .first()
    )
    if row:
        row.payload = payload
    else:
        db.add(NutritionCalibrationRecord(segment=segment, payload=payload))
    db.commit()
    return payload


def learn_from_user_tracking(db: Session, user_id: int, tracking: List[Dict[str, Any]], primary_goal: str) -> None:
    """Use last ~7 days of tracking against the latest decision segment."""
    if len(tracking) < 2:
        return
    recent = tracking[-7:]
    weights = [float(e["weight_lbs"]) for e in recent if e.get("weight_lbs") is not None]
    adherence = [float(e["adherence_percent"]) for e in recent if e.get("adherence_percent") is not None]
    decision = (
        db.query(NutritionDecisionRecord)
        .filter(NutritionDecisionRecord.user_id == user_id)
        .order_by(NutritionDecisionRecord.id.desc())
        .first()
    )
    if not decision:
        return
    weight_delta = (weights[-1] - weights[0]) if len(weights) >= 2 else None
    avg_adh = sum(adherence) / len(adherence) if adherence else None
    update_calibration_from_outcome(
        db,
        segment=decision.segment,
        weight_delta_lbs=weight_delta,
        goal_type=primary_goal,
        adherence_percent=avg_adh,
    )


def resolve_targets_for_user(
    *,
    user: Dict[str, Any],
    goals: List[Dict[str, Any]],
    lab_results: Optional[List[Dict[str, Any]]] = None,
    tracking: Optional[List[Dict[str, Any]]] = None,
    biometric_calorie_delta: int = 0,
) -> NutritionTargets:
    """Load calibration for the user's segment, compute targets, optionally learn."""
    db = SessionLocal()
    try:
        # Preliminary segment from a first pass without calibration
        draft = compute_nutrition_targets(
            user=user,
            goals=goals,
            lab_results=lab_results,
            tracking=tracking,
            calibration=None,
            biometric_calorie_delta=biometric_calorie_delta,
        )
        cal = get_calibration(db, draft.segment)
        targets = compute_nutrition_targets(
            user=user,
            goals=goals,
            lab_results=lab_results,
            tracking=tracking,
            calibration=cal,
            biometric_calorie_delta=biometric_calorie_delta,
        )
        # Continuous learning from latest tracking whenever we compute targets
        if tracking:
            learn_from_user_tracking(
                db,
                int(user["id"]),
                tracking,
                targets.primary_goal,
            )
        return targets
    finally:
        db.close()


def persist_plan_decision(
    *,
    user_id: int,
    plan: Dict[str, Any],
    targets: NutritionTargets,
) -> None:
    db = SessionLocal()
    try:
        record_decision(
            db,
            user_id=user_id,
            plan_id=plan.get("id"),
            targets=targets,
            generation_source=str(plan.get("generation_source") or "unknown"),
        )
    except Exception:
        logger.exception("Failed to persist nutrition decision for user %s", user_id)
        db.rollback()
    finally:
        db.close()
