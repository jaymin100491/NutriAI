"""
Live AI meal generation for NutriAI weekly plans.

When OPENAI_API_KEY or ANTHROPIC_API_KEY is set, generate a full Mon–Sun meal
set on the fly for ANY dietary style + cuisine mix (e.g. Mexican vegetarian).
Falls back to None if no key / API error so callers can use the catalog.

Wellness education only — not medical advice.
"""
from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

from app.core.config import settings

logger = logging.getLogger("nutriai.ai_meals")

_MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"]

_SYSTEM = """You are NutriAI's live dietitian chef for a production nutrition coaching app.
Create a practical, appetizing Mon–Sunday meal plan tailored to the patient's
dietary preference, cuisine preferences, goals, dislikes, and calorie target.

Rules:
- Respect dietary preference strictly (vegan = no animal products; vegetarian = no meat/fish; pescatarian = no land meat).
- Prefer requested cuisines heavily (if they want Mexican vegetarian, most meals should feel Mexican/Latin while staying vegetarian).
- If a cuisine is uncommon, still invent authentic-feeling meals for that cuisine + diet.
- Avoid every disliked ingredient/meal.
- Meals must be home-cookable, grocery-store realistic, and professional-sounding.
- Vary dishes across the week; no duplicate meal names.
- Wellness education only — not medical diagnosis or treatment.

Return ONLY valid JSON:
{
  "rationale": "2-3 sentences explaining the plan",
  "meals": [
    {
      "day": 1,
      "weekday": "Monday",
      "meal_type": "breakfast|lunch|dinner|snack",
      "name": "Dish name",
      "cuisine_type": "e.g. Mexican",
      "description": "1 sentence",
      "calories": 400,
      "protein_g": 20,
      "carbs_g": 40,
      "fat_g": 12,
      "fiber_g": 8,
      "ingredients": [{"item": "black beans", "quantity": "1", "unit": "cup"}],
      "health_tags": ["high-fiber", "plant-based"]
    }
  ]
}
Exactly 28 meals: days 1-7 × breakfast, lunch, dinner, snack.
"""


def ai_meal_generation_enabled() -> bool:
    if not getattr(settings, "AI_MEAL_GENERATION", True):
        return False
    return bool(settings.OPENAI_API_KEY or settings.ANTHROPIC_API_KEY)


def normalize_cuisine_list(cuisines: Optional[List[str]]) -> List[str]:
    """Fix common typos and title-case cuisine names."""
    if not cuisines:
        return []
    fixes = {
        "maxican": "Mexican",
        "meixcan": "Mexican",
        "mexcian": "Mexican",
        "mediteranean": "Mediterranean",
        "mediaterranean": "Mediterranean",
        "midle eastern": "Middle Eastern",
        "middle-eastern": "Middle Eastern",
        "veg": "Vegetarian",  # ignore if slipped into cuisine list
    }
    out: List[str] = []
    for c in cuisines:
        raw = (c or "").strip()
        if not raw:
            continue
        key = raw.lower()
        if key in fixes:
            fixed = fixes[key]
            if fixed == "Vegetarian":
                continue
            out.append(fixed)
        else:
            out.append(raw[:1].upper() + raw[1:] if raw else raw)
    # dedupe preserve order
    seen = set()
    uniq = []
    for c in out:
        if c.lower() not in seen:
            seen.add(c.lower())
            uniq.append(c)
    return uniq


def _extract_json(text: str) -> Optional[Dict[str, Any]]:
    text = (text or "").strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    m = re.search(r"\{[\s\S]*\}", text)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError:
        return None


def _call_openai(prompt: str) -> Optional[Dict[str, Any]]:
    if not settings.OPENAI_API_KEY:
        return None
    try:
        import openai

        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            temperature=0.7,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": prompt},
            ],
        )
        return _extract_json(resp.choices[0].message.content or "")
    except Exception as exc:
        logger.warning("OpenAI meal generation failed: %s", exc)
        return None


def _call_anthropic(prompt: str) -> Optional[Dict[str, Any]]:
    if not settings.ANTHROPIC_API_KEY:
        return None
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        resp = client.messages.create(
            model="claude-3-5-haiku-20241022",
            max_tokens=8000,
            system=_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "".join(getattr(b, "text", "") for b in resp.content)
        return _extract_json(text)
    except Exception as exc:
        logger.warning("Anthropic meal generation failed: %s", exc)
        return None


def _recipe_from_ai_meal(meal: Dict[str, Any], recipe_id: int) -> Dict[str, Any]:
    name = (meal.get("name") or "Balanced meal").strip()
    cuisine = meal.get("cuisine_type") or "International"
    meal_type = meal.get("meal_type") or "lunch"
    ingredients = meal.get("ingredients") or [{"item": name, "quantity": "1", "unit": "serving"}]
    return {
        "id": recipe_id,
        "name": name,
        "slug": re.sub(r"[^a-z0-9]+", "-", name.lower())[:80],
        "description": meal.get("description") or f"A {cuisine} {meal_type} aligned to your goals.",
        "cuisine_type": cuisine,
        "meal_type": [meal_type] if isinstance(meal_type, str) else list(meal_type),
        "dietary_tags": [],
        "health_tags": meal.get("health_tags") or ["balanced"],
        "prep_time_minutes": 15,
        "cook_time_minutes": 20,
        "servings": 1,
        "difficulty": "easy",
        "image_url": "",
        "ingredients": ingredients,
        "instructions": [
            "Prep fresh ingredients.",
            f"Cook {name} using healthy methods (grill, bake, steam, or sauté).",
            "Season with herbs and spices; keep salt moderate.",
            "Serve in a portion that fits your daily calorie target.",
        ],
        "nutrition": {
            "calories": int(meal.get("calories") or 400),
            "protein_g": float(meal.get("protein_g") or 20),
            "carbs_g": float(meal.get("carbs_g") or 40),
            "fat_g": float(meal.get("fat_g") or 12),
            "fiber_g": float(meal.get("fiber_g") or 8),
        },
        "primary_protein": (ingredients[0].get("item") if ingredients else "protein"),
        "substitutable_ingredients": [],
        "professional": True,
        "ai_generated": True,
    }


def generate_ai_week_meals(
    *,
    dietary: str,
    cuisine_prefs: List[str],
    dislikes: List[str],
    goal_labels: List[str],
    target_calories: int,
    week_start: str,
    weekdays: List[str],
    lab_summary: Optional[str] = None,
    biometric_notes: Optional[List[str]] = None,
) -> Optional[Dict[str, Any]]:
    """
    Returns {rationale, meals: [plan meal dicts with recipe]} or None.
    """
    if not ai_meal_generation_enabled():
        return None

    cuisines = normalize_cuisine_list(cuisine_prefs) or ["Mediterranean", "American"]
    dietary = (dietary or "omnivore").lower()
    prompt = (
        f"Week starting: {week_start}\n"
        f"Weekdays in order: {', '.join(weekdays)}\n"
        f"Dietary preference: {dietary}\n"
        f"Cuisine preferences (prioritize these): {', '.join(cuisines)}\n"
        f"Dislikes / avoid: {', '.join(dislikes) if dislikes else 'none'}\n"
        f"Goals: {', '.join(goal_labels) if goal_labels else 'general wellness'}\n"
        f"Daily calorie target: {target_calories}\n"
        f"Lab context: {lab_summary or 'n/a'}\n"
        f"Biometric notes: {'; '.join(biometric_notes or []) or 'n/a'}\n"
        "Generate the full 28-meal JSON now."
    )

    data = _call_openai(prompt) or _call_anthropic(prompt)
    if not data or not isinstance(data.get("meals"), list):
        logger.warning("AI meal generation returned no usable meals")
        return None

    raw_meals = data["meals"]
    # Index by (day, meal_type) for reliable ordering
    by_key: Dict[tuple, Dict[str, Any]] = {}
    for m in raw_meals:
        if not isinstance(m, dict):
            continue
        day = int(m.get("day") or 0)
        mt = (m.get("meal_type") or "").lower().strip()
        if day < 1 or day > 7 or mt not in _MEAL_TYPES:
            continue
        by_key[(day, mt)] = m

    plan_meals: List[Dict[str, Any]] = []
    recipe_id_base = 900000
    n = 0
    for day_num, weekday in enumerate(weekdays, start=1):
        for mt in _MEAL_TYPES:
            src = by_key.get((day_num, mt))
            if not src:
                # synthesize minimal placeholder from cuisine — should be rare
                src = {
                    "day": day_num,
                    "weekday": weekday,
                    "meal_type": mt,
                    "name": f"{cuisines[0]} {dietary.title()} {mt.title()}",
                    "cuisine_type": cuisines[0],
                    "description": f"Balanced {cuisines[0]} {mt} for {dietary} diet.",
                    "calories": max(150, target_calories // 4),
                    "protein_g": 18,
                    "carbs_g": 40,
                    "fat_g": 12,
                    "fiber_g": 8,
                    "ingredients": [{"item": "seasonal produce", "quantity": "1", "unit": "serving"}],
                    "health_tags": ["balanced"],
                }
            recipe = _recipe_from_ai_meal(src, recipe_id_base + n)
            n += 1
            plan_meals.append(
                {
                    "day": day_num,
                    "weekday": weekday,
                    "date": "",  # filled by caller
                    "meal_type": mt,
                    "recipe_id": recipe["id"],
                    "recipe": recipe,
                    "cuisine_focus": recipe.get("cuisine_type"),
                    "ai_generated": True,
                }
            )

    if len(plan_meals) < 28:
        logger.warning("AI meal generation incomplete (%s meals)", len(plan_meals))
        return None

    return {
        "rationale": data.get("rationale")
        or f"Live AI plan for {dietary} with {', '.join(cuisines)} focus.",
        "meals": plan_meals,
        "source": "ai_live",
        "cuisines": cuisines,
        "dietary": dietary,
    }
