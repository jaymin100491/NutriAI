"""
Intelligent diet plan generation engine.
Builds personalized 7-day plans from lab results, prioritized goals, and 1500+ recipe catalog.
"""
from __future__ import annotations

import random
from copy import deepcopy
from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from app.db.store import get_user_plan, get_user_preferences, next_plan_id, set_user_plan, set_user_preferences
from app.services.goal_service import get_goals_for_user
from app.services.recipe_catalog import (
    HEALTH_GOAL_TAGS,
    apply_ingredient_swap,
    get_recipe_catalog,
    search_recipes,
)


MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"]

GOAL_CALORIE_TARGETS = {
    "lower_cholesterol": 1800,
    "weight_loss": 1600,
    "manage_diabetes": 1700,
    "lower_blood_pressure": 1800,
    "muscle_gain": 2400,
    "weight_gain": 2600,
    "more_protein": 2000,
    "increase_energy": 1900,
    "gut_health": 1800,
    "reduce_inflammation": 1750,
    "increase_vitamin_d": 1800,
    "better_sleep": 1800,
    "athletic_performance": 2500,
    "heart_health": 1800,
    "kidney_support": 1800,
}

GOAL_MACRO_PROFILES = {
    "lower_cholesterol": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 35},
    "weight_loss": {"protein_percent": 30, "carb_percent": 40, "fat_percent": 30, "fiber_grams": 30},
    "manage_diabetes": {"protein_percent": 25, "carb_percent": 40, "fat_percent": 35, "fiber_grams": 35},
    "lower_blood_pressure": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 30},
    "muscle_gain": {"protein_percent": 35, "carb_percent": 40, "fat_percent": 25, "fiber_grams": 30},
    "weight_gain": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 28},
    "more_protein": {"protein_percent": 35, "carb_percent": 35, "fat_percent": 30, "fiber_grams": 28},
    "athletic_performance": {"protein_percent": 30, "carb_percent": 45, "fat_percent": 25, "fiber_grams": 30},
    "kidney_support": {"protein_percent": 20, "carb_percent": 55, "fat_percent": 25, "fiber_grams": 30},
    "default": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 30},
}


def _nutrition_for_goal(primary_goal: str, goals: List[Dict[str, Any]]) -> tuple:
    """Calories + macros + recipe tags from primary goal (supports custom nutrition_profile)."""
    primary = next((g for g in goals if g.get("goal_type") == primary_goal), goals[0] if goals else None)
    profile = (primary or {}).get("nutrition_profile") or {}
    calories = profile.get("calories") or GOAL_CALORIE_TARGETS.get(primary_goal, 1800)
    macros = profile.get("macros") or GOAL_MACRO_PROFILES.get(primary_goal, GOAL_MACRO_PROFILES["default"])
    tags = profile.get("health_tags") or []
    return calories, macros, tags


def _filter_recipes_for_user(
    recipes: List[Dict[str, Any]],
    user: Dict[str, Any],
    primary_goal: str,
    recent_ids: List[int],
) -> List[Dict[str, Any]]:
    dietary = (user.get("dietary_preference") or get_user_preferences(user["id"]).get("dietary_preference") or "omnivore").lower()
    allergies = [a.lower() for a in user.get("allergies", [])] or [
        a.lower() for a in get_user_preferences(user["id"]).get("allergies", [])
    ]
    prefs = get_user_preferences(user["id"])
    dislikes = [d.lower() for d in prefs.get("dislikes", [])]

    meat_tokens = ["chicken", "salmon", "beef", "shrimp", "turkey", "cod", "fish", "pork", "lamb", "bacon"]
    land_meat = ["chicken", "beef", "turkey", "pork", "lamb", "bacon"]
    animal_tokens = meat_tokens + ["egg", "paneer", "yogurt", "cheese", "milk", "butter", "ghee", "honey"]

    goal_tags = set(HEALTH_GOAL_TAGS.get(primary_goal, ["nutrient-dense", "balanced"]))
    # Custom / enriched goals may carry their own tags via preferences stash on user
    extra_tags = user.get("_goal_health_tags") or []
    goal_tags |= set(extra_tags)

    safe: List[Dict[str, Any]] = []
    scored: List[tuple] = []

    for r in recipes:
        if r["id"] in recent_ids:
            continue

        ingredients_text = " ".join(i["item"].lower() for i in r.get("ingredients", []))
        name_text = (r.get("name") or "").lower()
        haystack = f"{ingredients_text} {name_text}"
        tags = set(t.lower() for t in r.get("dietary_tags", []))

        if any(a in haystack for a in allergies if a):
            continue
        # Dislikes: match whole tokens (eggplant, shrimp, etc.) in name or ingredients
        blocked = False
        for d in dislikes:
            if not d:
                continue
            if d in haystack:
                blocked = True
                break
        if blocked:
            continue

        if dietary == "vegetarian":
            if tags & {"vegan", "vegetarian"}:
                pass
            elif any(p in haystack for p in meat_tokens):
                continue
        elif dietary == "pescatarian":
            if any(p in haystack for p in land_meat):
                continue
        elif dietary == "vegan":
            if "vegan" in tags:
                pass
            elif any(p in haystack for p in animal_tokens):
                continue

        safe.append(r)
        tag_score = len(goal_tags & set(r.get("health_tags", [])))
        scored.append((tag_score, r))

    scored.sort(key=lambda x: x[0], reverse=True)
    ranked = [r for _, r in scored]
    return ranked if ranked else safe


def _pick_recipe(
    meal_type: str,
    user: Dict[str, Any],
    primary_goal: str,
    recent_ids: List[int],
    rng: random.Random,
    cuisine_hint: Optional[str] = None,
) -> Dict[str, Any]:
    dietary = (
        user.get("dietary_preference")
        or get_user_preferences(int(user["id"])).get("dietary_preference")
        or "omnivore"
    ).lower()

    def _pool(exclude_recent: bool) -> List[Dict[str, Any]]:
        recent = recent_ids if exclude_recent else []
        # Pull a large meal-type slice; hard-filter enforces diet (vegan counts as vegetarian)
        base = search_recipes(meal_type=meal_type, health_goal=primary_goal, limit=300)["recipes"]
        base = _filter_recipes_for_user(base, user, primary_goal, recent)
        if len(base) < 8:
            broader = search_recipes(meal_type=meal_type, limit=400)["recipes"]
            broader = _filter_recipes_for_user(broader, user, primary_goal, recent)
            seen = {r["id"] for r in base}
            base.extend(r for r in broader if r["id"] not in seen)
        if len(base) < 3:
            all_for_meal = [r for r in get_recipe_catalog() if meal_type in r.get("meal_type", [])]
            base = _filter_recipes_for_user(all_for_meal, user, primary_goal, recent)
        if not base:
            base = _filter_recipes_for_user(get_recipe_catalog(), user, primary_goal, recent)
        return base

    candidates = _pool(exclude_recent=True)
    if not candidates:
        # Small vegetarian/vegan pools — allow repeats rather than serving meat
        candidates = _pool(exclude_recent=False)

    if not candidates:
        raise ValueError(f"No recipes available for dietary preference '{dietary}'")

    prefs = get_user_preferences(int(user["id"]))
    cuisine_prefs = prefs.get("cuisine_preferences") or [
        "Indian", "Mediterranean", "Mexican", "Thai", "Japanese", "Italian", "Middle Eastern", "Asian"
    ]

    if cuisine_hint:
        preferred = [r for r in candidates if r.get("cuisine_type") == cuisine_hint]
        if preferred:
            candidates = preferred + [r for r in candidates if r.get("cuisine_type") != cuisine_hint]
    elif cuisine_prefs:
        preferred = [r for r in candidates if r.get("cuisine_type") in cuisine_prefs]
        if preferred:
            mix = preferred[:20] + [r for r in candidates if r not in preferred][:10]
            candidates = mix or candidates

    recipe = deepcopy(rng.choice(candidates[: max(1, min(30, len(candidates)))]))

    for swap_from, swap_to in prefs.get("substitutions", {}).items():
        ingredients_text = " ".join(i["item"].lower() for i in recipe["ingredients"])
        if swap_from in ingredients_text:
            recipe = apply_ingredient_swap(recipe, swap_from, swap_to)

    return recipe


def _build_shopping_list(meals: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, str]]]:
    produce, protein, grains, pantry = set(), set(), set(), set()
    produce_items = {
        "spinach", "broccoli", "kale", "pepper", "zucchini", "tomato", "carrot", "onion",
        "garlic", "lemon", "avocado", "berry", "banana", "cucumber", "beans", "asparagus",
        "mushroom", "cabbage", "eggplant", "okra",
    }
    protein_items = {
        "chicken", "salmon", "tofu", "paneer", "lentil", "chickpea", "turkey", "shrimp",
        "egg", "tempeh", "cod", "bean",
    }
    grain_items = {"quinoa", "rice", "oat", "roti", "millet", "barley", "buckwheat", "pasta", "bread"}

    for meal in meals:
        recipe = meal.get("recipe", {})
        for ing in recipe.get("ingredients", []):
            item = ing["item"]
            item_lower = item.lower()
            entry = f"{item}|{ing.get('quantity', '1')} {ing.get('unit', '')}"

            if any(p in item_lower for p in protein_items):
                protein.add(entry)
            elif any(g in item_lower for g in grain_items):
                grains.add(entry)
            elif any(p in item_lower for p in produce_items):
                produce.add(entry)
            else:
                pantry.add(entry)

    def to_list(s):
        return [{"item": e.split("|")[0], "quantity": e.split("|")[1] if "|" in e else "1"} for e in sorted(s)]

    return {
        "produce": to_list(produce)[:15],
        "protein": to_list(protein)[:10],
        "grains": to_list(grains)[:8],
        "pantry": to_list(pantry)[:12],
    }


def _plan_title(goals: List[Dict[str, Any]]) -> str:
    if not goals:
        return "Personalized 7-Day Wellness Plan"
    primary = goals[0]
    label = primary.get("label", primary.get("goal_type", "Wellness"))
    return f"Chef-Dietitian Plan: {label} Focus (7 Days)"


def generate_diet_plan(
    user: Dict[str, Any],
    duration_days: int = 7,
    goals_override: Optional[List[str]] = None,
    lab_summary: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate a personalized multi-day diet plan with global cuisine rotation."""
    user_id = int(user["id"])
    goals = get_goals_for_user(user_id, user)

    if goals_override:
        goal_types = goals_override
    else:
        goal_types = [g["goal_type"] for g in sorted(goals, key=lambda g: g["priority"])]

    primary_goal = goal_types[0] if goal_types else "increase_energy"
    target_calories, macro_targets, goal_tags = _nutrition_for_goal(primary_goal, goals)

    prefs = get_user_preferences(user_id)
    if prefs.get("dietary_preference"):
        user = {**user, "dietary_preference": prefs["dietary_preference"]}
    if prefs.get("allergies"):
        user = {**user, "allergies": prefs["allergies"]}
    if goal_tags:
        user = {**user, "_goal_health_tags": goal_tags}

    cuisine_rotation = prefs.get("cuisine_preferences") or [
        "Indian", "Mediterranean", "Mexican", "Thai", "Japanese", "Italian", "Middle Eastern", "Asian"
    ]

    base_date = date.today()
    meals = []
    recent_ids: List[int] = []
    # Seed changes when goals/prefs/dislikes change so regenerated plans aren't clones
    seed_material = "|".join(
        [
            str(user_id),
            base_date.isoformat(),
            ",".join(goal_types),
            prefs.get("dietary_preference", "omnivore"),
            ",".join(sorted(prefs.get("dislikes", []))),
            ",".join(cuisine_rotation),
        ]
    )
    rng = random.Random(hash(seed_material) & 0xFFFFFFFF)

    for day in range(duration_days):
        day_date = base_date + timedelta(days=day)
        day_goal = goal_types[day % len(goal_types)] if goal_types else primary_goal
        day_cuisine = cuisine_rotation[day % len(cuisine_rotation)]

        for meal_type in MEAL_TYPES:
            # Dinner gets the day's featured cuisine; other meals rotate nearby
            hint = day_cuisine if meal_type in ("dinner", "lunch") else None
            recipe = _pick_recipe(meal_type, user, day_goal, recent_ids[-12:], rng, cuisine_hint=hint)
            recent_ids.append(recipe["id"])

            meals.append({
                "day": day + 1,
                "date": day_date.isoformat(),
                "meal_type": meal_type,
                "recipe_id": recipe["id"],
                "recipe": recipe,
                "cuisine_focus": recipe.get("cuisine_type"),
            })

    plan = {
        "id": next_plan_id(),
        "user_id": user_id,
        "title": _plan_title(goals),
        "start_date": base_date.isoformat(),
        "end_date": (base_date + timedelta(days=duration_days - 1)).isoformat(),
        "duration_days": duration_days,
        "goals": goal_types,
        "goal_details": goals,
        "primary_goal": primary_goal,
        "target_calories": target_calories,
        "macro_targets": macro_targets,
        "cuisine_rotation": cuisine_rotation,
        "dietary_preference": user.get("dietary_preference", "omnivore"),
        "meals": meals,
        "shopping_list": _build_shopping_list(meals),
        "ai_rationale": _build_rationale(goals, primary_goal, lab_summary, cuisine_rotation),
        "customization_count": 0,
    }

    return set_user_plan(user_id, plan)


def _build_rationale(
    goals: List[Dict[str, Any]],
    primary_goal: str,
    lab_summary: Optional[str],
    cuisine_rotation: Optional[List[str]] = None,
) -> str:
    primary = next((g for g in goals if g["goal_type"] == primary_goal), goals[0] if goals else None)
    parts = []
    if primary:
        parts.append(
            f"Your #{primary['priority']} priority is {primary.get('label', primary_goal)}"
            + (f" (currently {primary.get('current_value')} {primary.get('unit')})" if primary.get("current_value") else "")
            + "."
        )
    if len(goals) > 1:
        secondary = [g.get("label", g["goal_type"]) for g in goals[1:3]]
        parts.append(f"We'll address {', '.join(secondary)} as secondary focuses throughout the week.")
    if lab_summary:
        parts.append(f"Based on your labs: {lab_summary}")
    if cuisine_rotation:
        parts.append(
            f"Meals rotate across {', '.join(cuisine_rotation[:5])} and more — "
            "veg and non-veg options matched to your preferences. Tap “Don’t like this” anytime to swap."
        )
    else:
        parts.append("Every meal is selected from 1,500+ recipes matched to your health profile.")
    return " ".join(parts)


def get_or_create_plan(user: Dict[str, Any]) -> Dict[str, Any]:
    existing = get_user_plan(user["id"])
    if existing and existing.get("meals"):
        return existing
    return generate_diet_plan(user)


def apply_plan_modifications(
    user_id: int,
    swap_from: str,
    swap_to: str,
    apply_to_all_days: bool = True,
) -> Dict[str, Any]:
    """Apply ingredient substitution across the user's current diet plan."""
    plan = get_user_plan(user_id)
    if not plan:
        raise ValueError("No active diet plan")

    modified_count = 0
    for meal in plan["meals"]:
        recipe = meal.get("recipe", {})
        ingredients_text = " ".join(i["item"].lower() for i in recipe.get("ingredients", []))

        if swap_from.lower() in ingredients_text:
            if apply_to_all_days or meal["day"] >= date.today().weekday() + 1:
                new_recipe = apply_ingredient_swap(recipe, swap_from, swap_to)
                meal["recipe"] = new_recipe
                meal["recipe_id"] = new_recipe["id"]
                modified_count += 1

    from app.db.store import add_substitution_preference

    add_substitution_preference(user_id, swap_from, swap_to)
    plan["customization_count"] = plan.get("customization_count", 0) + modified_count
    plan["shopping_list"] = _build_shopping_list(plan["meals"])
    plan["last_customization"] = f"Replaced {swap_from} with {swap_to} in {modified_count} meals"

    return set_user_plan(user_id, plan)


def replace_meal_in_plan(
    user_id: int,
    day: int,
    meal_type: str,
    new_recipe: Dict[str, Any],
) -> Dict[str, Any]:
    """Replace a specific meal in the plan."""
    plan = get_user_plan(user_id)
    if not plan:
        raise ValueError("No active diet plan")

    for meal in plan["meals"]:
        if meal["day"] == day and meal["meal_type"] == meal_type:
            meal["recipe"] = deepcopy(new_recipe)
            meal["recipe_id"] = new_recipe["id"]
            meal["cuisine_focus"] = new_recipe.get("cuisine_type")
            break

    plan["customization_count"] = plan.get("customization_count", 0) + 1
    plan["shopping_list"] = _build_shopping_list(plan["meals"])
    return set_user_plan(user_id, plan)


def suggest_replacement_meal(
    user: Dict[str, Any],
    day: int,
    meal_type: str,
    reason: Optional[str] = None,
    add_to_dislikes: bool = True,
) -> Dict[str, Any]:
    """World-class coach behavior: learn dislike and replace with a better-fit meal."""
    user_id = int(user["id"])
    plan = get_user_plan(user_id)
    if not plan:
        raise ValueError("No active diet plan")

    current = next((m for m in plan["meals"] if m["day"] == day and m["meal_type"] == meal_type), None)
    if not current:
        raise ValueError("Meal not found")

    prefs = get_user_preferences(user_id)
    old_recipe = current.get("recipe") or {}
    old_name = (old_recipe.get("name") or "").lower()

    if add_to_dislikes and old_name:
        # Remember key proteins / dish cues so we don't serve similar again
        tokens = [t for t in old_name.replace(",", " ").split() if len(t) > 3][:3]
        for token in tokens:
            if token not in prefs.setdefault("dislikes", []):
                prefs["dislikes"].append(token)

    if reason:
        prefs.setdefault("dislike_reasons", []).append({"meal": old_name, "reason": reason})

    set_user_preferences(user_id, prefs)

    recent_ids = [m.get("recipe_id") for m in plan["meals"] if m.get("recipe_id")]
    primary_goal = plan.get("primary_goal") or "increase_energy"
    rng = random.Random(user_id + day + hash(meal_type) + hash(tuple(prefs.get("dislikes", []))))
    new_recipe = _pick_recipe(meal_type, user, primary_goal, recent_ids, rng)

    # Ensure we actually swapped
    attempts = 0
    while new_recipe.get("id") == old_recipe.get("id") and attempts < 8:
        new_recipe = _pick_recipe(meal_type, user, primary_goal, recent_ids + [new_recipe["id"]], rng)
        attempts += 1

    plan = replace_meal_in_plan(user_id, day, meal_type, new_recipe)
    plan["last_customization"] = (
        f"Swapped {old_recipe.get('name', 'meal')} → {new_recipe.get('name')} "
        f"({new_recipe.get('cuisine_type', 'global')} cuisine)"
    )
    return set_user_plan(user_id, plan)
