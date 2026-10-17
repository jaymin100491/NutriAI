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
    set_user_plan,
)
from app.db.database import SessionLocal
from app.db import repository as repo
from app.services.professional_meals import build_professional_catalog, PROFESSIONAL_MEALS
from app.services.goal_service import get_goals_for_user, GOAL_DEFINITIONS
from app.services.diet_plan_engine import _nutrition_for_goal, _build_shopping_list, MEAL_TYPES


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

    meat = ["chicken", "turkey", "beef", "steak", "shrimp", "salmon", "cod", "fish"]
    land = ["chicken", "turkey", "beef", "steak"]
    animal = meat + ["yogurt", "paneer", "feta", "cheese", "egg", "omelette", "cottage", "whey", "raita", "honey"]

    scored: List[Tuple[int, Dict[str, Any]]] = []
    for r in catalog:
        if meal_type not in r.get("meal_type", []):
            continue
        name = (r.get("name") or "").lower()
        if any(d in name for d in dislikes):
            continue
        tags = set(t.lower() for t in r.get("dietary_tags", []))
        if dietary == "vegetarian" and any(m in name for m in meat):
            continue
        if dietary == "pescatarian" and any(m in name for m in land):
            continue
        if dietary == "vegan" and (
            any(a in name for a in animal) and "vegan" not in tags
        ):
            # allow explicitly vegan-tagged
            if "vegan" not in tags:
                continue

        score = len(set(goal_tags) & set(r.get("health_tags", [])))
        if cuisine_prefs and r.get("cuisine_type") in cuisine_prefs:
            score += 2
        scored.append((score, r))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [r for _, r in scored] or [r for r in catalog if meal_type in r.get("meal_type", [])]


def generate_weekly_plan(
    user: Dict[str, Any],
    *,
    for_next_week: bool = False,
    lab_summary: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate a Mon–Sun professional weekly plan and archive the previous current plan."""
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
    cuisine_prefs = prefs.get("cuisine_preferences") or [
        "Indian", "Mediterranean", "Mexican", "Thai", "Japanese", "American", "Middle Eastern", "Asian"
    ]

    rng = random.Random(hash(f"{user_id}|{start.isoformat()}|{primary_goal}|{dietary}|{','.join(dislikes)}") & 0xFFFFFFFF)
    meals: List[Dict[str, Any]] = []
    recent_names: List[str] = []

    day = start
    day_num = 1
    while day <= end:
        day_goal = goal_types[(day_num - 1) % len(goal_types)]
        for meal_type in MEAL_TYPES:
            pool = _filter_professional(meal_type, dietary, dislikes, goal_tags, cuisine_prefs)
            pool = [p for p in pool if p["name"] not in recent_names[-8:]] or pool
            recipe = deepcopy(rng.choice(pool[: max(3, min(12, len(pool)))]))
            recent_names.append(recipe["name"])
            meals.append({
                "day": day_num,
                "weekday": day.strftime("%A"),
                "date": day.isoformat(),
                "meal_type": meal_type,
                "recipe_id": recipe["id"],
                "recipe": recipe,
                "cuisine_focus": recipe.get("cuisine_type"),
            })
        day += timedelta(days=1)
        day_num += 1

    primary_label = next((g.get("label") for g in goals if g.get("goal_type") == primary_goal), primary_goal)
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
        "ai_rationale": (
            f"Fixed Mon–Sun plan for {start.isoformat()} → {end.isoformat()}. "
            f"Primary focus: {primary_label}. "
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


def friday_release_next_week(user: Dict[str, Any]) -> Dict[str, Any]:
    """Generate next week's plan (call on Fridays or via admin/manual)."""
    return generate_weekly_plan(user, for_next_week=True)


def schedule_status(user_id: int) -> Dict[str, Any]:
    today = date.today()
    monday, sunday = week_bounds(today)
    n_mon, n_sun = next_week_bounds(today)
    existing = get_user_plan(user_id)
    return {
        "today": today.isoformat(),
        "weekday": today.strftime("%A"),
        "is_friday": is_friday(today),
        "current_week": {"start": monday.isoformat(), "end": sunday.isoformat()},
        "next_week": {"start": n_mon.isoformat(), "end": n_sun.isoformat()},
        "current_plan_week_start": (existing or {}).get("week_start"),
        "next_plan_available": bool(existing and existing.get("week_start") == n_mon.isoformat()),
        "message": (
            "Friday release: next week's Mon–Sun plan is ready to generate from your latest biometrics."
            if is_friday(today)
            else "Track biometrics daily. Your next Mon–Sun plan is prepared every Friday."
        ),
    }
