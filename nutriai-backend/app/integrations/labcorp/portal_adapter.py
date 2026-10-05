"""Map live patient portal API JSON to internal Labcorp models."""
from __future__ import annotations

from typing import Any, Dict, List

from app.integrations.labcorp.models import LabcorpResultDetail, LabcorpResultDetailItem, LabcorpResultSummary


def report_header_to_summary(header: Dict[str, Any]) -> LabcorpResultSummary:
    return LabcorpResultSummary.model_validate(header)


def report_to_detail(report: Dict[str, Any]) -> LabcorpResultDetail:
    header = report.get("header") or report
    ordered_items: List[Dict[str, Any]] = report.get("orderedItems") or []

    items: List[LabcorpResultDetailItem] = []
    for test in ordered_items:
        test_code = test.get("testCode")
        for result in test.get("results") or []:
            if result.get("displayNote"):
                continue
            items.append(
                LabcorpResultDetailItem.model_validate({
                    "resultCode": result.get("number") or result.get("resultCode") or "",
                    "resultName": result.get("name") or "",
                    "testCode": test_code,
                    "value": result.get("value") or result.get("formattedValue") or "",
                    "unit": result.get("units") or "",
                    "referenceRange": result.get("referenceRange") or "",
                    "abnormalFlag": _normalize_flag(result.get("abnormalIndicator")),
                })
            )

    return LabcorpResultDetail(
        id=int(header.get("id")),
        pid=int(header.get("pid")),
        patientName=header.get("patientName") or "",
        dateOfService=header.get("dateOfService") or "",
        reportDate=header.get("reportDate") or "",
        orderingProviderName=header.get("orderingProviderName") or "",
        accountName=header.get("accountName") or "",
        results=items,
    )


def _normalize_flag(flag: Any) -> str:
    if not flag:
        return "N"
    value = str(flag).upper()
    if value in {"H", "L", "A", "N", "HH", "LL"}:
        return value[0] if len(value) > 1 and value in {"HH", "LL"} else value
    if value in {">", "<", "*"}:
        return "A"
    return "N"
