"""
Parse copy-pasted or PDF-extracted lab panel text (Labcorp / MyChart / portals).

Handles:
- Simple paste:  Cholesterol, Total  228  mg/dL  100-199  High
- Labcorp Patient Report layout (name + site code, value, High/Low, unit, ref,
  optional previous result + date on the same collapsed line)
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

_COLLECTED_RE = re.compile(
    r"Date Collected:\s*(?P<m>\d{1,2})[/-](?P<d>\d{1,2})[/-](?P<y>\d{2,4})",
    re.IGNORECASE,
)

_UNIT = (
    r"(?:mg/dL|mmol/L|g/dL|IU/L|mL/min/1\.73|x10E[36]/uL|mmHg|ratio|%|in|lbs|"
    r"pg|fL|ng/mL|ug/dL|µg/dL|uIU/mL|µIU/mL|kg/m2)"
)

# Labcorp collapsed row: Name [01] value [High|Low] [prev value] [prev date] unit ref
_LABCORP_RE = re.compile(
    rf"^(?P<name>[A-Za-z][A-Za-z0-9 ,./()%+-]+?)"
    rf"(?:\s+\d{{2}})?"
    rf"\s+(?P<value><?-?\d+(?:\.\d+)?)"
    rf"(?:\s+(?P<status>High|Low|Normal|Abnormal|Critical)\b)?"
    rf"(?:\s+(?P<prev><?-?\d+(?:\.\d+)?)(?:\s+\d{{1,2}}/\d{{1,2}}/\d{{2,4}})?)?"
    rf"(?:\s+(?P<unit>{_UNIT}))?"
    rf"(?:\s+(?P<ref>(?:[<>]=?\s*\d+(?:\.\d+)?)|(?:\d+(?:\.\d+)?\s*[-–]\s*\d+(?:\.\d+)?)))?"
    rf"(?:\s+Not\s+Estab\.?)?"
    rf".*$",
    re.IGNORECASE,
)

# Simple paste / generic line
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
    "iron", "tsh", "alt", "ast", "bun", "sodium", "potassium", "non-hdl",
)

_SKIP_NAME_PREFIXES = (
    "please note",
    "date created",
    "all rights reserved",
    "if you have received",
    "the previous result",
    "performing lab",
    "ordered items",
    "general comments",
    "icon legend",
    "ref. interval",
    "avg.risk",
    "1/2 avg",
    "2x avg",
    "3x avg",
    "prediabetes",
    "diabetes:",
    "glycemic control",
    "patient id",
    "specimen id",
    "account number",
    "ordering physician",
    "date collected",
    "date received",
    "date reported",
    "panel ",
    "jul ",
    "nc,",
    "columbia",
)

_SKIP_EXACT = {
    "test",
    "result",
    "units",
    "men",
    "women",
    "chemistries",
    "lipids",
    "biometrics",
    "optimal",
    "borderline",
    "near optimal",
    "very high",
    "categories",
}


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
    if any(k in lower for k in ("alt", "ast", "bilirubin", "alkaline")):
        return "Liver"
    if any(k in lower for k in ("sodium", "potassium", "chloride", "carbon dioxide", "calcium")):
        return "Electrolytes"
    if any(k in lower for k in ("wbc", "rbc", "hemoglobin", "hematocrit", "platelet", "neutrophil", "lymph")):
        return "CBC"
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


def _parse_mdy(m: str, d: str, y: str) -> Optional[str]:
    year = int(y)
    if year < 100:
        year += 2000
    try:
        return date(year, int(m), int(d)).isoformat()
    except ValueError:
        return None


def _extract_date(text: str) -> Optional[str]:
    collected = _COLLECTED_RE.search(text)
    if collected:
        return _parse_mdy(collected.group("m"), collected.group("d"), collected.group("y"))
    match = _DATE_RE.search(text)
    if not match:
        return None
    if match.group("iso"):
        return match.group("iso")
    return _parse_mdy(match.group("m"), match.group("d"), match.group("y"))


def _stable_result_id(user_id: int, test_date: str, text: str) -> int:
    digest = hashlib.sha1(f"{user_id}:{test_date}:{text[:400]}".encode()).hexdigest()
    return int(digest[:8], 16) % 2_000_000_000 + 100_000_000


def _looks_like_header(line: str) -> bool:
    lower = line.lower().strip()
    if lower in _SKIP_EXACT:
        return True
    if any(lower.startswith(p) for p in _SKIP_NAME_PREFIXES):
        return True
    if "reference interval" in lower or "reference range" in lower:
        return True
    return False


def _normalize_labcorp_lines(text: str) -> List[str]:
    """Collapse whitespace and merge Labcorp name-only rows with the next value row."""
    raw = [re.sub(r"\s+", " ", line).strip() for line in text.replace("\t", "  ").splitlines()]
    raw = [line for line in raw if line]
    merged: List[str] = []
    i = 0
    while i < len(raw):
        line = raw[i]
        # Name ends with performing-lab site code (01/02) and has no decimal result yet
        if (
            re.search(r"\b\d{2}$", line)
            and not re.search(r"\d+\.\d+", line)
            and not _looks_like_header(line)
            and not re.search(r"Date |Patient ID|Specimen|Account |Ordered |Page ", line, re.I)
            and i + 1 < len(raw)
            and re.match(r"^[<>]?\d", raw[i + 1])
        ):
            line = f"{line} {raw[i + 1]}"
            i += 1
        merged.append(line)
        i += 1
    return merged


def _clean_name(name: str) -> str:
    name = re.sub(r"\s+\d{2}$", "", name.strip(" :-"))
    return re.sub(r"\s+", " ", name).strip()


def _should_keep_marker(name: str, value: float, status: Optional[str], unit: Optional[str], ref: Optional[str]) -> bool:
    lower = name.lower()
    if lower in _SKIP_EXACT or any(lower.startswith(p) for p in _SKIP_NAME_PREFIXES):
        return False
    if len(name) < 3 or len(name) > 80:
        return False
    # Reject footer / address junk that only matched a zip or phone fragment
    if value >= 1000 and not unit and not status and not _is_nutrition_relevant(name):
        return False
    if value in (1.0, 2.0) and not status and not unit and not ref and not _is_nutrition_relevant(name):
        # Likely captured the Labcorp site code as the value
        return False
    # Prefer rows with lab evidence; allow known biometrics without unit
    if unit or status or ref:
        return True
    if _is_nutrition_relevant(name) or lower in {
        "body mass index",
        "egfr",
        "bun/creatinine ratio",
        "non-hdl cholesterol",
    }:
        return True
    return False


def _marker_dict(
    name: str,
    value: Any,
    unit: str,
    ref: str,
    status: str,
) -> Dict[str, Any]:
    return {
        "name": name,
        "value": value,
        "unit": unit,
        "reference_range": ref.replace("–", "-"),
        "status": status,
        "category": _categorize(name),
        "test_code": "",
        "nutrition_relevant": _is_nutrition_relevant(name),
    }


def parse_pasted_lab_text(text: str) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """Return (markers, detected_date). Prefers Labcorp layout, falls back to simple lines."""
    markers: List[Dict[str, Any]] = []
    seen = set()
    detected_date = _extract_date(text)

    for line in _normalize_labcorp_lines(text):
        if len(line) < 4 or _looks_like_header(line):
            continue

        match = _LABCORP_RE.match(line) or _LINE_RE.match(line)
        if not match:
            continue

        name = _clean_name(match.group("name"))
        key = name.lower()
        if key in seen:
            continue

        value_s = match.group("value")
        try:
            value: Any = float(value_s)
            if isinstance(value, float) and value.is_integer():
                value = int(value)
        except ValueError:
            value = value_s

        unit = (match.groupdict().get("unit") or "").strip()
        ref = (match.groupdict().get("ref") or "").strip()
        status_raw = (match.groupdict().get("status") or "").strip().lower()

        if not isinstance(value, (int, float)):
            continue
        if not _should_keep_marker(name, float(value), status_raw or None, unit or None, ref or None):
            continue

        if status_raw in _STATUS_WORDS:
            status = _STATUS_WORDS[status_raw]
        else:
            status = _infer_status(name, float(value), ref)

        seen.add(key)
        markers.append(_marker_dict(name, value, unit, ref, status))

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
            "Could not find lab markers in the uploaded/pasted text. "
            "Use a Labcorp PDF Patient Report or paste lines like: "
            "Cholesterol, Total  228  mg/dL  100-199  High"
        )

    resolved_date = test_date or detected_date or date.today().isoformat()
    title = panel_title or f"Lab panel ({len(markers)} markers)"
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
        "raw_text_preview": text[:1500],
        "labcorp": {
            "account_name": "PDF / paste import",
            "ordering_provider": "Imported report",
            "patient_name": patient_name,
            "pid": None,
            "dashboard_category": "recently_viewed",
            "date_of_service": f"{resolved_date}T12:00:00.000Z",
            "ordered_date": f"{resolved_date}T12:00:00.000Z",
            "report_date": f"{resolved_date}T12:00:00.000Z",
            "is_detail_available": True,
            "test_codes": [{"test_code": "import", "test_name": title}],
        },
        "import_note": (
            "Imported from uploaded PDF or pasted panel. "
            "Markers are stored for history, goals, and weekly plan generation."
        ),
    }
