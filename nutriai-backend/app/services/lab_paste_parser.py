"""
Parse copy-pasted lab panel text (Labcorp / MyChart / employer portals).

Accepts common tabular paste formats, e.g.:

  Cholesterol, Total   228   mg/dL   100-199   High
  LDL Chol Calc (NIH)  154   mg/dL   0-99      High
  Hemoglobin A1c       6.2   %       4.8-5.6   High

Or name/value pairs:

  Glucose: 99 mg/dL (65-99)
"""
from __future__ import annotations

import hashlib
import re
from datetime import date
from typing import Any, Dict, List, Optional, Tuple

from app.integrations.labcorp.adapter import generate_interpretation

_STATUS_WORDS = {
    "high": "high",
    "low": "low",
    "normal": "normal",
    "abnormal": "high",
    "critical": "high",
    "h": "high",
    "l": "low",
    "n": "normal",
}

_DATE_RE = re.compile(
    r"(?P<m>\d{1,2})[/-](?P<d>\d{1,2})[/-](?P<y>\d{2,4})"
    r"|(?P<iso>\d{4}-\d{2}-\d{2})"
)

# name + value + optional unit + optional range + optional status
_LINE_RE = re.compile(
    r"^(?P<name>[A-Za-z][A-Za-z0-9 ,./()%+-]{1,80}?)"
    r"[\s:|=]+"
    r"(?P<value><?-?\d+(?:\.\d+)?)"
    r"(?:\s*(?P<unit>[A-Za-z%/µμ][A-Za-z0-9/%·^]*)?)?"
    r"(?:\s*(?:\(|\[)?(?P<ref>[<>]?\d+(?:\.\d+)?\s*[-–to]+\s*[<>]?\d+(?:\.\d+)?|[<>]=?\s*\d+(?:\.\d+)?)"
    r"(?:\)|\])?)?"
    r"(?:\s+(?P<status>High|Low|Normal|Abnormal|Critical|H|L|N))?"
    r"\s*$",
    re.IGNORECASE,
)

_NUTRITION_KEYWORDS = (
    "chol", "ldl", "hdl", "trigly", "glucose", "a1c", "hemoglobin a1c",
    "bmi", "weight", "waist", "blood pressure", "systolic", "diastolic",
    "creatin", "egfr", "vitamin", "b12", "folate", "homocyst", "ferritin",
    "iron", "tsh", "alt", "ast", "bun", "sodium", "potassium",
)


def _categorize(name: str) -> str:
    lower = name.lower()
    if any(k in lower for k in ("chol", "ldl", "hdl", "trigly", "vldl")):
        return "Lipid Panel"
    if "a1c" in lower or "glucose" in lower:
        return "Diabetes Screening" if "a1c" in lower else "Metabolic Panel"
    if any(k in lower for k in ("bmi", "weight", "height", "waist", "systolic", "diastolic", "blood pressure")):
        return "Biometrics"
    if any(k in lower for k in ("creat", "egfr", "bun")):
        return "Kidney Function"
    if any(k in lower for k in ("alt", "ast", "bilirubin")):
        return "Liver"
    if any(k in lower for k in ("sodium", "potassium", "chloride")):
        return "Electrolytes"
    return "General"


def _infer_status(name: str, value: float, ref: str) -> str:
    if not ref:
        return "normal"
    ref_clean = ref.replace("–", "-").replace("to", "-").replace(" ", "")
    try:
        if ref_clean.startswith(">") or ref_clean.startswith(">="):
            threshold = float(re.sub(r"[^\d.]", "", ref_clean))
            return "low" if value < threshold else "normal"
        if ref_clean.startswith("<") or ref_clean.startswith("<="):
            threshold = float(re.sub(r"[^\d.]", "", ref_clean))
            return "high" if value > threshold else "normal"
        if "-" in ref_clean:
            lo_s, hi_s = ref_clean.split("-", 1)
            lo, hi = float(re.sub(r"[^\d.]", "", lo_s)), float(re.sub(r"[^\d.]", "", hi_s))
            if value < lo:
                return "low"
            if value > hi:
                return "high"
    except ValueError:
        pass
    return "normal"


def _is_nutrition_relevant(name: str) -> bool:
    lower = name.lower()
    return any(k in lower for k in _NUTRITION_KEYWORDS)


def _extract_date(text: str) -> Optional[str]:
    match = _DATE_RE.search(text)
    if not match:
        return None
    if match.group("iso"):
        return match.group("iso")
    y = int(match.group("y"))
    if y < 100:
        y += 2000
    try:
        return date(y, int(match.group("m")), int(match.group("d"))).isoformat()
    except ValueError:
        return None


def _stable_result_id(user_id: int, test_date: str, text: str) -> int:
    digest = hashlib.sha1(f"{user_id}:{test_date}:{text[:400]}".encode()).hexdigest()
    # Keep within signed 32-bit-ish positive range used elsewhere
    return int(digest[:8], 16) % 2_000_000_000 + 100_000_000


def parse_pasted_lab_text(text: str) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """Return (markers, detected_date)."""
    markers: List[Dict[str, Any]] = []
    seen = set()
    detected_date = _extract_date(text)

    for raw_line in text.replace("\t", "  ").splitlines():
        line = re.sub(r"\s+", " ", raw_line).strip()
        if not line or len(line) < 4:
            continue
        # Skip obvious headers
        lower = line.lower()
        if lower in {"test", "result", "units", "reference", "status"}:
            continue
        if "reference interval" in lower or "reference range" in lower:
            continue

        match = _LINE_RE.match(line)
        if not match:
            continue

        name = match.group("name").strip(" :-")
        if len(name) < 2:
            continue
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)

        value_s = match.group("value")
        try:
            value: Any = float(value_s)
            if value.is_integer():
                value = int(value)
        except ValueError:
            value = value_s

        unit = (match.group("unit") or "").strip()
        ref = (match.group("ref") or "").strip()
        status_raw = (match.group("status") or "").strip().lower()
        if status_raw in _STATUS_WORDS:
            status = _STATUS_WORDS[status_raw]
        elif isinstance(value, (int, float)):
            status = _infer_status(name, float(value), ref)
        else:
            status = "normal"

        markers.append(
            {
                "name": name,
                "value": value,
                "unit": unit,
                "reference_range": ref.replace("–", "-"),
                "status": status,
                "category": _categorize(name),
                "test_code": "",
                "nutrition_relevant": _is_nutrition_relevant(name),
            }
        )

    return markers, detected_date


def build_pasted_lab_result(
    *,
    user_id: int,
    text: str,
    test_date: Optional[str] = None,
    panel_title: Optional[str] = None,
    source_label: str = "pasted_panel",
    patient_name: str = "Patient",
) -> Dict[str, Any]:
    markers, detected_date = parse_pasted_lab_text(text)
    if len(markers) < 1:
        raise ValueError(
            "Could not find lab markers in the pasted text. "
            "Paste lines like: Cholesterol, Total  228  mg/dL  100-199  High"
        )

    resolved_date = test_date or detected_date or date.today().isoformat()
    title = panel_title or f"Pasted panel ({len(markers)} markers)"
    result_id = _stable_result_id(user_id, resolved_date, text)
    interpretation = generate_interpretation(markers)

    return {
        "id": result_id,
        "user_id": user_id,
        "test_date": resolved_date,
        "test_type": title,
        "panel_title": title,
        "source": source_label,
        "results": {"tests": markers},
        "interpretation": interpretation,
        "labcorp": {
            "account_name": "Manual paste (demo)",
            "ordering_provider": "Self-reported",
            "patient_name": patient_name,
            "pid": None,
            "dashboard_category": "recently_viewed",
            "date_of_service": f"{resolved_date}T12:00:00.000Z",
            "ordered_date": f"{resolved_date}T12:00:00.000Z",
            "report_date": f"{resolved_date}T12:00:00.000Z",
            "is_detail_available": True,
            "test_codes": [{"test_code": "paste", "test_name": title}],
        },
        "import_note": (
            "Imported via copy-paste for demo. "
            "Future: automatic fetch from MyChart, Labcorp, and other health systems."
        ),
    }
