"""
Lab trend engine adapted from chronolab-rag (deterministic math, no LLM required).

Groups a user's stored panels by marker name, compares earliest → latest,
and returns delta / % change / status transitions for the Trends tab.
"""
from __future__ import annotations

import math
import re
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

# Focus panels for nutrition coaching demos
_FOCUS = (
    "cholesterol, total",
    "ldl chol",
    "hdl cholesterol",
    "triglycerides",
    "non-hdl",
    "hemoglobin a1c",
    "glucose",
    "creatinine",
    "egfr",
    "patient weight",
    "body mass index",
    "systolic",
    "diastolic",
    "waist",
)


def _parse_ref(ref: str) -> Tuple[Optional[float], Optional[float]]:
    if not ref:
        return None, None
    clean = ref.replace("–", "-").replace(" ", "")
    try:
        if clean.startswith(">"):
            return float(re.sub(r"[^\d.]", "", clean)), None
        if clean.startswith("<"):
            return None, float(re.sub(r"[^\d.]", "", clean))
        if "-" in clean:
            lo, hi = clean.split("-", 1)
            return float(re.sub(r"[^\d.]", "", lo)), float(re.sub(r"[^\d.]", "", hi))
    except ValueError:
        return None, None
    return None, None


def _status(value: float, low: Optional[float], high: Optional[float]) -> str:
    if low is not None and value < low and not math.isclose(value, low, abs_tol=1e-6):
        return "Low"
    if high is not None and value > high and not math.isclose(value, high, abs_tol=1e-6):
        return "High"
    if low is None and high is None:
        return "Unknown"
    return "Normal"


def _is_focus(name: str) -> bool:
    lower = name.lower()
    return any(k in lower for k in _FOCUS)


def build_lab_trends(lab_results: List[Dict[str, Any]], *, patient_id: str = "patient") -> Dict[str, Any]:
    """
    chronolab-style trends from NutriAI stored lab panels.
    Returns metrics + a mock plain-language summary (deterministic).
    """
    series: Dict[str, List[Dict[str, Any]]] = {}
    for panel in lab_results or []:
        test_date = str(panel.get("test_date") or "")[:10]
        try:
            ts = date.fromisoformat(test_date)
        except ValueError:
            continue
        for test in (panel.get("results") or {}).get("tests") or []:
            name = str(test.get("name") or "").strip()
            if not name or not _is_focus(name):
                continue
            try:
                value = float(test.get("value"))
            except (TypeError, ValueError):
                continue
            key = name.lower()
            lo, hi = _parse_ref(str(test.get("reference_range") or ""))
            series.setdefault(key, []).append(
                {
                    "name": name,
                    "value": value,
                    "unit": str(test.get("unit") or ""),
                    "date": ts.isoformat(),
                    "timestamp": ts,
                    "low": lo,
                    "high": hi,
                    "status": test.get("status") or _status(value, lo, hi),
                }
            )

    trends: List[Dict[str, Any]] = []
    for key, points in series.items():
        if len(points) < 2:
            # Still show single-point markers as baseline-only
            p = points[0]
            trends.append(
                {
                    "test_name": p["name"],
                    "unit": p["unit"],
                    "baseline_value": p["value"],
                    "latest_value": p["value"],
                    "baseline_date": p["date"],
                    "latest_date": p["date"],
                    "delta": 0.0,
                    "percent_change": 0.0,
                    "velocity_per_day": 0.0,
                    "baseline_status": _status(p["value"], p["low"], p["high"]).title()
                    if isinstance(p.get("status"), str) and p["status"] in ("high", "low", "normal")
                    else _status(p["value"], p["low"], p["high"]),
                    "latest_status": _status(p["value"], p["low"], p["high"]),
                    "status_transition": "Normal->Normal",
                    "observation_count": 1,
                    "reference_low": p["low"],
                    "reference_high": p["high"],
                    "points": [{"date": p["date"], "value": p["value"]}],
                }
            )
            continue

        ordered = sorted(points, key=lambda x: x["timestamp"])
        baseline, latest = ordered[0], ordered[-1]
        delta = latest["value"] - baseline["value"]
        pct = 0.0 if baseline["value"] == 0 else (delta / baseline["value"]) * 100.0
        elapsed = max((latest["timestamp"] - baseline["timestamp"]).days, 0)
        velocity = delta / elapsed if elapsed > 0 else 0.0
        b_status = _status(baseline["value"], baseline["low"], baseline["high"])
        l_status = _status(latest["value"], latest["low"], latest["high"])
        trends.append(
            {
                "test_name": latest["name"],
                "unit": latest["unit"] or baseline["unit"],
                "baseline_value": baseline["value"],
                "latest_value": latest["value"],
                "baseline_date": baseline["date"],
                "latest_date": latest["date"],
                "delta": round(delta, 2),
                "percent_change": round(pct, 1),
                "velocity_per_day": round(velocity, 4),
                "baseline_status": b_status,
                "latest_status": l_status,
                "status_transition": f"{b_status}->{l_status}",
                "observation_count": len(ordered),
                "reference_low": latest["low"],
                "reference_high": latest["high"],
                "points": [{"date": p["date"], "value": p["value"]} for p in ordered],
            }
        )

    # Prefer multi-point nutrition markers first
    trends.sort(key=lambda t: (-(t["observation_count"] > 1), t["test_name"]))
    summary = _mock_summary(trends)
    return {
        "patient_id": patient_id,
        "engine": "chronolab-rag-style",
        "panel_count": len(lab_results or []),
        "trend_count": len(trends),
        "trends": trends,
        "summary_text": summary,
        "disclaimer": (
            "Illustrative lab trend view for coaching demos. "
            "Not a diagnosis or treatment recommendation."
        ),
    }


def _mock_summary(trends: List[Dict[str, Any]]) -> str:
    """Deterministic plain-language summary (chronolab mock style)."""
    if not trends:
        return "No numeric lab markers were available to trend yet."
    parts: List[str] = []
    for t in trends:
        if t["observation_count"] < 2:
            continue
        direction = "increased" if t["delta"] > 0 else "decreased" if t["delta"] < 0 else "stayed about the same"
        unit = f" {t['unit']}" if t["unit"] else ""
        parts.append(
            f"{t['test_name']} {direction} from {t['baseline_value']}{unit} "
            f"({t['baseline_date']}) to {t['latest_value']}{unit} ({t['latest_date']}), "
            f"a change of {t['delta']}{unit} ({t['percent_change']}%). "
            f"Status moved {t['status_transition']}."
        )
        if len(parts) >= 6:
            break
    if not parts:
        return "Lab markers are on file, but more than one visit is needed to show a trend."
    return " ".join(parts)
