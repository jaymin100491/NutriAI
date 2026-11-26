"""
Production nutrition target engine.

Computes calorie + macro targets from:
  1. Biometrics (Mifflin–St Jeor BMR → TDEE)
  2. Lab-derived / user goals (deficit, surplus, macro tilt)
  3. Lab safety modifiers (eGFR → protein cap, A1c → carb moderation, lipids)
  4. Learned calibrations from historical plan outcomes (no code changes required)

Wellness education only — not medical advice or individualized clinical care.
"""
from __future__ import annotations

import logging
import math
import re
from dataclasses import asdict, dataclass, field
from datetime import date
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("nutriai.nutrition_engine")

# --- Safety clamps (production bounds) ---
MIN_CALORIES = 1400
MAX_CALORIES = 3200
MIN_PROTEIN_PCT = 15
MAX_PROTEIN_PCT = 40
MIN_CARB_PCT = 30
MAX_CARB_PCT = 60
MIN_FAT_PCT = 20
MAX_FAT_PCT = 40

ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

# Goal → calorie delta vs TDEE and preferred macro split
GOAL_ADJUSTMENTS: Dict[str, Dict[str, Any]] = {
    "weight_loss": {"calorie_delta": -400, "protein_pct": 30, "carb_pct": 40, "fat_pct": 30, "fiber_g": 30},
    "lower_cholesterol": {"calorie_delta": -150, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 35},
    "heart_health": {"calorie_delta": -100, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 32},
    "manage_diabetes": {"calorie_delta": -200, "protein_pct": 25, "carb_pct": 40, "fat_pct": 35, "fiber_g": 35},
    "lower_blood_pressure": {"calorie_delta": -150, "protein_pct": 25, "carb_pct": 50, "fat_pct": 25, "fiber_g": 30},
    "muscle_gain": {"calorie_delta": 300, "protein_pct": 35, "carb_pct": 40, "fat_pct": 25, "fiber_g": 30},
    "weight_gain": {"calorie_delta": 400, "protein_pct": 25, "carb_pct": 50, "fat_pct": 25, "fiber_g": 28},
    "more_protein": {"calorie_delta": 100, "protein_pct": 35, "carb_pct": 35, "fat_pct": 30, "fiber_g": 28},
    "athletic_performance": {"calorie_delta": 250, "protein_pct": 30, "carb_pct": 45, "fat_pct": 25, "fiber_g": 30},
    "kidney_support": {"calorie_delta": -100, "protein_pct": 18, "carb_pct": 55, "fat_pct": 27, "fiber_g": 30},
    "increase_energy": {"calorie_delta": 0, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 30},
    "gut_health": {"calorie_delta": 0, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 35},
    "reduce_inflammation": {"calorie_delta": -100, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 32},
    "default": {"calorie_delta": 0, "protein_pct": 25, "carb_pct": 45, "fat_pct": 30, "fiber_g": 30},
}


@dataclass
class BodyProfile:
    sex: str = "male"  # male | female
    age_years: Optional[int] = None
    height_in: Optional[float] = None
    weight_lbs: Optional[float] = None
    activity: str = "moderate"
    bmi: Optional[float] = None

    @property
    def height_cm(self) -> Optional[float]:
        return round(self.height_in * 2.54, 1) if self.height_in else None

    @property
    def weight_kg(self) -> Optional[float]:
        return round(self.weight_lbs * 0.453592, 2) if self.weight_lbs else None


@dataclass
class LabSnapshot:
    a1c: Optional[float] = None
    glucose: Optional[float] = None
    ldl: Optional[float] = None
    hdl: Optional[float] = None
    trig: Optional[float] = None
    total_chol: Optional[float] = None
    egfr: Optional[float] = None
    creatinine: Optional[float] = None
    systolic: Optional[float] = None
    diastolic: Optional[float] = None
    markers_used: List[str] = field(default_factory=list)


@dataclass
class NutritionTargets:
    target_calories: int
    macro_targets: Dict[str, Any]
    bmr: Optional[int]
    tdee: Optional[int]
    method: str
    primary_goal: str
    segment: str
    notes: List[str]
    health_tags: List[str]
    lab_summary: Optional[str]
    calibration_applied: Dict[str, float]
    profile: Dict[str, Any]
    labs: Dict[str, Any]

    def as_engine_payload(self) -> Dict[str, Any]:
        return asdict(self)


def _num(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _marker_map(lab_results: List[Dict[str, Any]]) -> Dict[str, float]:
    """Latest value per normalized marker name across panels (panels assumed newest-first)."""
    found: Dict[str, float] = {}
    for lab in lab_results or []:
        tests = (lab.get("results") or {}).get("tests") or []
        for test in tests:
            name = str(test.get("name") or "").strip().lower()
            val = _num(test.get("value"))
            if not name or val is None or name in found:
                continue
            found[name] = val
    return found


def _pick(
    markers: Dict[str, float],
    *needles: str,
    exclude: Tuple[str, ...] = (),
    lo: Optional[float] = None,
    hi: Optional[float] = None,
) -> Optional[float]:
    for needle in needles:
        for name, val in markers.items():
            if any(ex in name for ex in exclude):
                continue
            if needle not in name:
                continue
            if lo is not None and val < lo:
                continue
            if hi is not None and val > hi:
                continue
            return val
    return None


def extract_lab_snapshot(lab_results: List[Dict[str, Any]]) -> LabSnapshot:
    m = _marker_map(lab_results)
    snap = LabSnapshot(
        a1c=_pick(m, "hemoglobin a1c", "a1c", lo=3.0, hi=15.0),
        glucose=_pick(m, "glucose", lo=40, hi=400, exclude=("tolerance",)),
        ldl=_pick(m, "ldl chol", "ldl-c", "ldl", lo=20, hi=400, exclude=("vldl",)),
        hdl=_pick(m, "hdl cholesterol", "hdl", lo=10, hi=150, exclude=("non-hdl", "non hdl", "vldl")),
        trig=_pick(m, "triglyceride", lo=20, hi=1000),
        total_chol=_pick(m, "cholesterol, total", "total cholesterol", lo=50, hi=500, exclude=("hdl", "ldl", "vldl", "non-hdl")),
        egfr=_pick(m, "egfr", lo=1, hi=200),
        creatinine=_pick(m, "creatinine", lo=0.2, hi=5.0, exclude=("bun/creatinine", "ratio")),
        systolic=_pick(m, "systolic", lo=70, hi=250),
        diastolic=_pick(m, "diastolic", lo=40, hi=160),
    )
    snap.markers_used = [k for k, v in asdict(snap).items() if v is not None and k != "markers_used"]
    return snap


def _collect_biometric_series(lab_results: List[Dict[str, Any]]) -> Tuple[List[float], List[float], List[float]]:
    """Newest-first series of height/weight/bmi from panels."""
    heights: List[float] = []
    weights: List[float] = []
    bmis: List[float] = []
    for lab in lab_results or []:
        for test in (lab.get("results") or {}).get("tests") or []:
            name = str(test.get("name") or "").lower()
            val = _num(test.get("value"))
            if val is None:
                continue
            if "patient height" in name or name.startswith("height"):
                if 54 <= val <= 84:
                    heights.append(val)
            elif "patient weight" in name or ("weight" in name and "lbs" in name):
                if 80 <= val <= 450:
                    weights.append(val)
            elif "body mass index" in name or name == "bmi":
                if 12 <= val <= 60:
                    bmis.append(val)
    return heights, weights, bmis


def extract_body_profile(
    *,
    user: Dict[str, Any],
    lab_results: List[Dict[str, Any]],
    tracking: Optional[List[Dict[str, Any]]] = None,
) -> BodyProfile:
    heights, weights, bmis = _collect_biometric_series(lab_results)
    weight = weights[0] if weights else None
    height = heights[0] if heights else None
    bmi = bmis[0] if bmis else None

    # Prefer a height that yields a plausible BMI with the newest weight (Labcorp
    # sometimes prints a bad current height with a sane previous value).
    if weight and heights:
        plausible = []
        for h in heights:
            b = (weight / (h * h)) * 703
            if 17 <= b <= 40:
                plausible.append((abs(b - 26), h, b))  # prefer near-overweight band as tie-break
        if plausible:
            plausible.sort()
            height = plausible[0][1]

    if tracking:
        for entry in reversed(tracking):
            if weight is None and entry.get("weight_lbs") is not None:
                w = _num(entry.get("weight_lbs"))
                if w is not None and 80 <= w <= 450:
                    weight = w
            if height is None and entry.get("height_in") is not None:
                h = _num(entry.get("height_in"))
                if h is not None and 54 <= h <= 84:
                    height = h

    sex = str(user.get("sex") or user.get("gender") or "male").strip().lower()
    if sex not in ("male", "female"):
        sex = "male"

    age = user.get("age") or user.get("age_years")
    if age is None:
        dob = user.get("date_of_birth") or user.get("dob")
        if dob:
            try:
                parts = str(dob)[:10].replace("/", "-").split("-")
                if len(parts[0]) == 4:
                    y, mo, d = int(parts[0]), int(parts[1]), int(parts[2])
                else:
                    mo, d, y = int(parts[0]), int(parts[1]), int(parts[2])
                    if y < 100:
                        y += 2000
                age = max(18, min(90, date.today().year - y))
            except Exception:
                age = None
    age = int(age) if age else 35  # production fallback when DOB missing

    activity = str(user.get("activity_level") or "moderate").strip().lower()
    if activity not in ACTIVITY_MULTIPLIERS:
        activity = "moderate"

    if bmi is None and height and weight and height > 0:
        bmi = round((weight / (height * height)) * 703, 1)

    return BodyProfile(
        sex=sex,
        age_years=age,
        height_in=height,
        weight_lbs=weight,
        activity=activity,
        bmi=bmi,
    )


def mifflin_st_jeor_bmr(profile: BodyProfile) -> Optional[float]:
    """BMR in kcal/day. Requires weight, height, age."""
    if not profile.weight_kg or not profile.height_cm or not profile.age_years:
        return None
    base = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age_years
    return base + 5 if profile.sex == "male" else base - 161


def compute_tdee(bmr: float, activity: str) -> float:
    return bmr * ACTIVITY_MULTIPLIERS.get(activity, 1.55)


def _goal_adj(primary_goal: str) -> Dict[str, Any]:
    if primary_goal in GOAL_ADJUSTMENTS:
        return GOAL_ADJUSTMENTS[primary_goal]
    if primary_goal.startswith("custom_"):
        return GOAL_ADJUSTMENTS["default"]
    return GOAL_ADJUSTMENTS.get(primary_goal, GOAL_ADJUSTMENTS["default"])


def _segment_key(profile: BodyProfile, primary_goal: str) -> str:
    bmi = profile.bmi or 0
    if bmi < 18.5:
        bmi_bucket = "under"
    elif bmi < 25:
        bmi_bucket = "normal"
    elif bmi < 30:
        bmi_bucket = "over"
    else:
        bmi_bucket = "obese"
    return f"{primary_goal}|{profile.sex}|{bmi_bucket}|{profile.activity}"


def _normalize_macros(protein: float, carb: float, fat: float) -> Tuple[float, float, float]:
    protein = max(MIN_PROTEIN_PCT, min(MAX_PROTEIN_PCT, protein))
    carb = max(MIN_CARB_PCT, min(MAX_CARB_PCT, carb))
    fat = max(MIN_FAT_PCT, min(MAX_FAT_PCT, fat))
    total = protein + carb + fat
    if total <= 0:
        return 25.0, 45.0, 30.0
    protein = round(100 * protein / total)
    carb = round(100 * carb / total)
    fat = 100 - protein - carb
    return float(protein), float(carb), float(fat)


def _apply_lab_modifiers(
    *,
    calories: float,
    protein_pct: float,
    carb_pct: float,
    fat_pct: float,
    labs: LabSnapshot,
    notes: List[str],
    tags: List[str],
) -> Tuple[float, float, float, float]:
    # Kidney: lower protein when eGFR reduced
    if labs.egfr is not None and labs.egfr < 60:
        protein_pct = min(protein_pct, 18)
        notes.append(f"eGFR {labs.egfr:.0f} — moderating protein for kidney support.")
        tags += ["kidney-friendly", "controlled-protein"]

    # Glycemic: moderate carbs when A1c or fasting glucose elevated
    if (labs.a1c is not None and labs.a1c >= 5.7) or (labs.glucose is not None and labs.glucose >= 100):
        carb_pct = min(carb_pct, 40)
        protein_pct = max(protein_pct, 25)
        notes.append("Elevated glycemic markers — lower-glycemic carb pattern.")
        tags += ["low-glycemic", "high-fiber", "complex-carbs"]

    # Lipids: emphasize fiber / plant fats narrative via tags; slight calorie trim if obese lipids
    if labs.ldl is not None and labs.ldl >= 100:
        tags += ["heart-healthy", "high-fiber", "plant-forward"]
        notes.append(f"LDL {labs.ldl:.0f} — heart-healthy fat quality and fiber focus.")
    if labs.trig is not None and labs.trig >= 150:
        carb_pct = min(carb_pct, 42)
        notes.append(f"Triglycerides {labs.trig:.0f} — moderating refined carbs.")
        tags += ["low-glycemic"]

    # Blood pressure
    if (labs.systolic is not None and labs.systolic >= 130) or (
        labs.diastolic is not None and labs.diastolic >= 80
    ):
        tags += ["dash-style", "lower-sodium"]
        notes.append("Blood pressure elevated — DASH-style meal emphasis.")

    protein_pct, carb_pct, fat_pct = _normalize_macros(protein_pct, carb_pct, fat_pct)
    return calories, protein_pct, carb_pct, fat_pct


def _fallback_calories(primary_goal: str, profile: BodyProfile) -> int:
    """When height/weight missing, use goal baselines scaled lightly by BMI if known."""
    base = {
        "weight_loss": 1600,
        "muscle_gain": 2400,
        "weight_gain": 2600,
        "athletic_performance": 2500,
        "manage_diabetes": 1700,
        "lower_cholesterol": 1800,
    }.get(primary_goal, 1900)
    if profile.bmi and profile.bmi >= 30 and primary_goal in ("weight_loss", "lower_cholesterol", "manage_diabetes"):
        base = max(MIN_CALORIES, base - 100)
    return base


def compute_nutrition_targets(
    *,
    user: Dict[str, Any],
    goals: List[Dict[str, Any]],
    lab_results: Optional[List[Dict[str, Any]]] = None,
    tracking: Optional[List[Dict[str, Any]]] = None,
    calibration: Optional[Dict[str, float]] = None,
    biometric_calorie_delta: int = 0,
) -> NutritionTargets:
    """
    Production entry point: returns calorie + macro targets with full audit trail.
    """
    lab_results = lab_results or []
    goals = goals or []
    primary_goal = (goals[0].get("goal_type") if goals else None) or "increase_energy"
    adj = _goal_adj(primary_goal)
    profile = extract_body_profile(user=user, lab_results=lab_results, tracking=tracking)
    labs = extract_lab_snapshot(lab_results)
    notes: List[str] = []
    tags: List[str] = list(adj.get("health_tags") or [])

    bmr = mifflin_st_jeor_bmr(profile)
    method = "mifflin_st_jeor"
    if bmr is None:
        calories = float(_fallback_calories(primary_goal, profile))
        tdee = None
        method = "goal_baseline_fallback"
        notes.append("Missing height/weight/age for BMR — used goal baseline calories.")
    else:
        tdee = compute_tdee(bmr, profile.activity)
        calories = tdee + float(adj["calorie_delta"])
        notes.append(
            f"BMR {bmr:.0f} → TDEE {tdee:.0f} ({profile.activity}) "
            f"with {primary_goal} delta {adj['calorie_delta']:+d}."
        )

    protein_pct = float(adj["protein_pct"])
    carb_pct = float(adj["carb_pct"])
    fat_pct = float(adj["fat_pct"])
    fiber_g = int(adj.get("fiber_g") or 30)

    # Custom goal nutrition_profile override (from AI goal interpret)
    primary = next((g for g in goals if g.get("goal_type") == primary_goal), goals[0] if goals else {})
    custom = (primary or {}).get("nutrition_profile") or {}
    if custom.get("calories"):
        calories = float(custom["calories"])
        notes.append("Applied custom nutrition_profile calories.")
    macros_custom = custom.get("macros") or {}
    if macros_custom:
        protein_pct = float(macros_custom.get("protein_percent", protein_pct))
        carb_pct = float(macros_custom.get("carb_percent", carb_pct))
        fat_pct = float(macros_custom.get("fat_percent", fat_pct))
        fiber_g = int(macros_custom.get("fiber_grams", fiber_g))

    calories, protein_pct, carb_pct, fat_pct = _apply_lab_modifiers(
        calories=calories,
        protein_pct=protein_pct,
        carb_pct=carb_pct,
        fat_pct=fat_pct,
        labs=labs,
        notes=notes,
        tags=tags,
    )

    # Short-term biometric nudge from tracking
    if biometric_calorie_delta:
        calories += biometric_calorie_delta
        notes.append(f"Biometric weekly nudge {biometric_calorie_delta:+d} kcal.")

    # Learned calibrations (from millions of stored plan outcomes over time)
    cal = calibration or {}
    cal_applied = {
        "calorie_bias": float(cal.get("calorie_bias") or 0),
        "protein_pct_bias": float(cal.get("protein_pct_bias") or 0),
        "carb_pct_bias": float(cal.get("carb_pct_bias") or 0),
        "fat_pct_bias": float(cal.get("fat_pct_bias") or 0),
    }
    if any(cal_applied.values()):
        calories += cal_applied["calorie_bias"]
        protein_pct += cal_applied["protein_pct_bias"]
        carb_pct += cal_applied["carb_pct_bias"]
        fat_pct += cal_applied["fat_pct_bias"]
        notes.append("Applied learned segment calibration from historical outcomes.")

    protein_pct, carb_pct, fat_pct = _normalize_macros(protein_pct, carb_pct, fat_pct)
    calories = int(max(MIN_CALORIES, min(MAX_CALORIES, round(calories / 10) * 10)))

    lab_bits = []
    if labs.a1c is not None:
        lab_bits.append(f"A1c {labs.a1c}")
    if labs.ldl is not None:
        lab_bits.append(f"LDL {labs.ldl}")
    if labs.trig is not None:
        lab_bits.append(f"TG {labs.trig}")
    if labs.egfr is not None:
        lab_bits.append(f"eGFR {labs.egfr}")
    lab_summary = ", ".join(lab_bits) if lab_bits else None

    if not tags:
        tags = ["nutrient-dense", "balanced", "high-fiber"]

    return NutritionTargets(
        target_calories=calories,
        macro_targets={
            "protein_percent": int(protein_pct),
            "carb_percent": int(carb_pct),
            "fat_percent": int(fat_pct),
            "fiber_grams": fiber_g,
        },
        bmr=int(round(bmr)) if bmr else None,
        tdee=int(round(tdee)) if tdee else None,
        method=method,
        primary_goal=primary_goal,
        segment=_segment_key(profile, primary_goal),
        notes=notes,
        health_tags=list(dict.fromkeys(tags)),
        lab_summary=lab_summary,
        calibration_applied=cal_applied,
        profile=asdict(profile),
        labs={k: v for k, v in asdict(labs).items() if k != "markers_used"},
    )
