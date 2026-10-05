"""
Transforms Labcorp patient portal format → NutriAI canonical lab result format.
Used by hospital integrations (Atrium, Novant, Cone Health, etc.)
"""
from __future__ import annotations

import re
from datetime import datetime
from typing import Any, Dict, List, Optional

from app.integrations.labcorp.models import LabcorpResultDetail, LabcorpResultSummary

# Test codes relevant to nutrition / diet planning
NUTRITION_RELEVANT_CODES = {
    "001818", "001198", "001032", "001065", "001172",  # glucose, sodium, cholesterol panel codes
    "070140", "070141", "070142", "706994", "707009",  # vitamins, homocysteine
    "001321", "001453",  # HbA1c, LDL
}

# Category mapping by test/analyte name
CATEGORY_MAP = {
    "glucose": "Metabolic Panel",
    "sodium": "Electrolytes",
    "cholesterol": "Lipid Panel",
    "ldl": "Lipid Panel",
    "hdl": "Lipid Panel",
    "triglyceride": "Lipid Panel",
    "hba1c": "Diabetes Screening",
    "a1c": "Diabetes Screening",
    "vitamin": "Vitamins",
    "homocyst": "Cardiovascular Risk",
    "iron": "Iron Studies",
    "ferritin": "Iron Studies",
    "b12": "Vitamins",
    "vitamin d": "Vitamins",
    "creatinine": "Kidney Function",
}


def _parse_date(iso_date: str) -> str:
    """ISO datetime → YYYY-MM-DD."""
    try:
        return datetime.fromisoformat(iso_date.replace("Z", "+00:00")).strftime("%Y-%m-%d")
    except ValueError:
        return iso_date[:10]


def _flag_to_status(flag: Optional[str], value: str) -> str:
    if not flag or flag == "N":
        return "normal"
    if flag in ("H", "HH", "A"):
        return "high"
    if flag in ("L", "LL"):
        return "low"
    # Non-numeric values
    if value.lower() in ("not detected", "negative"):
        return "normal"
    return "normal"


def _categorize(name: str) -> str:
    lower = name.lower()
    for key, cat in CATEGORY_MAP.items():
        if key in lower:
            return cat
    return "General"


def _is_nutrition_relevant(item_name: str, test_code: Optional[str]) -> bool:
    if test_code and test_code in NUTRITION_RELEVANT_CODES:
        return True
    lower = item_name.lower()
    skip = ["sars", "cov", "influenza", "strep", "culture"]
    if any(s in lower for s in skip):
        return False
    nutrition_keywords = [
        "glucose", "cholesterol", "ldl", "hdl", "triglyceride", "sodium", "potassium",
        "vitamin", "iron", "ferritin", "b12", "hba1c", "a1c", "homocyst", "creatinine",
        "calcium", "magnesium", "phosphorus", "protein", "albumin",
    ]
    return any(k in lower for k in nutrition_keywords)


def _parse_numeric_value(value: str) -> Optional[float]:
    try:
        cleaned = re.sub(r"[^\d.\-]", "", value.split()[0])
        return float(cleaned) if cleaned else None
    except (ValueError, IndexError):
        return None


def detail_to_canonical_tests(detail: LabcorpResultDetail) -> List[Dict[str, Any]]:
    """Convert Labcorp detail analytes to NutriAI test format."""
    tests = []
    for item in detail.results:
        status = _flag_to_status(item.abnormal_flag, item.value)
        numeric = _parse_numeric_value(item.value)

        tests.append({
            "name": item.result_name,
            "value": numeric if numeric is not None else item.value,
            "unit": item.unit or "",
            "reference_range": item.reference_range or "",
            "status": status,
            "category": _categorize(item.result_name),
            "test_code": item.test_code or item.result_code,
            "result_code": item.result_code,
            "abnormal_flag": item.abnormal_flag,
            "nutrition_relevant": _is_nutrition_relevant(item.result_name, item.test_code),
        })
    return tests


def generate_interpretation(tests: List[Dict[str, Any]]) -> Dict[str, Any]:
    """AI-ready clinical interpretation from lab markers."""
    abnormal = [t for t in tests if t["status"] != "normal" and t.get("nutrition_relevant", True)]
    nutrition_tests = [t for t in tests if t.get("nutrition_relevant", True)]

    concerns = []
    recommendations = []

    for t in abnormal:
        name = t["name"]
        val = t["value"]
        unit = t["unit"]
        ref = t["reference_range"]
        concerns.append(f"{name}: {val} {unit} (ref {ref}) — {t['status']}")

        lower = name.lower()
        if "glucose" in lower or "a1c" in lower:
            recommendations.extend([
                "Prioritize low glycemic index foods (legumes, whole grains, non-starchy vegetables)",
                "Reduce refined carbohydrates and added sugars",
                "Pair carbohydrates with protein or healthy fats at each meal",
            ])
        elif "cholesterol" in lower or "ldl" in lower:
            recommendations.extend([
                "Increase soluble fiber intake (oats, beans, apples, psyllium)",
                "Choose lean proteins and omega-3 rich fish 2-3x per week",
                "Limit saturated fat to less than 7% of daily calories",
            ])
        elif "homocyst" in lower:
            recommendations.extend([
                "Increase folate-rich foods (leafy greens, lentils, fortified grains)",
                "Ensure adequate B6 and B12 intake",
            ])
        elif "vitamin" in lower and t["status"] == "low":
            recommendations.append(f"Increase dietary sources of {name} or discuss supplementation with your provider")

    if not concerns:
        summary = "All nutrition-relevant markers are within normal range. Maintain a balanced, whole-food diet."
    else:
        summary = (
            f"Found {len(abnormal)} marker(s) outside optimal range that may benefit from dietary intervention. "
            + "; ".join(concerns[:3])
        )

    # Deduplicate recommendations
    unique_recs = list(dict.fromkeys(recommendations))[:6]

    return {
        "summary": summary,
        "concerns": concerns,
        "recommendations": unique_recs or [
            "Continue current balanced eating pattern",
            "Stay hydrated and maintain regular meal timing",
        ],
        "nutrition_relevant_count": len(nutrition_tests),
        "abnormal_count": len(abnormal),
    }


def to_canonical_lab_result(
    summary: LabcorpResultSummary,
    detail: Optional[LabcorpResultDetail],
    user_id: int,
) -> Dict[str, Any]:
    """Full transformation: Labcorp list item + detail → NutriAI format."""
    test_date = _parse_date(summary.date_of_service)
    tests = detail_to_canonical_tests(detail) if detail else []

    # Build test list from summary if no detail yet
    if not tests:
        for tc in summary.test_codes:
            for rc in tc.result_codes:
                tests.append({
                    "name": rc.result_name,
                    "value": "Pending",
                    "unit": "",
                    "reference_range": "",
                    "status": "pending",
                    "category": _categorize(rc.result_name),
                    "test_code": tc.test_code,
                    "result_code": rc.result_code,
                    "nutrition_relevant": _is_nutrition_relevant(rc.result_name, tc.test_code),
                })

    interpretation = generate_interpretation(tests) if tests and tests[0].get("status") != "pending" else None

    test_names = [tc.test_name for tc in summary.test_codes]
    panel_title = test_names[0] if len(test_names) == 1 else f"{test_names[0]} + {len(test_names) - 1} more"

    return {
        "id": summary.id,
        "user_id": user_id,
        "test_date": test_date,
        "panel_title": panel_title,
        "source": "labcorp",
        "results": {"tests": tests},
        "interpretation": interpretation,
        "labcorp": {
            "pid": summary.pid,
            "patient_name": summary.patient_name,
            "account_name": summary.account_name,
            "ordering_provider": summary.ordering_provider_name,
            "dashboard_category": summary.dashboard_category,
            "date_of_service": summary.date_of_service,
            "ordered_date": summary.ordered_date,
            "report_date": summary.report_date,
            "is_detail_available": summary.is_detail_available,
            "test_codes": [
                {"test_code": tc.test_code, "test_name": tc.test_name}
                for tc in summary.test_codes
            ],
        },
    }


def summary_test_label(summary: LabcorpResultSummary) -> str:
    names = [tc.test_name for tc in summary.test_codes]
    return ", ".join(names)
