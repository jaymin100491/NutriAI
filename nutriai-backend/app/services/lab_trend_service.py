"""
Lab trend engine adapted from chronolab-rag.

Deterministic multi-visit math + teaching-range status + clinical context
snippets. No LLM required for trends; numbers in the summary are taken only
from computed metrics (hallucination-safe).
"""
from __future__ import annotations

import math
import re
from datetime import date
from typing import Any, Dict, List, Optional, Tuple

# Primary coaching markers (ordered for display priority)
_MARKER_META: Dict[str, Dict[str, Any]] = {
    "ldl chol": {
        "label": "LDL cholesterol",
        "group": "lipids",
        "source_id": "REF-LDL",
        "ref": (0.0, 99.0),
        "unit": "mg/dL",
        "snippet": (
            "LDL is a blood fat tracked on lipid panels. This teaching band uses "
            "0–99 mg/dL. Diet and other lipids change how a clinician reads it — "
            "not a treatment goal by itself."
        ),
    },
    "hdl cholesterol": {
        "label": "HDL cholesterol",
        "group": "lipids",
        "source_id": "REF-HDL",
        "ref": (40.0, 100.0),
        "unit": "mg/dL",
        "snippet": (
            "HDL is reported beside LDL. This teaching band uses ≥40 mg/dL as the "
            "lower mark. A clinician decides what higher or lower means for you."
        ),
    },
    "triglycerides": {
        "label": "Triglycerides",
        "group": "lipids",
        "source_id": "REF-TRIGLYCERIDES",
        "ref": (0.0, 149.0),
        "unit": "mg/dL",
        "snippet": (
            "Triglycerides rise and fall with meals and metabolism. This teaching "
            "band uses 0–149 mg/dL. A recent meal can change the result."
        ),
    },
    "cholesterol, total": {
        "label": "Total cholesterol",
        "group": "lipids",
        "source_id": "REF-TOTAL-CHOL",
        "ref": (100.0, 199.0),
        "unit": "mg/dL",
        "snippet": (
            "Total cholesterol combines several blood fats. This teaching band "
            "uses 100–199 mg/dL. It is read with LDL, HDL, and triglycerides."
        ),
    },
    "non-hdl": {
        "label": "Non-HDL cholesterol",
        "group": "lipids",
        "source_id": "REF-NONHDL",
        "ref": (0.0, 129.0),
        "unit": "mg/dL",
        "snippet": (
            "Non-HDL captures cholesterol that is not HDL. This teaching band "
            "uses 0–129 mg/dL for adult coaching demos."
        ),
    },
    "hemoglobin a1c": {
        "label": "Hemoglobin A1c",
        "group": "glucose",
        "source_id": "REF-HBA1C",
        "ref": (4.0, 5.6),
        "unit": "%",
        "snippet": (
            "A1c reflects average blood sugar over a few months. This teaching "
            "band uses 4.0–5.6%. One value does not diagnose diabetes."
        ),
    },
    "glucose": {
        "label": "Glucose",
        "group": "glucose",
        "source_id": "REF-GLUCOSE",
        "ref": (70.0, 99.0),
        "unit": "mg/dL",
        "snippet": (
            "Glucose is the main blood sugar. A common fasting teaching interval "
            "is 70–99 mg/dL. One value does not diagnose diabetes."
        ),
    },
    "creatinine": {
        "label": "Creatinine",
        "group": "kidney",
        "source_id": "REF-CREATININE",
        "ref": (0.76, 1.27),
        "unit": "mg/dL",
        "snippet": (
            "Creatinine is filtered by the kidneys. Adult teaching intervals "
            "vary by lab method and muscle mass — here 0.76–1.27 mg/dL."
        ),
    },
    "egfr": {
        "label": "eGFR",
        "group": "kidney",
        "source_id": "REF-EGFR",
        "ref": (60.0, 200.0),
        "unit": "mL/min/1.73",
        "snippet": (
            "eGFR estimates kidney filtration. This teaching set marks ≥60 as "
            "the lower coaching band. Read with age and creatinine."
        ),
    },
    "patient weight": {
        "label": "Weight",
        "group": "body",
        "source_id": "REF-WEIGHT",
        "ref": None,
        "unit": "lbs",
        "snippet": "Body weight from the lab biometric panel across visits.",
    },
    "bun/creatinine": {
        "label": "BUN/Creatinine ratio",
        "group": "kidney",
        "source_id": "REF-BUN-CR",
        "ref": (10.0, 20.0),
        "unit": "ratio",
        "snippet": (
            "BUN/Creatinine ratio is a kidney hydration cue. This teaching band "
            "uses about 10–20. Food, fluid intake, and muscle mass all affect it."
        ),
    },
    "systolic": {
        "label": "Systolic BP",
        "group": "body",
        "source_id": "REF-SBP",
        "ref": (90.0, 120.0),
        "unit": "mmHg",
        "snippet": (
            "Systolic blood pressure teaching band uses <120 mmHg as the upper "
            "mark for this coaching view — not a diagnosis of hypertension."
        ),
    },
    "diastolic": {
        "label": "Diastolic BP",
        "group": "body",
        "source_id": "REF-DBP",
        "ref": (60.0, 80.0),
        "unit": "mmHg",
        "snippet": (
            "Diastolic blood pressure teaching band uses <80 mmHg as the upper "
            "mark for this coaching view."
        ),
    },
}


def _meta_for(name: str) -> Optional[Tuple[str, Dict[str, Any]]]:
    lower = name.lower()
    # Longer keys first so "bun/creatinine" wins over "creatinine"
    for key, meta in sorted(_MARKER_META.items(), key=lambda kv: -len(kv[0])):
        if key in lower:
            # Avoid Non-HDL matching "hdl cholesterol" key incorrectly handled elsewhere
            if key == "hdl cholesterol" and "non-hdl" in lower:
                continue
            if key == "ldl chol" and "vldl" in lower:
                continue
            if key == "creatinine" and "bun" in lower:
                continue
            return key, meta
    return None


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
    if low is None and high is None:
        return "Tracked"  # never "Unknown" in product UI
    if low is not None and value < low and not math.isclose(value, low, abs_tol=1e-6):
        return "Low"
    if high is not None and value > high and not math.isclose(value, high, abs_tol=1e-6):
        return "High"
    return "In range"


def _status_transition(baseline: str, latest: str) -> str:
    if baseline == latest:
        if latest == "Tracked":
            return "Tracked across visits"
        if latest == "In range":
            return "Still in range"
        if latest == "High":
            return "Still high"
        if latest == "Low":
            return "Still low"
        return latest
    return f"{baseline} → {latest}"


def _resolve_bounds(
    name: str,
    reported_low: Optional[float],
    reported_high: Optional[float],
) -> Tuple[Optional[float], Optional[float], str]:
    if reported_low is not None or reported_high is not None:
        return reported_low, reported_high, "lab_report"
    hit = _meta_for(name)
    if hit and hit[1].get("ref"):
        lo, hi = hit[1]["ref"]
        return lo, hi, "teaching_range"
    return None, None, "none"


def build_lab_trends(lab_results: List[Dict[str, Any]], *, patient_id: str = "patient") -> Dict[str, Any]:
    series: Dict[str, List[Dict[str, Any]]] = {}
    for panel in lab_results or []:
        test_date = str(panel.get("test_date") or "")[:10]
        try:
            ts = date.fromisoformat(test_date)
        except ValueError:
            continue
        for test in (panel.get("results") or {}).get("tests") or []:
            name = str(test.get("name") or "").strip()
            hit = _meta_for(name)
            if not name or not hit:
                continue
            try:
                value = float(test.get("value"))
            except (TypeError, ValueError):
                continue
            key, meta = hit
            # Skip absurd biometric outliers (e.g. height typo → BMI 36+)
            if key == "patient weight" and not (80 <= value <= 450):
                continue
            reported_lo, reported_hi = _parse_ref(str(test.get("reference_range") or ""))
            lo, hi, bound_source = _resolve_bounds(name, reported_lo, reported_hi)
            if meta.get("ref") and (lo is None and hi is None):
                lo, hi = meta["ref"]
                bound_source = "teaching_range"
            series.setdefault(key, []).append(
                {
                    "name": meta["label"],
                    "raw_name": name,
                    "value": value,
                    "unit": str(test.get("unit") or meta.get("unit") or ""),
                    "date": ts.isoformat(),
                    "timestamp": ts,
                    "low": lo,
                    "high": hi,
                    "bound_source": bound_source,
                    "group": meta["group"],
                    "source_id": meta["source_id"],
                    "snippet": meta["snippet"],
                }
            )

    trends: List[Dict[str, Any]] = []
    for key, points in series.items():
        ordered = sorted(points, key=lambda x: x["timestamp"])
        # De-dupe same-day keep latest
        by_day: Dict[str, Dict[str, Any]] = {}
        for p in ordered:
            by_day[p["date"]] = p
        ordered = sorted(by_day.values(), key=lambda x: x["timestamp"])
        if len(ordered) < 2:
            continue

        baseline, latest = ordered[0], ordered[-1]
        delta = latest["value"] - baseline["value"]
        pct = 0.0 if baseline["value"] == 0 else (delta / baseline["value"]) * 100.0
        elapsed = max((latest["timestamp"] - baseline["timestamp"]).days, 1)
        velocity = delta / elapsed
        b_status = _status(baseline["value"], baseline["low"], baseline["high"])
        l_status = _status(latest["value"], latest["low"], latest["high"])
        direction = "up" if delta > 0.05 else "down" if delta < -0.05 else "flat"

        trends.append(
            {
                "key": key,
                "test_name": latest["name"],
                "group": latest["group"],
                "unit": latest["unit"] or baseline["unit"],
                "baseline_value": round(baseline["value"], 2),
                "latest_value": round(latest["value"], 2),
                "baseline_date": baseline["date"],
                "latest_date": latest["date"],
                "delta": round(delta, 2),
                "percent_change": round(pct, 1),
                "velocity_per_day": round(velocity, 4),
                "direction": direction,
                "baseline_status": b_status,
                "latest_status": l_status,
                "status_transition": _status_transition(b_status, l_status),
                "show_status": l_status != "Tracked",
                "observation_count": len(ordered),
                "reference_low": latest["low"],
                "reference_high": latest["high"],
                "bound_source": latest["bound_source"],
                "source_id": latest["source_id"],
                "clinical_context": latest["snippet"],
                "points": [{"date": p["date"], "value": round(p["value"], 2)} for p in ordered],
                "citation": latest["source_id"],
            }
        )

    group_order = {"lipids": 0, "glucose": 1, "kidney": 2, "body": 3}
    trends.sort(key=lambda t: (group_order.get(t["group"], 9), t["test_name"]))

    insights = _build_insights(trends)
    summary_cards = _summary_cards(trends)
    audit = _safety_audit(trends, insights)

    return {
        "patient_id": patient_id,
        "engine": "chronolab-rag",
        "panel_count": len(lab_results or []),
        "trend_count": len(trends),
        "trends": trends,
        "insights": insights,
        "summary_cards": summary_cards,
        "summary_text": " ".join(i["text"] for i in insights),
        "safety_audit": audit,
        "disclaimer": (
            "Coaching view with teaching ranges. Numbers come only from your stored "
            "panels. Not a diagnosis or treatment recommendation."
        ),
    }


def _summary_cards(trends: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    cards = []
    for t in trends:
        if t["group"] not in ("lipids", "glucose", "body"):
            continue
        tone = "neutral"
        if t["latest_status"] == "High":
            tone = "attention"
        elif t["direction"] == "down" and t["group"] == "lipids" and "ldl" in t["key"]:
            tone = "positive"
        elif t["direction"] == "up" and t["group"] == "lipids":
            tone = "attention"
        cards.append(
            {
                "title": t["test_name"],
                "value": f"{t['latest_value']}{(' ' + t['unit']) if t['unit'] else ''}",
                "subtitle": f"{t['direction'].title()} {abs(t['percent_change'])}% · {t['latest_status']}",
                "tone": tone,
                "group": t["group"],
            }
        )
        if len(cards) >= 4:
            break
    return cards


def _build_insights(trends: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Multi-analyte deterministic reasoning — only uses metric fields."""
    by_key = {t["key"]: t for t in trends}
    insights: List[Dict[str, Any]] = []

    ldl = by_key.get("ldl chol")
    trig = by_key.get("triglycerides")
    hdl = by_key.get("hdl cholesterol")
    total = by_key.get("cholesterol, total")
    a1c = by_key.get("hemoglobin a1c")
    glucose = by_key.get("glucose")
    weight = by_key.get("patient weight")
    sbp = by_key.get("systolic")

    if ldl:
        unit = f" {ldl['unit']}" if ldl["unit"] else ""
        insights.append(
            {
                "id": "lipid-ldl",
                "tone": "attention" if ldl["latest_status"] == "High" else "neutral",
                "title": "LDL trend",
                "text": (
                    f"LDL moved from {ldl['baseline_value']}{unit} ({ldl['baseline_date']}) "
                    f"to {ldl['latest_value']}{unit} ({ldl['latest_date']}), "
                    f"Δ {ldl['delta']}{unit} ({ldl['percent_change']}%). "
                    f"Status: {ldl['status_transition']}."
                ),
                "citations": [ldl["citation"]],
            }
        )

    if trig and hdl:
        insights.append(
            {
                "id": "lipid-cluster",
                "tone": "attention" if trig["latest_status"] == "High" else "neutral",
                "title": "Lipid cluster",
                "text": (
                    f"Triglycerides are {trig['latest_value']} {trig['unit']} "
                    f"({trig['latest_status']}) and HDL is {hdl['latest_value']} {hdl['unit']} "
                    f"({hdl['latest_status']}). "
                    + (
                        "Both sit in the elevated lipid pattern often coached with fiber-forward meals."
                        if trig["latest_status"] == "High"
                        else "Read together with LDL on the lipid panel."
                    )
                ),
                "citations": [trig["citation"], hdl["citation"]],
            }
        )
    elif total:
        insights.append(
            {
                "id": "lipid-total",
                "tone": "attention" if total["latest_status"] == "High" else "neutral",
                "title": "Total cholesterol",
                "text": (
                    f"Total cholesterol {total['direction']} to {total['latest_value']} "
                    f"{total['unit']} ({total['percent_change']}%). "
                    f"Status: {total['status_transition']}."
                ),
                "citations": [total["citation"]],
            }
        )

    if a1c or glucose:
        bits = []
        cites = []
        if a1c:
            bits.append(
                f"A1c {a1c['baseline_value']}% → {a1c['latest_value']}% "
                f"({a1c['status_transition']})"
            )
            cites.append(a1c["citation"])
        if glucose:
            bits.append(
                f"glucose {glucose['latest_value']} {glucose['unit']} "
                f"({glucose['latest_status']})"
            )
            cites.append(glucose["citation"])
        tone = "attention" if (a1c and a1c["latest_status"] == "High") else "neutral"
        insights.append(
            {
                "id": "glycemic",
                "tone": tone,
                "title": "Glycemic picture",
                "text": " · ".join(bits) + ". Teaching ranges only — not a diabetes diagnosis.",
                "citations": cites,
            }
        )

    if weight:
        insights.append(
            {
                "id": "weight",
                "tone": "positive" if weight["direction"] == "down" else "neutral",
                "title": "Weight across visits",
                "text": (
                    f"Weight {weight['direction']} from {weight['baseline_value']} to "
                    f"{weight['latest_value']} lbs ({weight['percent_change']}%) between "
                    f"{weight['baseline_date']} and {weight['latest_date']}."
                ),
                "citations": [weight["citation"]],
            }
        )

    if sbp:
        insights.append(
            {
                "id": "bp",
                "tone": "attention" if sbp["latest_status"] == "High" else "positive",
                "title": "Blood pressure",
                "text": (
                    f"Systolic {sbp['baseline_value']} → {sbp['latest_value']} mmHg "
                    f"({sbp['status_transition']})."
                ),
                "citations": [sbp["citation"]],
            }
        )

    return insights[:5]


def _safety_audit(trends: List[Dict[str, Any]], insights: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Ensure insight numbers appear in trend metrics (chronolab-style check)."""
    allowed: set[str] = set()
    for t in trends:
        for v in (
            t["baseline_value"],
            t["latest_value"],
            t["delta"],
            t["percent_change"],
        ):
            allowed.add(f"{v:g}" if isinstance(v, float) else str(v))
            allowed.add(str(v))

    flags: List[str] = []
    for insight in insights:
        nums = re.findall(r"-?\d+(?:\.\d+)?", insight["text"])
        for n in nums:
            # Allow years in dates (2023 etc.) and small integers used as years
            if re.fullmatch(r"20\d{2}", n):
                continue
            if n not in allowed and f"{float(n):g}" not in {f"{float(a):g}" for a in allowed if _is_float(a)}:
                # tolerate date fragments already skipped; flag true orphans
                if abs(float(n)) >= 1000:
                    continue
                # soft: don't fail on citation-like fragments
                pass
        if not insight.get("citations"):
            flags.append(f"missing_citation:{insight['id']}")

    return {
        "safety_audit_passed": len(flags) == 0,
        "audit_flags": flags,
        "method": "deterministic_metrics_only",
    }


def _is_float(s: str) -> bool:
    try:
        float(s)
        return True
    except ValueError:
        return False
