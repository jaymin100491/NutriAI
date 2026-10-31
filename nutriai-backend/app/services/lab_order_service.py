"""
Sample Labcorp-style wellness lab order page for DEMO ONLY.

Mirrors the familiar Annual Wellness Verified Laboratory Request layout
(employer wellness / LES style) so demos can show "ready for retest → go to Labcorp".
This does NOT place a real lab order.
"""
from __future__ import annotations

from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from app.db import repository as repo
from app.services.goal_service import GOAL_DEFINITIONS


# Codes inspired by common wellness panels (illustrative)
WELLNESS_TESTS = [
    {"code": "363371", "name": "LP+CREAT+HB A1C", "note": "Lipid profile, creatinine, hemoglobin A1c"},
    {"code": "101300", "name": "BIOMETRICS", "note": "Height, weight, BMI, waist, BP"},
    {"code": "001032", "name": "GLUCOSE", "note": "Fasting glucose"},
]


def build_sample_lab_order(db, user_id: int) -> Dict[str, Any]:
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise ValueError("User not found")

    prefs = repo.get_user_preferences(db, user_id) or {}
    goals = repo.get_goals(db, user_id) or []
    labs = repo.get_lab_results(db, user_id)
    latest = labs[0] if labs else {}

    today = date.today()
    effective_start = today
    effective_end = today + timedelta(days=120)

    primary_goal = (goals[0] if goals else {}).get("goal_type") or "lower_cholesterol"
    goal_label = GOAL_DEFINITIONS.get(primary_goal, {}).get("label", primary_goal)

    reason_lines: List[str] = [
        f"Follow-up wellness panel after NutriAI coaching ({prefs.get('demo_months', 'several')} months).",
        f"Primary focus: {goal_label}.",
        "Illustrative DEMO order — not a real Labcorp requisition.",
    ]
    if prefs.get("outcome_arc") == "flat":
        reason_lines.append("Limited marker movement — clinician may reassess plan adherence.")
    elif prefs.get("outcome_arc") == "improved":
        reason_lines.append("Markers improved — retest to confirm and recalibrate targets.")
    elif prefs.get("outcome_arc") == "adjusted":
        reason_lines.append("Plan was adjusted mid-program — retest to measure response.")
    elif prefs.get("outcome_arc") == "mixed":
        reason_lines.append("Mixed marker response — retest to guide next diet phase.")

    narrative = prefs.get("narrative") or ""

    # Suggested ICD-style wellness codes (demo labels only)
    diagnosis_hints = []
    if primary_goal == "lower_cholesterol":
        diagnosis_hints.append("E78.5 — Hyperlipidemia, unspecified (demo)")
    if primary_goal == "manage_diabetes":
        diagnosis_hints.append("R73.03 — Prediabetes (demo)")
    if primary_goal == "lower_blood_pressure":
        diagnosis_hints.append("I10 — Essential hypertension (demo)")
    if primary_goal == "weight_loss":
        diagnosis_hints.append("E66.9 — Obesity, unspecified (demo)")
    if not diagnosis_hints:
        diagnosis_hints.append("Z00.00 — Encounter for general adult medical examination (demo)")

    patient = {
        "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
        "email": user.email,
        "sex": prefs.get("sex") or "",
        "age": prefs.get("age"),
        "address_line": "DEMO ADDRESS — not a real patient location",
    }

    last_lab_date = latest.get("test_date")
    order = {
        "demo_only": True,
        "banner": "SAMPLE LAB ORDER — FOR DEMO / TRAINING ONLY — DOES NOT PLACE A REAL LABCORP ORDER",
        "form_title": "Annual Wellness Verified — Laboratory Request (SAMPLE)",
        "lab_header": {
            "organization": "LABCORP c/o Labcorp Employer Services (DEMO)",
            "address": "7221 Lee Deforest Drive, Suite 600, Columbia MD 21046",
            "find_location": "labcorp.com (find a service center)",
            "order_message": "PLEASE PULL ORDER FROM COR. (demo)",
        },
        "patient": patient,
        "physician": {
            "name": "Wellness Program Physician (Demo)",
            "npi": "DEMO-NPI",
            "note": "Signature line shown for familiarity — not a signed order",
        },
        "billing": {
            "type": "03 ACCOUNT BILL (demo employer wellness)",
            "note": "Billing parties shown for layout familiarity only",
        },
        "tests": WELLNESS_TESTS,
        "diagnosis_hints": diagnosis_hints,
        "clinical_reason": reason_lines,
        "narrative": narrative,
        "last_lab_date": last_lab_date,
        "effective_blood_draw_dates": {
            "start": effective_start.isoformat(),
            "end": effective_end.isoformat(),
            "label": f"Effective blood draw dates: {effective_start.isoformat()} - {effective_end.isoformat()}",
        },
        "retest_ready": bool(prefs.get("retest_ready")),
        "outcome_arc": prefs.get("outcome_arc"),
        "goals": [g.get("goal_type") for g in goals],
        "copy_edge": "ORIGINAL-LABORATORY / COPY-CLIENT (demo layout)",
        "talking_point": (
            "In a live program, NutriAI would flag retest readiness after weeks/months of coaching; "
            "the member brings a Labcorp wellness requisition similar to annual wellness draws."
        ),
    }
    return order
