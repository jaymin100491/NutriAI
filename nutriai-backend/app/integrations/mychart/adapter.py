"""
FHIR R4 (Epic MyChart) → NutriAI canonical lab result transformer.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from app.integrations.mychart.client import FHIR_INTERPRETATION_MAP
from app.integrations.labcorp.adapter import generate_interpretation, _categorize, _parse_date


def _fhir_interpretation_to_status(obs: Dict[str, Any]) -> str:
    interpretations = obs.get("interpretation", [])
    if interpretations:
        code = interpretations[0].get("coding", [{}])[0].get("code", "")
        return FHIR_INTERPRETATION_MAP.get(code, "normal")
    return "normal"


def observations_to_tests(observations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    tests = []
    for obs in observations:
        code = obs.get("code", {}).get("coding", [{}])[0]
        name = code.get("display", "Unknown")
        loinc = code.get("code", "")

        value_qty = obs.get("valueQuantity", {})
        value = value_qty.get("value", obs.get("valueString", "N/A"))
        unit = value_qty.get("unit", "")

        ref_ranges = obs.get("referenceRange", [])
        ref_range = ref_ranges[0].get("text", "") if ref_ranges else ""

        status = _fhir_interpretation_to_status(obs)

        tests.append({
            "name": name,
            "value": value,
            "unit": unit,
            "reference_range": ref_range,
            "status": status,
            "category": _categorize(name),
            "test_code": loinc,
            "result_code": loinc,
            "abnormal_flag": "H" if status == "high" else ("L" if status == "low" else "N"),
            "nutrition_relevant": True,
            "source_format": "fhir",
        })
    return tests


def diagnostic_report_to_canonical(
    report: Dict[str, Any],
    observations: List[Dict[str, Any]],
    user_id: int,
) -> Dict[str, Any]:
    """Transform Epic DiagnosticReport + Observations → NutriAI format."""
    tests = observations_to_tests(observations)
    interpretation = generate_interpretation(tests) if tests else None

    code = report.get("code", {}).get("coding", [{}])[0]
    panel_title = code.get("display", "Lab Panel")
    test_date = _parse_date(report.get("effectiveDateTime", ""))

    performer = (report.get("performer") or [{}])[0].get("display", "Labcorp")
    provider = (report.get("resultsInterpreter") or [{}])[0].get("display", "")
    account = (report.get("basedOn") or [{}])[0].get("display", "")

    return {
        "id": report.get("labcorp_result_id") or hash(report.get("report_id", "")) % 1000000,
        "user_id": user_id,
        "test_date": test_date,
        "panel_title": panel_title,
        "source": "mychart",
        "results": {"tests": tests},
        "interpretation": interpretation,
        "mychart": {
            "fhir_report_id": report.get("report_id"),
            "patient_fhir_id": report.get("patient_id"),
            "resource_type": "DiagnosticReport",
            "status": report.get("status"),
            "issued": report.get("issued"),
            "performer": performer,
        },
        "labcorp": {
            "pid": None,
            "patient_name": report.get("subject", {}).get("display", ""),
            "account_name": account,
            "ordering_provider": provider,
            "dashboard_category": "new" if report.get("status") == "final" else "recent",
            "date_of_service": report.get("effectiveDateTime", ""),
            "ordered_date": report.get("effectiveDateTime", ""),
            "report_date": report.get("issued", ""),
            "is_detail_available": True,
            "test_codes": [{"test_code": code.get("code", ""), "test_name": panel_title}],
            "performing_lab": performer,
        },
    }
