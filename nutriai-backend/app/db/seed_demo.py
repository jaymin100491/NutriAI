"""
Demo seed for open-market NutriAI — multi-year lab timeline with improvement arc.
Uses realistic panels inspired by a real patient timeline (values are demo-tweaked).
"""
from __future__ import annotations

from copy import deepcopy
from datetime import date, timedelta
from typing import Any, Dict, List

from sqlalchemy.orm import Session

from app.db import repository as repo
from app.db.models import DietPlanRecord, User
from app.db.store import set_user_goals, get_user_preferences
from app.integrations.labcorp.adapter import generate_interpretation
from app.services.diet_plan_engine import generate_diet_plan


DEMO_EMAIL = "jaymin@nutriai.app"
DEMO_PASSWORD_HINT = "demo"


def _marker(
    name: str,
    value: float | str,
    unit: str,
    reference_range: str,
    status: str,
    category: str,
    test_code: str = "",
) -> Dict[str, Any]:
    return {
        "name": name,
        "value": value,
        "unit": unit,
        "reference_range": reference_range,
        "status": status,
        "category": category,
        "test_code": test_code,
        "nutrition_relevant": True,
    }


def _biometrics(height: float, weight: float, waist: float, systolic: int, diastolic: int) -> List[Dict[str, Any]]:
    bmi = round((weight / (height * height)) * 703, 1)
    return [
        _marker("Patient Height (In)", height, "in", "", "normal", "Biometrics", "101148"),
        _marker("Patient Weight (lbs)", weight, "lbs", "", "normal", "Biometrics", "101149"),
        _marker("Body Mass Index", bmi, "kg/m2", "18.5-24.9", "high" if bmi >= 25 else "normal", "Biometrics", "101150"),
        _marker("Waist Circumference (In)", waist, "in", "<40", "high" if waist >= 40 else "normal", "Biometrics", "101151"),
        _marker("Systolic Blood Pressure", systolic, "mmHg", "<120", "high" if systolic >= 130 else "normal", "Biometrics", "101144"),
        _marker("Diastolic Blood Pressure", diastolic, "mmHg", "<80", "high" if diastolic >= 80 else "normal", "Biometrics", "101145"),
    ]


def _lipid_glucose_a1c(
    *,
    total_chol: float,
    trig: float,
    hdl: float,
    ldl: float,
    glucose: float,
    a1c: float,
    creat: float | None = None,
    egfr: float | None = None,
) -> List[Dict[str, Any]]:
    vldl = round(trig / 5, 1)
    ratio = round(total_chol / hdl, 1) if hdl else 0
    markers = [
        _marker("Cholesterol, Total", total_chol, "mg/dL", "100-199", "high" if total_chol >= 200 else "normal", "Lipid Panel", "001065"),
        _marker("Triglycerides", trig, "mg/dL", "0-149", "high" if trig >= 150 else "normal", "Lipid Panel", "001172"),
        _marker("HDL Cholesterol", hdl, "mg/dL", ">39", "low" if hdl <= 39 else "normal", "Lipid Panel", "011817"),
        _marker("VLDL Cholesterol Cal", vldl, "mg/dL", "5-40", "high" if vldl > 40 else "normal", "Lipid Panel", "011919"),
        _marker("LDL Chol Calc (NIH)", ldl, "mg/dL", "0-99", "high" if ldl >= 100 else "normal", "Lipid Panel", "012059"),
        _marker("T. Chol/HDL Ratio", ratio, "ratio", "0-5", "high" if ratio > 5 else "normal", "Lipid Panel", "100065"),
        _marker("Glucose", glucose, "mg/dL", "65-99", "high" if glucose >= 100 else "normal", "Metabolic Panel", "001032"),
        _marker("Hemoglobin A1c", a1c, "%", "4.8-5.6", "high" if a1c >= 5.7 else "normal", "Diabetes Screening", "001481"),
    ]
    if creat is not None:
        markers.append(_marker("Creatinine", creat, "mg/dL", "0.76-1.27", "high" if creat > 1.27 else "normal", "Kidney Function", "001370"))
    if egfr is not None:
        markers.append(_marker("eGFR", egfr, "mL/min/1.73", ">59", "low" if egfr < 60 else "normal", "Kidney Function", "100779"))
    return markers


def _build_result(
    *,
    result_id: int,
    user_id: int,
    test_date: str,
    panel_title: str,
    account_name: str,
    provider: str,
    markers: List[Dict[str, Any]],
    source: str = "health_records",
    category: str = "recently_viewed",
) -> Dict[str, Any]:
    interpretation = generate_interpretation(markers)
    return {
        "id": result_id,
        "user_id": user_id,
        "test_date": test_date,
        "test_type": panel_title,
        "panel_title": panel_title,
        "source": source,
        "results": {"tests": markers},
        "interpretation": interpretation,
        "labcorp": {
            "account_name": account_name,
            "ordering_provider": provider,
            "patient_name": "Jaymin Patel",
            "pid": 25410253,
            "dashboard_category": category,
            "date_of_service": f"{test_date}T12:00:00.000Z",
            "ordered_date": f"{test_date}T14:00:00.000Z",
            "report_date": f"{test_date}T18:00:00.000Z",
            "is_detail_available": True,
            "test_codes": [{"test_code": "demo", "test_name": panel_title}],
        },
    }


def build_demo_lab_timeline(user_id: int) -> List[Dict[str, Any]]:
    """Improvement story: 2023 → 2026 after nutrition coaching."""
    return [
        _build_result(
            result_id=3763041399,
            user_id=user_id,
            test_date="2023-07-27",
            panel_title="LP + Creat + HbA1c + Biometrics",
            account_name="Employer Wellness",
            provider="M McDaniel",
            markers=_lipid_glucose_a1c(
                total_chol=228, trig=178, hdl=38, ldl=154, glucose=118, a1c=6.2, creat=1.05, egfr=88
            )
            + _biometrics(70, 198, 41, 138, 88),
            category="recently_viewed",
        ),
        _build_result(
            result_id=3853232152,
            user_id=user_id,
            test_date="2024-07-12",
            panel_title="LP + Glucose + HbA1c + Biometrics",
            account_name="Employer Wellness",
            provider="M McDaniel",
            markers=_lipid_glucose_a1c(
                total_chol=214, trig=162, hdl=41, ldl=141, glucose=110, a1c=5.9
            )
            + _biometrics(70, 192, 40, 134, 84),
        ),
        _build_result(
            result_id=3934019856,
            user_id=user_id,
            test_date="2025-06-27",
            panel_title="LP + Glucose + HbA1c + Biometrics",
            account_name="Employer Wellness",
            provider="M McDaniel",
            markers=_lipid_glucose_a1c(
                total_chol=198, trig=138, hdl=44, ldl=126, glucose=102, a1c=5.7
            )
            + _biometrics(70, 186, 38, 128, 80),
        ),
        _build_result(
            result_id=3965665823,
            user_id=user_id,
            test_date="2025-10-24",
            panel_title="Comprehensive Metabolic + Lipid Panel",
            account_name="Primary Care Clinic",
            provider="K Shukla",
            markers=[
                _marker("Glucose", 99, "mg/dL", "65-99", "normal", "Metabolic Panel", "001032"),
                _marker("BUN", 14, "mg/dL", "6-24", "normal", "Kidney Function", "001040"),
                _marker("Creatinine", 0.98, "mg/dL", "0.76-1.27", "normal", "Kidney Function", "001370"),
                _marker("eGFR", 95, "mL/min/1.73", ">59", "normal", "Kidney Function", "100779"),
                _marker("Sodium", 140, "mmol/L", "134-144", "normal", "Electrolytes", "001198"),
                _marker("Potassium", 4.2, "mmol/L", "3.5-5.2", "normal", "Electrolytes", "001180"),
                _marker("ALT (SGPT)", 28, "IU/L", "0-44", "normal", "Liver", "001545"),
                _marker("AST (SGOT)", 24, "IU/L", "0-40", "normal", "Liver", "001123"),
                *_lipid_glucose_a1c(total_chol=190, trig=128, hdl=46, ldl=118, glucose=99, a1c=5.6)[:6],
                _marker("Non-HDL Cholesterol", 144, "mg/dL", "0-159", "normal", "Lipid Panel", "011976"),
            ],
            source="mychart",
        ),
        _build_result(
            result_id=3965653735,
            user_id=user_id,
            test_date="2025-10-24",
            panel_title="CBC With Differential/Platelet",
            account_name="Primary Care Clinic",
            provider="K Shukla",
            markers=[
                _marker("WBC", 6.4, "x10E3/uL", "3.4-10.8", "normal", "CBC", "005025"),
                _marker("RBC", 4.9, "x10E6/uL", "4.14-5.80", "normal", "CBC", "005033"),
                _marker("Hemoglobin", 15.1, "g/dL", "13.0-17.7", "normal", "CBC", "005041"),
                _marker("Hematocrit", 44.2, "%", "37.5-51.0", "normal", "CBC", "005058"),
                _marker("Platelets", 232, "x10E3/uL", "150-450", "normal", "CBC", "015172"),
            ],
            source="mychart",
        ),
        _build_result(
            result_id=4029818556,
            user_id=user_id,
            test_date="2026-06-16",
            panel_title="LP + Creat + HbA1c + Biometrics",
            account_name="Employer Wellness",
            provider="M McDaniel",
            markers=_lipid_glucose_a1c(
                total_chol=178, trig=112, hdl=49, ldl=107, glucose=94, a1c=5.4, creat=0.94, egfr=99
            )
            + _biometrics(70, 180, 36, 122, 76),
            category="new",
        ),
    ]


def ensure_demo_user(db: Session) -> User:
    user = db.query(User).filter(User.email == DEMO_EMAIL).first()
    if user is None:
        user = User(
            email=DEMO_EMAIL,
            first_name="Jaymin",
            last_name="Patel",
            subscription_tier="premium",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def seed_demo_workspace(db: Session, user: User | None = None) -> User:
    """Idempotent seed: labs, goals, current plan, preferences, plan history."""
    user = user or ensure_demo_user(db)

    labs = build_demo_lab_timeline(user.id)
    repo.save_lab_results(db, user.id, labs)

    prefs = get_user_preferences(user.id)
    prefs.update(
        {
            "dislikes": ["shrimp"],
            "cuisine_preferences": ["Indian", "Mediterranean", "Mexican", "Thai", "Japanese"],
            "dietary_preference": "omnivore",
            "favorites": ["paneer", "lentils", "salmon"],
            "substitutions": {"tofu": "paneer"},
        }
    )

    goals = [
        {
            "id": 1,
            "goal_type": "lower_cholesterol",
            "label": "Optimize LDL Cholesterol",
            "priority": 1,
            "current_value": 107,
            "target_value": 99,
            "unit": "mg/dL",
            "status": "improving",
            "baseline_value": 154,
            "notes": "Down from 154 (2023) → 107 (2026) on NutriAI coaching",
        },
        {
            "id": 2,
            "goal_type": "manage_diabetes",
            "label": "Maintain Healthy A1c",
            "priority": 2,
            "current_value": 5.4,
            "target_value": 5.4,
            "unit": "%",
            "status": "achieved",
            "baseline_value": 6.2,
            "notes": "A1c improved from 6.2% to 5.4%",
        },
        {
            "id": 3,
            "goal_type": "weight_loss",
            "label": "Sustain Healthy Weight",
            "priority": 3,
            "current_value": 180,
            "target_value": 175,
            "unit": "lbs",
            "status": "improving",
            "baseline_value": 198,
            "notes": "18 lbs down since 2023 with global cuisine meal plans",
        },
        {
            "id": 4,
            "goal_type": "lower_blood_pressure",
            "label": "Blood Pressure Support",
            "priority": 4,
            "current_value": 122,
            "target_value": 120,
            "unit": "mmHg",
            "status": "improving",
            "baseline_value": 138,
            "notes": "Systolic 138 → 122 with DASH-style + Indian/Med meals",
        },
    ]
    set_user_goals(user.id, goals)

    # Historical archived plans (for demo narrative)
    history_plans = [
        {
            "id": 9001,
            "user_id": user.id,
            "title": "2023 Kickoff: Lower Cholesterol Focus",
            "start_date": "2023-08-01",
            "end_date": "2023-08-07",
            "duration_days": 7,
            "goals": ["lower_cholesterol", "manage_diabetes"],
            "primary_goal": "lower_cholesterol",
            "target_calories": 1800,
            "macro_targets": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 35},
            "meals": [],
            "shopping_list": {},
            "ai_rationale": "Baseline plan after July 2023 labs (LDL 154, A1c 6.2).",
            "customization_count": 2,
            "archived": True,
        },
        {
            "id": 9002,
            "user_id": user.id,
            "title": "2024 Global Cuisine Refresh",
            "start_date": "2024-08-01",
            "end_date": "2024-08-07",
            "duration_days": 7,
            "goals": ["lower_cholesterol", "weight_loss"],
            "primary_goal": "lower_cholesterol",
            "target_calories": 1700,
            "macro_targets": {"protein_percent": 28, "carb_percent": 42, "fat_percent": 30, "fiber_grams": 32},
            "meals": [],
            "shopping_list": {},
            "ai_rationale": "Rotated Indian, Mediterranean, and Mexican meals after mid-year improvement.",
            "customization_count": 5,
            "archived": True,
        },
    ]

    # Clear previous diet plans then add history + current
    db.query(DietPlanRecord).filter(DietPlanRecord.user_id == user.id).delete()
    db.commit()

    for plan in history_plans:
        db.add(DietPlanRecord(user_id=user.id, payload=plan, is_current=False))
    db.commit()

    demo_user_dict = {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "subscription_tier": user.subscription_tier,
        "dietary_preference": "omnivore",
        "allergies": [],
        "height_inches": 70,
        "current_weight_lbs": 180,
    }
    generate_diet_plan(
        demo_user_dict,
        duration_days=7,
        goals_override=["lower_cholesterol", "manage_diabetes", "weight_loss", "lower_blood_pressure"],
        lab_summary="Latest labs (Jun 2026): LDL 107, A1c 5.4%, glucose 94 — continue Mediterranean + Indian heart-healthy rotation; keep shrimp off the plan.",
    )

    seed_biometric_history(db, user.id)
    return user


def seed_biometric_history(db: Session, user_id: int) -> None:
    """
    Interpolate weight / BP / glucose between lab draws so Progress shows
    improvement alongside diet-plan milestones.
    """
    from datetime import datetime, timedelta
    import random

    anchors = [
        # date, weight, systolic, diastolic, glucose, milestone
        ("2023-07-27", 198.0, 138, 88, 118, "Baseline labs — NutriAI kickoff plan"),
        ("2023-11-15", 194.0, 136, 86, 114, "Plan adherence: lower cholesterol focus"),
        ("2024-03-01", 191.0, 134, 84, 110, "Global cuisine rotation started"),
        ("2024-07-12", 192.0, 134, 84, 110, "Year-1 labs — early improvement"),
        ("2024-11-01", 188.0, 130, 82, 106, "Fiber + Med/Indian meal block"),
        ("2025-03-15", 185.0, 128, 80, 103, "DASH-style BP support added"),
        ("2025-06-27", 186.0, 128, 80, 102, "Mid-2025 labs — lipids improving"),
        ("2025-10-24", 183.0, 126, 78, 99, "Clinic labs — CMP + lipids"),
        ("2026-02-01", 181.5, 124, 77, 96, "Winter plan refresh"),
        ("2026-06-16", 180.0, 122, 76, 94, "Latest labs — goals nearly met"),
    ]

    rng = random.Random(user_id + 42)
    entries: List[Dict[str, Any]] = []

    def parse(d: str) -> datetime:
        return datetime.strptime(d, "%Y-%m-%d")

    for i, (d, w, sys, dia, glu, milestone) in enumerate(anchors):
        entries.append(
            {
                "date": d,
                "weight_lbs": w,
                "systolic_bp": sys,
                "diastolic_bp": dia,
                "blood_glucose": glu,
                "mood": 5 + min(i, 4),
                "adherence_percent": 70 + min(i * 3, 25),
                "notes": milestone,
                "milestone": milestone,
                "source": "lab_anchor",
            }
        )
        if i == len(anchors) - 1:
            break
        start, end = parse(d), parse(anchors[i + 1][0])
        days = (end - start).days
        # monthly-ish samples between anchors
        step = max(days // 4, 20)
        for offset in range(step, days, step):
            t = offset / days
            nw = w + (anchors[i + 1][1] - w) * t + rng.uniform(-0.6, 0.6)
            nsys = int(round(sys + (anchors[i + 1][2] - sys) * t + rng.uniform(-1.5, 1.5)))
            ndia = int(round(dia + (anchors[i + 1][3] - dia) * t + rng.uniform(-1.0, 1.0)))
            nglu = int(round(glu + (anchors[i + 1][4] - glu) * t + rng.uniform(-2, 2)))
            sample_date = (start + timedelta(days=offset)).strftime("%Y-%m-%d")
            entries.append(
                {
                    "date": sample_date,
                    "weight_lbs": round(nw, 1),
                    "systolic_bp": nsys,
                    "diastolic_bp": ndia,
                    "blood_glucose": nglu,
                    "mood": 5 + min(i, 4),
                    "adherence_percent": 75 + rng.randint(0, 15),
                    "notes": "Between checkups — on NutriAI plan",
                    "source": "interpolated",
                }
            )

    # Dedupe by date
    by_date = {e["date"]: e for e in entries}
    repo.replace_tracking_entries(db, user_id, list(by_date.values()))
