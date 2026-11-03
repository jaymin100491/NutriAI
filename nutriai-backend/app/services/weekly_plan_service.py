"""
Weekly diet plan scheduling — production rules:

- Plans are fixed Mon–Sun calendar weeks
- Next week's plan is generated/released on Friday
- Recent biometrics influence next week's calorie/macro tilt
- Past plans remain stored for history / improvement review
"""
from __future__ import annotations

import random
from copy import deepcopy
from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Tuple

from app.db.store import (
    get_user_goals,
    get_user_plan,
    get_user_preferences,
    next_plan_id,
    patch_user_plan,
    set_user_plan,
)
from app.db.database import SessionLocal
from app.db import repository as repo
from app.services.professional_meals import build_professional_catalog, PROFESSIONAL_MEALS
from app.services.goal_service import get_goals_for_user, GOAL_DEFINITIONS
from app.services.diet_plan_engine import _nutrition_for_goal, _build_shopping_list, MEAL_TYPES
from app.services.ai_meal_generator import (
    ai_meal_generation_enabled,
    generate_ai_week_meals,
    normalize_cuisine_list,
)


def week_bounds(ref: Optional[date] = None) -> Tuple[date, date]:
    """Return Monday–Sunday for the week containing ref (default today)."""
    d = ref or date.today()
    monday = d - timedelta(days=d.weekday())  # Monday=0
    sunday = monday + timedelta(days=6)
    return monday, sunday


def next_week_bounds(ref: Optional[date] = None) -> Tuple[date, date]:
    monday, _ = week_bounds(ref)
    next_monday = monday + timedelta(days=7)
    return next_monday, next_monday + timedelta(days=6)


def is_friday(ref: Optional[date] = None) -> bool:
    return (ref or date.today()).weekday() == 4


def _biometric_adjustments(user_id: int) -> Dict[str, Any]:
    """Tilt next week's targets using last ~7 days of biometrics."""
    db = SessionLocal()
    try:
        entries = repo.get_tracking_entries(db, user_id, days=14)
    finally:
        db.close()

    notes: List[str] = []
    calorie_delta = 0
    tags: List[str] = []

    if len(entries) < 2:
        return {"calorie_delta": 0, "extra_tags": [], "notes": ["Not enough biometric history yet — using baseline targets."]}

    recent = entries[-7:]
    weights = [e["weight_lbs"] for e in recent if e.get("weight_lbs") is not None]
    glucose = [e["blood_glucose"] for e in recent if e.get("blood_glucose") is not None]
    adherence = [e.get("adherence_percent") for e in recent if e.get("adherence_percent") is not None]

    if len(weights) >= 2:
        delta = weights[-1] - weights[0]
        if delta > 1.5:
            calorie_delta -= 150
            tags += ["lean", "high-protein", "high-fiber"]
            notes.append(f"Weight up ~{delta:.1f} lbs this week — slight calorie reduction and higher protein focus.")
        elif delta < -1.5:
            calorie_delta += 100
            tags += ["nutrient-dense", "balanced"]
            notes.append(f"Weight down ~{abs(delta):.1f} lbs — supporting recovery calories.")

    if glucose:
        avg_g = sum(glucose) / len(glucose)
        if avg_g >= 110:
            tags += ["low-glycemic", "high-fiber", "complex-carbs"]
            notes.append(f"Average glucose ~{avg_g:.0f} — prioritizing low-glycemic meals.")

    if adherence:
        avg_a = sum(float(a) for a in adherence) / len(adherence)
        if avg_a < 70:
            notes.append("Adherence was lower — next week uses simpler, familiar meal patterns.")

    if not notes:
        notes.append("Biometrics stable — maintaining current nutrition targets.")

    return {"calorie_delta": calorie_delta, "extra_tags": list(set(tags)), "notes": notes}


def _recipe_matches_diet(recipe: Dict[str, Any], dietary: str) -> bool:
    """Hard diet gate — never serve chicken/fish/etc. for vegetarian users."""
    dietary = (dietary or "omnivore").lower()
    if dietary in ("", "omnivore"):
        return True

    name = (recipe.get("name") or "").lower()
    protein = (recipe.get("primary_protein") or "").lower()
    tags = {t.lower() for t in (recipe.get("dietary_tags") or [])}
    ingredients = " ".join(
        str((i or {}).get("item") or "").lower() for i in (recipe.get("ingredients") or [])
    )
    haystack = f"{name} {protein} {ingredients}"

    meat = [
        "chicken", "turkey", "beef", "steak", "shrimp", "salmon", "cod", "fish",
        "pork", "lamb", "bacon", "meat", "seafood", "prawn", "tuna", "anchovy",
    ]
    land = ["chicken", "turkey", "beef", "steak", "pork", "lamb", "bacon", "meat"]
    animal = meat + [
        "yogurt", "paneer", "feta", "cheese", "egg", "omelette", "cottage",
        "whey", "raita", "honey", "butter", "ghee", "milk",
    ]

    if dietary == "vegetarian":
        if tags & {"vegetarian", "vegan"}:
            # Still block if name clearly contains meat (bad tagging)
            return not any(m in haystack for m in meat)
        return not any(m in haystack for m in meat)
    if dietary == "pescatarian":
        return not any(m in haystack for m in land)
    if dietary == "vegan":
        if "vegan" in tags:
            return True
        return not any(a in haystack for a in animal)
    return True


def _filter_professional(
    meal_type: str,
    dietary: str,
    dislikes: List[str],
    goal_tags: List[str],
    cuisine_prefs: List[str],
) -> List[Dict[str, Any]]:
    dietary = (dietary or "omnivore").lower()
    dislikes = [d.lower() for d in dislikes if d]
    catalog = build_professional_catalog()

    scored: List[Tuple[int, Dict[str, Any]]] = []
    for r in catalog:
        if meal_type not in r.get("meal_type", []):
            continue
        if not _recipe_matches_diet(r, dietary):
            continue
        name = (r.get("name") or "").lower()
        if any(d in name for d in dislikes):
            continue

        score = len(set(goal_tags) & set(r.get("health_tags", [])))
        if cuisine_prefs and r.get("cuisine_type") in cuisine_prefs:
            score += 2
        scored.append((score, r))

    scored.sort(key=lambda x: x[0], reverse=True)
    ranked = [r for _, r in scored]
    if ranked:
        return ranked
    # Strict fallback — same diet only, never open the full (meat) catalog
    return [
        r for r in catalog
        if meal_type in r.get("meal_type", []) and _recipe_matches_diet(r, dietary)
    ]


def generate_weekly_plan(
    user: Dict[str, Any],
    *,
    for_next_week: bool = False,
    lab_summary: Optional[str] = None,
    allow_ai: bool = True,
) -> Dict[str, Any]:
    """
    Generate a Mon–Sun professional weekly plan and archive the previous current plan.

    Live product path: when AI keys are configured, meals are generated on the fly
    for any diet + cuisine combination. Catalog is fallback (and used for bulk demo seeding).
    """
    user_id = int(user["id"])
    today = date.today()
    if for_next_week:
        start, end = next_week_bounds(today)
        week_label = "Next week"
    else:
        start, end = week_bounds(today)
        week_label = "This week"

    goals = get_goals_for_user(user_id, user) or []
    goal_types = [g["goal_type"] for g in sorted(goals, key=lambda g: g.get("priority", 99))]
    if not goal_types:
        goal_types = ["increase_energy"]
    primary_goal = goal_types[0]
    target_calories, macro_targets, goal_tags = _nutrition_for_goal(primary_goal, goals)

    bio = _biometric_adjustments(user_id)
    target_calories = max(1400, min(2800, int(target_calories) + int(bio["calorie_delta"])))
    goal_tags = list(set(list(goal_tags) + bio.get("extra_tags", [])))

    prefs = get_user_preferences(user_id)
    dietary = prefs.get("dietary_preference") or user.get("dietary_preference") or "omnivore"
    dislikes = prefs.get("dislikes") or []
    cuisine_prefs = normalize_cuisine_list(
        prefs.get("cuisine_preferences")
        or user.get("cuisine_preferences")
        or ["Indian", "Mediterranean", "Mexican", "Thai", "Japanese", "American", "Middle Eastern", "Asian"]
    )

    weekdays: List[str] = []
    d = start
    while d <= end:
        weekdays.append(d.strftime("%A"))
        d += timedelta(days=1)

    meals: List[Dict[str, Any]] = []
    generation_source = "catalog"
    ai_rationale_extra = ""

    goal_labels = [
        next((g.get("label") for g in goals if g.get("goal_type") == gt), gt) for gt in goal_types
    ]

    if allow_ai and ai_meal_generation_enabled():
        ai = generate_ai_week_meals(
            dietary=dietary,
            cuisine_prefs=cuisine_prefs,
            dislikes=dislikes,
            goal_labels=goal_labels,
            target_calories=target_calories,
            week_start=start.isoformat(),
            weekdays=weekdays,
            lab_summary=lab_summary,
            biometric_notes=bio.get("notes"),
        )
        if ai and ai.get("meals"):
            generation_source = "ai_live"
            ai_rationale_extra = ai.get("rationale") or ""
            day = start
            day_num = 1
            by_day: Dict[int, List[Dict[str, Any]]] = {}
            for m in ai["meals"]:
                by_day.setdefault(int(m["day"]), []).append(m)
            while day <= end:
                for m in by_day.get(day_num, []):
                    item = deepcopy(m)
                    item["date"] = day.isoformat()
                    item["weekday"] = day.strftime("%A")
                    meals.append(item)
                day += timedelta(days=1)
                day_num += 1

    if not meals:
        # Catalog fallback (also used when AI keys are not yet configured)
        generation_source = "catalog"
        rng = random.Random(
            hash(f"{user_id}|{start.isoformat()}|{primary_goal}|{dietary}|{','.join(dislikes)}") & 0xFFFFFFFF
        )
        recent_names: List[str] = []
        day = start
        day_num = 1
        while day <= end:
            for meal_type in MEAL_TYPES:
                pool = _filter_professional(meal_type, dietary, dislikes, goal_tags, cuisine_prefs)
                pool = [p for p in pool if p["name"] not in recent_names[-8:]] or pool
                recipe = deepcopy(rng.choice(pool[: max(3, min(12, len(pool)))]))
                recent_names.append(recipe["name"])
                meals.append(
                    {
                        "day": day_num,
                        "weekday": day.strftime("%A"),
                        "date": day.isoformat(),
                        "meal_type": meal_type,
                        "recipe_id": recipe["id"],
                        "recipe": recipe,
                        "cuisine_focus": recipe.get("cuisine_type"),
                    }
                )
            day += timedelta(days=1)
            day_num += 1
        ai_rationale_extra = (
            "Built from the professional meal engine "
            "(add OPENAI_API_KEY or ANTHROPIC_API_KEY for live on-the-fly generation of any cuisine)."
        )

    primary_label = next((g.get("label") for g in goals if g.get("goal_type") == primary_goal), primary_goal)
    source_note = (
        "Live AI chef generated meals for your exact diet + cuisine preferences."
        if generation_source == "ai_live"
        else "Catalog engine used (AI keys not configured or AI unavailable)."
    )
    plan = {
        "id": next_plan_id(),
        "user_id": user_id,
        "title": f"{week_label}: {primary_label} (Mon–Sun)",
        "plan_type": "weekly_fixed",
        "week_start": start.isoformat(),
        "week_end": end.isoformat(),
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "duration_days": 7,
        "goals": goal_types,
        "goal_details": goals,
        "primary_goal": primary_goal,
        "target_calories": target_calories,
        "macro_targets": macro_targets,
        "cuisine_rotation": cuisine_prefs,
        "dietary_preference": dietary,
        "meals": meals,
        "shopping_list": _build_shopping_list(meals),
        "biometric_notes": bio.get("notes", []),
        "generation_source": generation_source,
        "ai_rationale": (
            f"Fixed Mon–Sun plan for {start.isoformat()} → {end.isoformat()}. "
            f"Primary focus: {primary_label}. {source_note} "
            + (ai_rationale_extra + " " if ai_rationale_extra else "")
            + " ".join(bio.get("notes", []))
            + (f" Labs: {lab_summary}" if lab_summary else "")
            + " Next week's plan is prepared every Friday from your biometrics + goals."
        ),
        "released_on": today.isoformat(),
        "customization_count": 0,
        "professional": True,
    }
    return set_user_plan(user_id, plan)


def ensure_current_week_plan(user: Dict[str, Any]) -> Dict[str, Any]:
    """Return current week's plan; create if missing or week rolled over."""
    existing = get_user_plan(int(user["id"]))
    monday, sunday = week_bounds()
    if existing and existing.get("week_start") == monday.isoformat() and existing.get("meals"):
        return existing
    return generate_weekly_plan(user, for_next_week=False)


def regenerate_remaining_days(
    user: Dict[str, Any],
    *,
    effective_after: Optional[date] = None,
) -> Dict[str, Any]:
    """
    Preference change mid-week: keep today + past meals, rebuild only future days.
    Does not archive the current week — patches the current plan in place.
    """
    user_id = int(user["id"])
    today = effective_after or date.today()
    monday, sunday = week_bounds(today)
    existing = get_user_plan(user_id)

    if not existing or existing.get("week_start") != monday.isoformat():
        return generate_weekly_plan(user, for_next_week=False, allow_ai=True)

    prefs = get_user_preferences(user_id)
    dietary = prefs.get("dietary_preference") or user.get("dietary_preference") or "omnivore"
    dislikes = prefs.get("dislikes") or []
    cuisine_prefs = normalize_cuisine_list(
        prefs.get("cuisine_preferences")
        or user.get("cuisine_preferences")
        or ["Indian", "Mediterranean", "Mexican", "Thai", "Japanese", "American"]
    )
    goals = get_goals_for_user(user_id, user) or []
    primary = (goals[0] if goals else {}).get("goal_type") or "increase_energy"
    target_calories, macro_targets, goal_tags = _nutrition_for_goal(primary, goals)
    rng = random.Random(hash(f"{user_id}|remaining|{today.isoformat()}|{dietary}") & 0xFFFFFFFF)

    keep: List[Dict[str, Any]] = []
    for m in existing.get("meals") or []:
        try:
            md = date.fromisoformat(str(m.get("date") or "")[:10])
        except ValueError:
            continue
        if md <= today:
            keep.append(deepcopy(m))

    future: List[Dict[str, Any]] = []
    recent_names: List[str] = [str((m.get("recipe") or {}).get("name") or "") for m in keep][-8:]

    # Prefer AI for remaining days when available
    if ai_meal_generation_enabled():
        weekdays = []
        d0 = monday
        while d0 <= sunday:
            weekdays.append(d0.strftime("%A"))
            d0 += timedelta(days=1)
        goal_labels = [
            next((g.get("label") for g in goals if g.get("goal_type") == gt), gt)
            for gt in [g.get("goal_type") for g in goals if g.get("goal_type")]
        ] or [primary]
        ai = generate_ai_week_meals(
            dietary=dietary,
            cuisine_prefs=cuisine_prefs,
            dislikes=dislikes,
            goal_labels=goal_labels,
            target_calories=int(existing.get("target_calories") or target_calories),
            week_start=monday.isoformat(),
            weekdays=weekdays,
            lab_summary=None,
            biometric_notes=None,
        )
        if ai and ai.get("meals"):
            for m in ai["meals"]:
                try:
                    md = date.fromisoformat(str(m.get("date") or "")[:10])
                except ValueError:
                    # AI may only set day index
                    day_num = int(m.get("day") or 0)
                    if day_num < 1:
                        continue
                    md = monday + timedelta(days=day_num - 1)
                    m = {**m, "date": md.isoformat(), "weekday": md.strftime("%A")}
                if md <= today:
                    continue
                recipe = m.get("recipe") or {}
                if recipe and not _recipe_matches_diet(recipe, dietary):
                    continue
                future.append(deepcopy(m))

    have = {(m.get("date"), m.get("meal_type")) for m in future}
    d = today + timedelta(days=1)
    while d <= sunday:
        for meal_type in MEAL_TYPES:
            key = (d.isoformat(), meal_type)
            if key in have:
                continue
            pool = _filter_professional(meal_type, dietary, dislikes, goal_tags, cuisine_prefs)
            pool = [p for p in pool if p.get("name") not in recent_names[-8:]] or pool
            if not pool:
                continue
            recipe = deepcopy(rng.choice(pool[: max(3, min(10, len(pool)))]))
            recent_names.append(recipe.get("name") or "")
            future.append(
                {
                    "day": (d - monday).days + 1,
                    "weekday": d.strftime("%A"),
                    "date": d.isoformat(),
                    "meal_type": meal_type,
                    "recipe_id": recipe["id"],
                    "recipe": recipe,
                    "cuisine_focus": recipe.get("cuisine_type"),
                    "preference_updated": True,
                }
            )
            have.add(key)
        d += timedelta(days=1)

    merged_meals = sorted(
        keep + future,
        key=lambda m: (str(m.get("date") or ""), str(m.get("meal_type") or "")),
    )
    plan = deepcopy(existing)
    plan["meals"] = merged_meals
    plan["dietary_preference"] = dietary
    plan["cuisine_rotation"] = cuisine_prefs
    plan["target_calories"] = int(existing.get("target_calories") or target_calories)
    plan["macro_targets"] = existing.get("macro_targets") or macro_targets
    plan["shopping_list"] = _build_shopping_list(merged_meals)
    plan["preference_patch"] = {
        "effective_after": today.isoformat(),
        "kept_through": today.isoformat(),
        "regenerated_from": (today + timedelta(days=1)).isoformat() if today < sunday else None,
        "regenerated_to": sunday.isoformat() if today < sunday else None,
        "remaining_meals": len(future),
        "kept_meals": len(keep),
    }
    plan["ai_rationale"] = (
        f"Preferences updated on {today.isoformat()}. "
        f"Meals through today were kept unchanged; "
        f"{len(future)} remaining meals regenerated for {dietary}."
    )
    plan["customization_count"] = int(plan.get("customization_count") or 0) + 1
    return patch_user_plan(user_id, plan)


def friday_release_next_week(user: Dict[str, Any]) -> Dict[str, Any]:
    """Generate next week's plan (call on Fridays or via admin/manual)."""
    return generate_weekly_plan(user, for_next_week=True)


def schedule_status(user_id: int) -> Dict[str, Any]:
    today = date.today()
    monday, sunday = week_bounds(today)
    n_mon, n_sun = next_week_bounds(today)
    existing = get_user_plan(user_id)
    ai_live = ai_meal_generation_enabled()
    return {
        "today": today.isoformat(),
        "weekday": today.strftime("%A"),
        "is_friday": is_friday(today),
        "current_week": {"start": monday.isoformat(), "end": sunday.isoformat()},
        "next_week": {"start": n_mon.isoformat(), "end": n_sun.isoformat()},
        "current_plan_week_start": (existing or {}).get("week_start"),
        "next_plan_available": bool(existing and existing.get("week_start") == n_mon.isoformat()),
        "ai_meal_generation": ai_live,
        "generation_mode": "ai_live" if ai_live else "catalog_fallback",
        "message": (
            "Friday release: next week's Mon–Sun plan is ready to generate from your latest biometrics."
            if is_friday(today)
            else "Track biometrics daily. Your next Mon–Sun plan is prepared every Friday."
        ),
    }
