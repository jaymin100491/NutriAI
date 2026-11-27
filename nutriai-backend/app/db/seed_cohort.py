"""
Seed an illustrative 55-user demo cohort for stakeholder presentations.

This is DEMO NARRATIVE DATA — not a clinical study. Frame it as a
multi-persona workspace showing how NutriAI looks with longitudinal labs,
mixed outcomes, meal substitutions, and retest-ready sample lab orders.
"""
from __future__ import annotations

import logging
import random
from copy import deepcopy
from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session

from app.core.security import get_password_hash
from app.db import repository as repo
from app.db.models import DietPlanRecord, User
from app.db.seed_cohort_personas import (
    COHORT_MARKER_PREF,
    COHORT_PASSWORD,
    PERSONAS,
    persona_email,
)
from app.db.seed_demo import _biometrics, _build_result, _lipid_glucose_a1c, _marker
from app.db.store import set_user_goals, set_user_preferences
from app.services.goal_service import GOAL_DEFINITIONS
from app.services.professional_meals import build_professional_catalog
from app.services.weekly_plan_service import generate_weekly_plan, week_bounds

logger = logging.getLogger("nutriai")

COHORT_VERSION = "2026.10-cohort-v1"


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _status_ldl(v: float) -> str:
    return "high" if v >= 100 else "normal"


def _status_a1c(v: float) -> str:
    return "high" if v >= 5.7 else "normal"


def _values_at(persona: Dict[str, Any], t: float, mid_worsen: bool = False) -> Dict[str, float]:
    """t=0 baseline, t=1 latest. Optional mid worsen for adjusted arcs."""
    b = persona["baseline"]
    d = persona["delta"]
    out: Dict[str, float] = {}
    for k, base in b.items():
        delta = d.get(k, 0)
        if mid_worsen and 0.35 <= t <= 0.55:
            # temporary setback around mid-journey
            out[k] = float(base) + float(delta) * t + (abs(float(delta)) * 0.35 if delta <= 0 else -abs(float(delta)) * 0.2)
        else:
            out[k] = float(base) + float(delta) * t
    return out


def _panel_for(
    *,
    result_id: int,
    user_id: int,
    patient_name: str,
    test_date: str,
    vals: Dict[str, float],
    panel_title: str,
    height: float = 66.0,
) -> Dict[str, Any]:
    ldl = round(vals["ldl"], 0)
    hdl = round(vals["hdl"], 0)
    trig = round(vals["trig"], 0)
    total = round(ldl + hdl + trig / 5, 0)
    a1c = round(vals["a1c"], 1)
    glu = round(vals["glu"], 0)
    wt = round(vals["wt"], 1)
    sys = int(round(vals["sys"]))
    dia = int(round(sys * 0.62))
    markers = _lipid_glucose_a1c(
        total_chol=total,
        trig=trig,
        hdl=hdl,
        ldl=ldl,
        glucose=glu,
        a1c=a1c,
        creat=0.95,
        egfr=88,
    )
    markers.extend(_biometrics(height, wt, 34 if height < 68 else 38, sys, dia))
    if "vitd" in vals:
        vd = round(vals["vitd"], 0)
        markers.append(
            _marker(
                "Vitamin D, 25-Hydroxy",
                vd,
                "ng/mL",
                "30-100",
                "low" if vd < 30 else "normal",
                "Vitamins",
                "081950",
            )
        )
    if "crp" in vals:
        crp = round(vals["crp"], 1)
        markers.append(
            _marker(
                "C-Reactive Protein, Cardiac",
                crp,
                "mg/L",
                "0-3.0",
                "high" if crp > 3 else "normal",
                "Inflammation",
                "120766",
            )
        )
    panel = _build_result(
        result_id=result_id,
        user_id=user_id,
        test_date=test_date,
        panel_title=panel_title,
        account_name="Employer Wellness / Labcorp LES",
        provider="Wellness Program MD",
        markers=markers,
        source="demo_cohort",
    )
    panel["labcorp"]["patient_name"] = patient_name
    panel["demo_cohort"] = True
    return panel


def _build_goals(persona: Dict[str, Any], latest: Dict[str, float]) -> List[Dict[str, Any]]:
    goals = []
    for i, gt in enumerate(persona["goals"], 1):
        defn = GOAL_DEFINITIONS.get(gt, {"label": gt, "description": ""})
        status = {
            "improved": "improving",
            "mixed": "mixed",
            "flat": "stable",
            "adjusted": "adjusting",
            "early": "new",
        }.get(persona["arc"], "active")
        goals.append(
            {
                "id": i,
                "goal_type": gt,
                "label": defn.get("label", gt),
                "description": defn.get("description", ""),
                "priority": i,
                "status": status,
                "source": "demo_cohort",
                "notes": f"Illustrative arc: {persona['arc']}",
            }
        )
    # attach key lab current/target for primary goal narrative
    if goals:
        g0 = goals[0]
        if g0["goal_type"] == "lower_cholesterol":
            g0["baseline_value"] = persona["baseline"]["ldl"]
            g0["current_value"] = round(latest["ldl"], 0)
            g0["target_value"] = 99
            g0["unit"] = "mg/dL"
        elif g0["goal_type"] == "manage_diabetes":
            g0["baseline_value"] = persona["baseline"]["a1c"]
            g0["current_value"] = round(latest["a1c"], 1)
            g0["target_value"] = 5.6
            g0["unit"] = "%"
        elif g0["goal_type"] == "weight_loss":
            g0["baseline_value"] = persona["baseline"]["wt"]
            g0["current_value"] = round(latest["wt"], 1)
            g0["target_value"] = round(persona["baseline"]["wt"] + min(persona["delta"].get("wt", -10), -5), 1)
            g0["unit"] = "lbs"
        elif g0["goal_type"] == "lower_blood_pressure":
            g0["baseline_value"] = persona["baseline"]["sys"]
            g0["current_value"] = round(latest["sys"], 0)
            g0["target_value"] = 120
            g0["unit"] = "mmHg"
    return goals


def _compact_meals(rng: random.Random, catalog: List[Dict], days: int = 7) -> List[Dict[str, Any]]:
    meals = []
    types = ["breakfast", "lunch", "dinner", "snack"]
    for day in range(1, days + 1):
        for mt in types:
            pool = [r for r in catalog if mt in r.get("meal_type", [])] or catalog
            recipe = deepcopy(rng.choice(pool))
            meals.append(
                {
                    "day": day,
                    "meal_type": mt,
                    "date": "",
                    "recipe_id": recipe["id"],
                    "recipe": recipe,
                }
            )
    return meals


def _apply_meal_swap(meals: List[Dict[str, Any]], swap: Optional[Dict[str, Any]], catalog: List[Dict]) -> Tuple[List[Dict[str, Any]], Optional[Dict[str, Any]]]:
    if not swap:
        return meals, None
    replacement = next((r for r in catalog if r["name"] == swap["to"]), None)
    if not replacement:
        return meals, None
    applied = False
    for m in meals:
        name = (m.get("recipe") or {}).get("name")
        if name == swap["from"] or (not applied and m["meal_type"] in ("lunch", "dinner", "breakfast")):
            if name == swap["from"] or not applied:
                m["recipe"] = deepcopy(replacement)
                m["recipe_id"] = replacement["id"]
                m["substituted"] = True
                m["substitution_note"] = swap["reason"]
                applied = True
                break
    meta = {
        "original": swap["from"],
        "replacement": swap["to"],
        "reason": swap["reason"],
        "demo_story": True,
    }
    return meals, meta


def _tracking_series(
    persona: Dict[str, Any],
    start: date,
    end: date,
    rng: random.Random,
) -> List[Dict[str, Any]]:
    days = (end - start).days
    entries = []
    mid_worsen = bool(persona.get("mid_worsen"))
    # denser in last 45 days
    for offset in range(0, days + 1):
        d = start + timedelta(days=offset)
        t = offset / max(days, 1)
        # sample ~2-3x/week historically, daily last 30 days
        recent = (end - d).days <= 30
        if not recent and offset % 3 != 0:
            continue
        vals = _values_at(persona, t, mid_worsen=mid_worsen)
        adherence = 60 + int(20 * t) + rng.randint(-8, 8)
        if persona["arc"] == "flat":
            adherence = 55 + rng.randint(-10, 10)
        if persona["arc"] == "early":
            adherence = 70 + rng.randint(-5, 10)
        entries.append(
            {
                "date": d.isoformat(),
                "weight_lbs": round(vals["wt"] + rng.uniform(-0.8, 0.8), 1),
                "systolic_bp": int(round(vals["sys"] + rng.uniform(-2, 2))),
                "diastolic_bp": int(round(vals["sys"] * 0.62 + rng.uniform(-1, 1))),
                "blood_glucose": int(round(vals["glu"] + rng.uniform(-3, 3))),
                "mood": 5 + min(4, int(3 * t)) + (1 if persona["arc"] == "improved" else 0),
                "adherence_percent": max(40, min(98, adherence)),
                "sleep_hours": round(6.5 + rng.uniform(-0.5, 1.2), 1),
                "notes": "Demo cohort biometric",
                "source": "demo_cohort",
            }
        )
    return entries


def _lab_dates(months: int, today: date) -> List[date]:
    """Return chronological lab draw dates spanning months (baseline → optional mid → latest)."""
    months = max(1, months)
    span = int(months * 30.5)
    start = today - timedelta(days=span)
    latest = today - timedelta(days=10)
    if months <= 1:
        return [start]
    if months <= 3:
        return [start, latest]
    if months >= 6:
        return sorted(
            {
                start,
                start + timedelta(days=span // 3),
                start + timedelta(days=(2 * span) // 3),
                latest,
            }
        )
    return sorted({start, start + timedelta(days=span // 2), latest})


def cohort_already_seeded(db: Session) -> bool:
    email = persona_email(PERSONAS[0]["slug"])
    return repo.get_user_by_email(db, email) is not None


def seed_demo_cohort(db: Session, *, force: bool = False) -> Dict[str, Any]:
    """Idempotent unless force=True (force re-seeds each persona in place)."""
    if cohort_already_seeded(db) and not force:
        count = sum(1 for p in PERSONAS if repo.get_user_by_email(db, persona_email(p["slug"])))
        logger.info("Demo cohort already present (%s users) — skip", count)
        return {"seeded": False, "reason": "already_exists", "users": count, "version": COHORT_VERSION}

    today = date.today()
    catalog = build_professional_catalog(start_id=8000)
    summary = {
        "seeded": True,
        "version": COHORT_VERSION,
        "users": 0,
        "retest_ready": 0,
        "with_meal_swap": 0,
        "by_arc": {},
        "disclaimer": (
            "Illustrative multi-persona demo workspace — not clinical research. "
            "Use to show product depth for stakeholder demos."
        ),
    }

    for idx, persona in enumerate(PERSONAS):
        email = persona_email(persona["slug"])
        user = repo.get_user_by_email(db, email)
        if user is None:
            user = repo.create_password_user(
                db,
                email=email,
                password_hash=get_password_hash(COHORT_PASSWORD),
                first_name=persona["first"],
                last_name=persona["last"],
            )
        else:
            user.password_hash = get_password_hash(COHORT_PASSWORD)
            user.first_name = persona["first"]
            user.last_name = persona["last"]
            user.is_active = True
            db.commit()

        patient_name = f"{persona['first']} {persona['last']}"
        rng = random.Random(hash(persona["slug"]) & 0xFFFFFFFF)
        height = 64 if persona["sex"] == "F" else 70
        lab_dates = _lab_dates(int(persona["months"]), today)
        mid_worsen = bool(persona.get("mid_worsen"))

        labs = []
        for pi, ld in enumerate(lab_dates):
            t = pi / max(len(lab_dates) - 1, 1)
            vals = _values_at(persona, t, mid_worsen=mid_worsen and 0 < pi < len(lab_dates) - 1)
            title = "Annual Wellness Panel (Lipid + A1c + Glucose + Biometrics)"
            if pi == 0:
                title = "Baseline Wellness Panel — NutriAI kickoff"
            elif pi == len(lab_dates) - 1:
                title = "Follow-up Wellness Panel — post coaching"
            else:
                title = "Interval Wellness Panel — mid program"
            rid = 700000 + idx * 20 + pi
            labs.append(
                _panel_for(
                    result_id=rid,
                    user_id=user.id,
                    patient_name=patient_name,
                    test_date=ld.isoformat(),
                    vals=vals,
                    panel_title=title,
                    height=height,
                )
            )
        repo.save_lab_results(db, user.id, labs)
        latest_vals = _values_at(persona, 1.0)

        goals = _build_goals(persona, latest_vals)
        set_user_goals(user.id, goals)

        diet = persona["diet"]
        if diet in ("halal_omnivore", "kosher_omnivore"):
            diet_pref = "omnivore"
        else:
            diet_pref = diet

        swap = persona.get("swap")
        prefs = {
            COHORT_MARKER_PREF: True,
            "cohort_version": COHORT_VERSION,
            "cohort_slug": persona["slug"],
            "outcome_arc": persona["arc"],
            "retest_ready": bool(persona.get("retest")),
            "demo_months": persona["months"],
            "dietary_preference": diet_pref,
            "diet_label": diet,
            "cuisine_preferences": persona.get("cuisines") or ["Mediterranean", "American"],
            "dislikes": [],
            "substitutions": {},
            "age": persona["age"],
            "sex": persona["sex"],
            "narrative": _narrative(persona, latest_vals),
        }
        if swap:
            prefs["substitutions"] = {swap["from"]: swap["to"]}
            prefs["dislikes"] = [swap["from"].split()[0]]
            prefs["meal_swap_story"] = swap
            summary["with_meal_swap"] += 1
        set_user_preferences(user.id, prefs)

        # Diet plan history: archived weeks + current
        db.query(DietPlanRecord).filter(DietPlanRecord.user_id == user.id).delete()
        db.commit()

        hist_count = min(max(persona["months"] * 2, 2), 12)
        monday, sunday = week_bounds(today)
        for h in range(hist_count, 0, -1):
            ws = monday - timedelta(days=7 * h)
            we = ws + timedelta(days=6)
            meals = _compact_meals(rng, catalog, 7)
            for m in meals:
                m["date"] = (ws + timedelta(days=m["day"] - 1)).isoformat()
            swap_meta = None
            if swap and h == 2:
                meals, swap_meta = _apply_meal_swap(meals, swap, catalog)
            plan = {
                "id": 800000 + idx * 50 + h,
                "user_id": user.id,
                "title": f"Week of {ws.isoformat()}: {GOAL_DEFINITIONS.get(persona['goals'][0], {}).get('label', persona['goals'][0])}",
                "plan_type": "weekly_fixed",
                "week_start": ws.isoformat(),
                "week_end": we.isoformat(),
                "start_date": ws.isoformat(),
                "end_date": we.isoformat(),
                "duration_days": 7,
                "goals": persona["goals"],
                "primary_goal": persona["goals"][0],
                "target_calories": GOAL_DEFINITIONS.get(persona["goals"][0], {}).get("calories", 1800),
                "macro_targets": GOAL_DEFINITIONS.get(persona["goals"][0], {}).get(
                    "macros",
                    {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 30},
                ),
                "meals": meals,
                "shopping_list": {},
                "ai_rationale": prefs["narrative"],
                "biometric_notes": [f"Arc={persona['arc']}", f"Month {persona['months']} journey"],
                "demo_cohort": True,
                "meal_substitution": swap_meta,
                "archived": True,
            }
            db.add(DietPlanRecord(user_id=user.id, payload=plan, is_current=False))
        db.commit()

        # Current week plan via engine (professional)
        user_payload = {
            "id": user.id,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "subscription_tier": "premium",
            "dietary_preference": diet_pref,
            "allergies": [],
        }
        current = generate_weekly_plan(
            user_payload,
            for_next_week=False,
            lab_summary=prefs["narrative"],
            allow_ai=False,  # cohort seed stays offline/fast; live users use AI when keyed
        )
        if swap:
            meals, swap_meta = _apply_meal_swap(current.get("meals") or [], swap, catalog)
            current["meals"] = meals
            current["meal_substitution"] = swap_meta
            current["ai_rationale"] = (current.get("ai_rationale") or "") + f" Meal swap: {swap['reason']}"
            # persist updated current
            row = (
                db.query(DietPlanRecord)
                .filter(DietPlanRecord.user_id == user.id, DietPlanRecord.is_current.is_(True))
                .first()
            )
            if row:
                row.payload = current
                db.commit()

        # Tracking
        start_track = today - timedelta(days=int(persona["months"] * 30.5))
        entries = _tracking_series(persona, start_track, today, rng)
        # milestones at lab dates
        for pi, ld in enumerate(lab_dates):
            key = ld.isoformat()
            for e in entries:
                if e["date"] == key:
                    e["milestone"] = labs[pi]["panel_title"]
                    e["notes"] = labs[pi]["panel_title"]
        if persona.get("retest"):
            entries.append(
                {
                    "date": today.isoformat(),
                    "weight_lbs": round(latest_vals["wt"], 1),
                    "systolic_bp": int(round(latest_vals["sys"])),
                    "diastolic_bp": int(round(latest_vals["sys"] * 0.62)),
                    "blood_glucose": int(round(latest_vals["glu"])),
                    "mood": 7,
                    "adherence_percent": 85,
                    "milestone": "READY FOR RETEST — sample Labcorp-style order available",
                    "notes": "Program cadence suggests follow-up wellness panel",
                    "source": "demo_cohort",
                    "retest_ready": True,
                }
            )
            summary["retest_ready"] += 1
        repo.replace_tracking_entries(db, user.id, entries)

        summary["users"] += 1
        summary["by_arc"][persona["arc"]] = summary["by_arc"].get(persona["arc"], 0) + 1

    logger.info(
        "Demo cohort seeded: %s users, %s retest-ready, %s meal-swaps",
        summary["users"],
        summary["retest_ready"],
        summary["with_meal_swap"],
    )
    return summary


def _narrative(persona: Dict[str, Any], latest: Dict[str, float]) -> str:
    arc = persona["arc"]
    g = persona["goals"][0]
    label = GOAL_DEFINITIONS.get(g, {}).get("label", g)
    b = persona["baseline"]
    if g == "lower_cholesterol":
        metric = f"LDL {b['ldl']:.0f} → {latest['ldl']:.0f} mg/dL"
    elif g == "manage_diabetes":
        metric = f"A1c {b['a1c']:.1f}% → {latest['a1c']:.1f}%"
    elif g == "weight_loss":
        metric = f"Weight {b['wt']:.0f} → {latest['wt']:.0f} lbs"
    elif g == "lower_blood_pressure":
        metric = f"Systolic {b['sys']:.0f} → {latest['sys']:.0f} mmHg"
    else:
        metric = f"Primary focus {label} over {persona['months']} months"
    arc_txt = {
        "improved": "Markers improved on plan.",
        "mixed": "Some markers improved; others flat — plan adjusted.",
        "flat": "Limited change — adherence and plan review recommended.",
        "adjusted": "Mid-program setback; diet adjusted; latest trend improving.",
        "early": "Early in program — retest not yet due.",
    }.get(arc, arc)
    extra = ""
    if persona.get("retest"):
        extra = " RETEST READY: follow-up wellness panel suggested (sample Labcorp-style order)."
    if persona.get("swap"):
        extra += f" Meal substitution story: {persona['swap']['reason']}"
    return f"{metric}. {arc_txt}{extra}"


def cohort_summary(db: Session) -> Dict[str, Any]:
    users = []
    by_arc: Dict[str, int] = {}
    retest = 0
    swaps = 0
    for p in PERSONAS:
        u = repo.get_user_by_email(db, persona_email(p["slug"]))
        if not u:
            continue
        prefs = repo.get_user_preferences(db, u.id) or {}
        arc = prefs.get("outcome_arc", p["arc"])
        by_arc[arc] = by_arc.get(arc, 0) + 1
        if prefs.get("retest_ready"):
            retest += 1
        if prefs.get("meal_swap_story"):
            swaps += 1
        users.append(
            {
                "id": u.id,
                "email": u.email,
                "name": f"{u.first_name} {u.last_name}",
                "slug": p["slug"],
                "goals": p["goals"],
                "arc": arc,
                "retest_ready": bool(prefs.get("retest_ready")),
                "meal_swap": bool(prefs.get("meal_swap_story")),
                "months": p["months"],
                "narrative": prefs.get("narrative"),
            }
        )
    return {
        "version": COHORT_VERSION,
        "total": len(users),
        "retest_ready": retest,
        "with_meal_swap": swaps,
        "by_arc": by_arc,
        "password_hint": COHORT_PASSWORD,
        "email_domain": "cohort.nutriai.app",
        "disclaimer": (
            "Illustrative multi-persona demo workspace for stakeholder presentations. "
            "Not a clinical study, IRB protocol, or proof of Labcorp order volume."
        ),
        "users": users,
    }
