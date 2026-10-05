"""
AI goal interpreter — turns ANY free-text wellness goal into a nutrition profile.

Used when the user types something we never hard-coded (skin, hair, jet lag,
shift work, wedding prep, etc.). Falls back to local heuristics if no API key.

Architecture for a strong product:
  free-text goal → AI nutrition profile → catalog diet engine → 7-day plan
"""
from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, Optional

from app.core.config import settings

logger = logging.getLogger("nutriai.goal_ai")

_ALLOWED_TAGS = [
    "high-protein",
    "lean",
    "high-fiber",
    "low-carb",
    "low-glycemic",
    "heart-healthy",
    "omega-3",
    "anti-inflammatory",
    "antioxidant-rich",
    "plant-based",
    "probiotic",
    "iron-rich",
    "complex-carbs",
    "nutrient-dense",
    "balanced",
    "low-sodium-option",
    "potassium-rich",
    "cholesterol-lowering",
]

_SYSTEM = """You are NutriAI's clinical nutrition mapper.
Convert any patient wellness goal into a SAFE, practical daily nutrition profile
for meal planning (wellness education — not medical diagnosis).

Return ONLY valid JSON with this shape:
{
  "label": "short goal label",
  "summary": "1-2 sentence why this nutrition shape fits",
  "calories": 1600-2600 integer,
  "protein_percent": 20-40 integer,
  "carb_percent": 30-55 integer,
  "fat_percent": 20-40 integer,
  "fiber_grams": 25-45 integer,
  "health_tags": ["tag1", "tag2", "tag3"]
}

Rules:
- protein_percent + carb_percent + fat_percent MUST equal 100
- health_tags MUST be chosen ONLY from: """ + ", ".join(_ALLOWED_TAGS) + """
- Prefer 3-5 tags
- Weight loss → lower calories, higher protein
- Muscle / protein → higher protein, adequate carbs
- Skin / hair / nails → anti-inflammatory, antioxidant-rich, omega-3, nutrient-dense, solid protein
- Blood sugar → low-glycemic, high-fiber
- Heart / cholesterol → heart-healthy, high-fiber, omega-3
- Unknown / unusual goals → balanced nutrient-dense plan (never refuse)
"""


def _clamp_profile(data: Dict[str, Any], raw_text: str) -> Dict[str, Any]:
    calories = int(data.get("calories") or 1900)
    calories = max(1400, min(2800, calories))
    protein = int(data.get("protein_percent") or 28)
    carbs = int(data.get("carb_percent") or 42)
    fat = int(data.get("fat_percent") or 30)
    # Normalize macros to 100
    total = max(1, protein + carbs + fat)
    protein = round(protein * 100 / total)
    carbs = round(carbs * 100 / total)
    fat = max(1, 100 - protein - carbs)
    fiber = int(data.get("fiber_grams") or 32)
    fiber = max(20, min(50, fiber))

    tags = [t for t in (data.get("health_tags") or []) if t in _ALLOWED_TAGS]
    if len(tags) < 2:
        tags = ["balanced", "nutrient-dense", "high-fiber"]

    label = (data.get("label") or raw_text[:80]).strip() or raw_text[:80]
    summary = (data.get("summary") or f"Personalized nutrition profile for: {raw_text}").strip()

    return {
        "label": label[:80],
        "summary": summary[:300],
        "calories": calories,
        "macros": {
            "protein_percent": protein,
            "carb_percent": carbs,
            "fat_percent": fat,
            "fiber_grams": fiber,
        },
        "health_tags": tags[:6],
        "source": "ai",
    }


def _call_openai(text: str) -> Optional[Dict[str, Any]]:
    if not settings.OPENAI_API_KEY:
        return None
    try:
        import openai

        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            temperature=0.2,
            max_tokens=400,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": f"Patient goal: {text}"},
            ],
        )
        content = response.choices[0].message.content or "{}"
        return json.loads(content)
    except Exception as exc:
        logger.warning("OpenAI goal interpret failed: %s", exc)
        return None


def _call_anthropic(text: str) -> Optional[Dict[str, Any]]:
    if not settings.ANTHROPIC_API_KEY:
        return None
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        response = client.messages.create(
            model="claude-3-5-haiku-latest",
            max_tokens=400,
            temperature=0.2,
            system=_SYSTEM,
            messages=[{"role": "user", "content": f"Patient goal: {text}"}],
        )
        content = response.content[0].text
        match = re.search(r"\{.*\}", content, re.DOTALL)
        if not match:
            return None
        return json.loads(match.group(0))
    except Exception as exc:
        logger.warning("Anthropic goal interpret failed: %s", exc)
        return None


def interpret_goal_with_ai(text: str) -> Optional[Dict[str, Any]]:
    """
    Returns a normalized nutrition profile dict, or None if AI unavailable.
    Prefers OpenAI gpt-4o-mini (cheap), then Anthropic Haiku.
    """
    raw = (text or "").strip()
    if not raw:
        return None

    data = _call_openai(raw) or _call_anthropic(raw)
    if not data:
        return None
    return _clamp_profile(data, raw)


def ai_available() -> bool:
    return bool(settings.OPENAI_API_KEY or settings.ANTHROPIC_API_KEY)
