"""
Sample Labcorp-style wellness lab order page for DEMO ONLY.

Mirrors the familiar Annual Wellness Verified Laboratory Request layout
(employer wellness / LES style) so demos can show "ready for retest → go to Labcorp".
This does NOT place a real lab order.

Tests requested are personalized from the patient's goals, outcome arc,
and prior abnormal markers — not a flat one-size list.
"""
from __future__ import annotations

from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Set

from app.db import repository as repo
from app.services.goal_service import GOAL_DEFINITIONS


# Illustrative Labcorp-style codes (demo only)
TEST_CATALOG: Dict[str, Dict[str, str]] = {
    "lipid_a1c": {
        "code": "363371",
        "name": "LP+CREAT+HB A1C",
        "note": "Lipid profile, creatinine, hemoglobin A1c",
    },
    "biometrics": {
        "code": "101300",
        "name": "BIOMETRICS",
        "note": "Height, weight, BMI, waist, BP",
    },
    "glucose": {
        "code": "001032",
        "name": "GLUCOSE",
        "note": "Fasting glucose",
    },
    "cmp": {
        "code": "322000",
        "name": "COMPREHENSIVE METABOLIC PANEL",
        "note": "Electrolytes, kidney, liver, glucose",
    },
    "a1c": {
        "code": "001453",
        "name": "HEMOGLOBIN A1c",
        "note": "Glycemic control over ~3 months",
    },
    "lipid": {
        "code": "303756",
        "name": "LIPID PANEL WITH LDL",
        "note": "Total chol, HDL, trig, calculated LDL",
    },
    "hs_crp": {
        "code": "120766",
        "name": "HS-CRP",
        "note": "Inflammation / CV risk marker",
    },
    "tsh": {
        "code": "004259",
        "name": "TSH",
        "note": "Thyroid screening (energy / weight context)",
    },
    "vitamin_d": {
        "code": "081950",
        "name": "VITAMIN D, 25-HYDROXY",
        "note": "Often low with inflammation / fatigue goals",
    },
    "cbc": {
        "code": "005009",
        "name": "CBC WITH DIFFERENTIAL",
        "note": "Anemia / infection screen with wellness draw",
    },
    "uric_acid": {
        "code": "001057",
        "name": "URIC ACID",
        "note": "Metabolic / gout-adjacent monitoring",
    },
    "insulin": {
        "code": "004333",
        "name": "INSULIN",
        "note": "Fasting insulin — insulin resistance follow-up",
    },
}


def _goal_types(goals: List[Dict[str, Any]]) -> List[str]:
    out: List[str] = []
    for g in goals:
        gt = (g.get("goal_type") or g.get("id") or "").strip()
        if gt:
            out.append(gt)
    return out


def _abnormal_marker_names(labs: List[Dict[str, Any]]) -> Set[str]:
    names: Set[str] = set()
    for lab in labs[:3]:
        results = lab.get("results") if isinstance(lab.get("results"), dict) else {}
        tests = results.get("tests") or lab.get("tests") or []
        for t in tests:
            if not isinstance(t, dict):
                continue
            status = str(t.get("status") or "").lower()
            name = str(t.get("name") or "").lower()
            if any(s in status for s in ("high", "low", "abnormal", "critical", "borderline")):
                names.add(name)
            # Also catch elevated lipids / glucose by name even if status missing
            for key in ("ldl", "triglyceride", "a1c", "glucose", "hba1c", "crp", "systolic"):
                if key in name:
                    names.add(name)
    return names


def select_tests_for_patient(
    *,
    goal_types: List[str],
    outcome_arc: Optional[str],
    abnormal: Set[str],
) -> List[Dict[str, str]]:
    """Build a personalized demo requisition from care context."""
    keys: List[str] = []

    def add(key: str) -> None:
        if key not in keys and key in TEST_CATALOG:
            keys.append(key)

    # Core wellness draw always present
    add("biometrics")

    goals = set(goal_types)
    if "lower_cholesterol" in goals or "heart_health" in goals:
        add("lipid")
        add("lipid_a1c")
        add("hs_crp")
    if "manage_diabetes" in goals or "blood_sugar" in goals:
        add("a1c")
        add("glucose")
        add("cmp")
        add("insulin")
    if "lower_blood_pressure" in goals:
        add("cmp")
        add("lipid")
    if "weight_loss" in goals or "weight_gain" in goals:
        add("cmp")
        add("tsh")
        add("lipid")
    if "reduce_inflammation" in goals:
        add("hs_crp")
        add("vitamin_d")
        add("cbc")
    if "increase_energy" in goals:
        add("cbc")
        add("tsh")
        add("vitamin_d")
        add("cmp")
    if "gut_health" in goals:
        add("cmp")
        add("cbc")

    # Prior abnormal markers drive extra follow-ups
    joined = " ".join(abnormal)
    if "ldl" in joined or "cholesterol" in joined or "triglyceride" in joined:
        add("lipid")
        add("hs_crp")
    if "a1c" in joined or "glucose" in joined or "hba1c" in joined:
        add("a1c")
        add("glucose")
        add("insulin")
    if "crp" in joined or "inflammation" in joined:
        add("hs_crp")
        add("vitamin_d")
    if "uric" in joined:
        add("uric_acid")

    # Arc-specific emphasis
    if outcome_arc == "flat":
        add("cmp")
        add("lipid_a1c")
    elif outcome_arc == "adjusted":
        add("lipid_a1c")
        add("cmp")
    elif outcome_arc == "improved":
        # Confirm gains with the panels that mattered most
        if "manage_diabetes" in goals:
            add("a1c")
        if "lower_cholesterol" in goals:
            add("lipid")

    # Safe default if somehow empty beyond biometrics
    if len(keys) <= 1:
        add("lipid_a1c")
        add("glucose")

    return [dict(TEST_CATALOG[k]) for k in keys]


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

    goal_list = _goal_types(goals)
    primary_goal = goal_list[0] if goal_list else "lower_cholesterol"
    goal_label = GOAL_DEFINITIONS.get(primary_goal, {}).get("label", primary_goal)
    goal_labels = [
        GOAL_DEFINITIONS.get(g, {}).get("label", g.replace("_", " ").title()) for g in goal_list
    ] or [goal_label]

    abnormal = _abnormal_marker_names(labs)
    tests = select_tests_for_patient(
        goal_types=goal_list,
        outcome_arc=prefs.get("outcome_arc"),
        abnormal=abnormal,
    )

    reason_lines: List[str] = [
        f"Follow-up wellness panel after NutriAI coaching ({prefs.get('demo_months', 'several')} months).",
        f"Care goals driving this draw: {', '.join(goal_labels)}.",
        f"Panel customized for this patient — {len(tests)} tests selected from goals + prior markers.",
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
    elif prefs.get("outcome_arc") == "early":
        reason_lines.append("Early in program — baseline confirmation draw.")

    if abnormal:
        preview = ", ".join(sorted(abnormal)[:4])
        reason_lines.append(f"Prior panels flagged attention on: {preview}.")

    narrative = prefs.get("narrative") or ""

    diagnosis_hints: List[str] = []
    if "lower_cholesterol" in goal_list:
        diagnosis_hints.append("E78.5 — Hyperlipidemia, unspecified (demo)")
    if "manage_diabetes" in goal_list:
        diagnosis_hints.append("R73.03 — Prediabetes (demo)")
    if "lower_blood_pressure" in goal_list:
        diagnosis_hints.append("I10 — Essential hypertension (demo)")
    if "weight_loss" in goal_list:
        diagnosis_hints.append("E66.9 — Obesity, unspecified (demo)")
    if "reduce_inflammation" in goal_list:
        diagnosis_hints.append("M79.3 — Panniculitis, unspecified (demo inflammatory context)")
    if "increase_energy" in goal_list:
        diagnosis_hints.append("R53.83 — Other fatigue (demo)")
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
        "tests": tests,
        "test_selection_basis": {
            "goals": goal_list,
            "outcome_arc": prefs.get("outcome_arc"),
            "prior_abnormal_markers": sorted(abnormal),
            "personalized": True,
        },
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
        "goals": goal_list,
        "copy_edge": "ORIGINAL-LABORATORY / COPY-CLIENT (demo layout)",
        "talking_point": (
            "Retest panels are assembled from this patient's goals and prior markers — "
            "e.g. diabetes focus adds A1c/glucose/insulin; cholesterol focus adds lipids/hs-CRP. "
            "In production, a clinician reviews before the member draws at Labcorp."
        ),
    }
    return order
