"""
AI Dietitian chat — grounded in the user's actual current week plan.
Uses OpenAI/Claude with a full meal inventory; never invents dishes.
"""
from __future__ import annotations

import re
from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Tuple

from app.core.config import settings
from app.db.mock_data import MOCK_USERS
from app.db.store import (
    add_chat_message,
    add_substitution_preference,
    get_chat_history,
    get_user_plan,
    get_user_preferences,
)
from app.services.diet_plan_engine import apply_plan_modifications, generate_diet_plan, get_or_create_plan
from app.services.goal_service import get_goals_for_user, parse_priority_from_message, update_goal_priorities
from app.services.recipe_catalog import get_substitution_options

SWAP_PATTERNS = [
    r"(?:change|swap|replace|substitute)\s+(\w+)\s+(?:to|with|for)\s+(\w+)",
    r"(?:don'?t|do not)\s+like\s+(\w+).*(?:use|try|want|prefer)\s+(\w+)",
    r"(?:instead of|rather than)\s+(\w+).*(?:use|try|want|have)\s+(\w+)",
    r"(\w+)\s+instead\s+of\s+(\w+)",
    r"no\s+(\w+).*(?:give me|want|prefer)\s+(\w+)",
]

REGENERATE_PATTERNS = [
    r"(?:regenerate|new plan|fresh plan|start over|redo)",
    r"(?:generate|create)\s+(?:a\s+)?new\s+(?:diet\s+)?plan",
]

PRIORITY_PATTERNS = [
    r"first.*(?:then|before)",
    r"focus\s+on",
    r"priority",
    r"fix\s+\w+\s+first",
]

MEAL_TYPES = ("breakfast", "lunch", "dinner", "snack")


def _get_user(user_id: int) -> Dict[str, Any]:
    from app.db.database import SessionLocal
    from app.db import repository as repo

    prefs = get_user_preferences(user_id)
    db = SessionLocal()
    try:
        user = repo.get_user_by_id(db, user_id)
        if user:
            return {
                "id": user.id,
                "email": user.email,
                "first_name": user.first_name or "Patient",
                "last_name": user.last_name or "",
                "dietary_preference": prefs.get("dietary_preference") or "omnivore",
                "allergies": prefs.get("allergies") or [],
                "medical_conditions": prefs.get("medical_conditions") or [],
            }
    finally:
        db.close()
    return next((u for u in MOCK_USERS if u["id"] == user_id), MOCK_USERS[0])


def _get_latest_lab(user_id: int) -> Optional[Dict[str, Any]]:
    from app.db.database import SessionLocal
    from app.services.lab_result_service import get_lab_results_for_user

    db = SessionLocal()
    try:
        results = get_lab_results_for_user(db, user_id)
    finally:
        db.close()
    if not results:
        return None
    return results[0]


def _current_plan(user_id: int) -> Optional[Dict[str, Any]]:
    """Prefer the saved current week plan (same as Plan tab) — never invent another."""
    plan = get_user_plan(user_id)
    if plan and plan.get("meals"):
        return plan
    return None


def _meal_recipe(meal: Dict[str, Any]) -> Dict[str, Any]:
    recipe = meal.get("recipe")
    return recipe if isinstance(recipe, dict) else {}


def _format_ingredient(ing: Dict[str, Any]) -> str:
    qty = str(ing.get("quantity") or "").strip()
    unit = str(ing.get("unit") or "").strip()
    item = str(ing.get("item") or "").strip()
    notes = str(ing.get("notes") or "").strip()
    amount = " ".join(p for p in (qty, unit) if p).strip()
    line = f"{amount} {item}".strip() if amount else item
    if notes:
        line = f"{line} ({notes})"
    return line


def _format_plan_inventory(plan: Dict[str, Any], *, detailed: bool = True) -> str:
    meals = plan.get("meals") or []
    if not meals:
        return "No meals on the current plan."
    lines: List[str] = []
    for meal in meals:
        recipe = _meal_recipe(meal)
        name = recipe.get("name") or "Untitled meal"
        mtype = str(meal.get("meal_type") or "").lower()
        day = meal.get("weekday") or f"Day {meal.get('day')}"
        d = str(meal.get("date") or "")[:10]
        cals = (recipe.get("nutrition") or {}).get("calories", "")
        lines.append(f"- {d} ({day}) {mtype}: {name}" + (f" · {cals} kcal" if cals != "" else ""))
        if detailed:
            ings = recipe.get("ingredients") or []
            if ings:
                lines.append(
                    "  Ingredients: "
                    + "; ".join(_format_ingredient(i) for i in ings if isinstance(i, dict))
                )
            steps = recipe.get("instructions") or []
            if steps:
                lines.append("  Steps: " + " | ".join(f"{i+1}. {s}" for i, s in enumerate(steps[:8])))
    return "\n".join(lines)


def _parse_iso(d: str) -> Optional[date]:
    try:
        return date.fromisoformat(str(d)[:10])
    except ValueError:
        return None


def _resolve_target_date(message: str, today: date) -> date:
    msg = message.lower()
    if "tomorrow" in msg or "tmrw" in msg:
        return today + timedelta(days=1)
    if "yesterday" in msg:
        return today - timedelta(days=1)
    # weekday names
    weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    for i, name in enumerate(weekdays):
        if name in msg:
            delta = (i - today.weekday()) % 7
            return today + timedelta(days=delta)
    return today


def _detect_meal_type(message: str) -> Optional[str]:
    msg = message.lower()
    for m in MEAL_TYPES:
        if m in msg:
            return m
    if "brunch" in msg:
        return "breakfast"
    return None


def _meals_for_date(plan: Dict[str, Any], target: date) -> List[Dict[str, Any]]:
    out = []
    for meal in plan.get("meals") or []:
        d = _parse_iso(str(meal.get("date") or ""))
        if d == target:
            out.append(meal)
    return out


def _cook_card(meal: Dict[str, Any]) -> str:
    recipe = _meal_recipe(meal)
    name = recipe.get("name") or "Meal"
    mtype = str(meal.get("meal_type") or "").title()
    d = str(meal.get("date") or "")[:10]
    weekday = meal.get("weekday") or ""
    nutrition = recipe.get("nutrition") or {}
    ings = recipe.get("ingredients") or []
    steps = recipe.get("instructions") or []
    prep = recipe.get("prep_time_minutes")
    cook = recipe.get("cook_time_minutes")
    servings = recipe.get("servings") or 1

    parts = [
        f"**{name}** ({mtype} · {weekday} {d})",
        f"Servings: {servings}"
        + (f" · Prep {prep} min" if prep is not None else "")
        + (f" · Cook {cook} min" if cook is not None else ""),
    ]
    if nutrition:
        parts.append(
            f"Nutrition: {nutrition.get('calories', '—')} kcal · "
            f"P {nutrition.get('protein_g', '—')}g · "
            f"C {nutrition.get('carbs_g', '—')}g · "
            f"F {nutrition.get('fat_g', '—')}g"
        )
    if ings:
        parts.append("**Ingredients (exact quantities from your plan):**")
        for ing in ings:
            if isinstance(ing, dict):
                parts.append(f"• {_format_ingredient(ing)}")
    else:
        parts.append("Ingredients were not stored for this meal — open Plan → meal → Start cooking.")
    if steps:
        parts.append("**How to make it:**")
        for i, step in enumerate(steps, 1):
            parts.append(f"{i}. {step}")
    else:
        parts.append(
            "Step-by-step instructions weren’t stored for this meal. "
            "Open the meal in your Plan tab and use Start cooking for the guided view."
        )
    return "\n".join(parts)


_OFF_TOPIC_HINTS = (
    "weather",
    "forecast",
    "temperature in",
    "temp in",
    "raining",
    "humidity",
    "joke",
    "funny",
    "super bowl",
    "world cup",
    "who won",
    "score of",
    "capital of",
    "president",
    "prime minister",
    "stock price",
    "bitcoin",
    "crypto",
    "movie",
    "netflix",
    "celebrity",
    "horoscope",
    "lottery",
    "lottery numbers",
)


def _is_off_topic(message: str) -> bool:
    """True for clearly unrelated asks (weather, sports, trivia, etc.)."""
    msg = message.lower().strip()
    if any(h in msg for h in _OFF_TOPIC_HINTS):
        return True
    # "weather in Austin", "what's the weather in xyz"
    if re.search(r"\bweather\b", msg) and re.search(r"\bin\b", msg):
        return True
    if re.search(r"\b(temperature|forecast)\b.*\bin\b", msg):
        return True
    return False


def _off_topic_redirect(user_id: int) -> str:
    user = _get_user(user_id)
    plan = _current_plan(user_id)
    tomorrow = date.today() + timedelta(days=1)
    tip = "How do I make tomorrow’s breakfast?"
    if plan:
        t_meals = _meals_for_date(plan, tomorrow)
        breakfast = next(
            (m for m in t_meals if str(m.get("meal_type") or "").lower() == "breakfast"),
            None,
        )
        if breakfast:
            name = _meal_recipe(breakfast).get("name")
            if name:
                tip = f"How do I cook {name}?"
    return (
        f"I’m your NutriAI Coach for **{user.get('first_name', 'you')}** — I only help with "
        "your labs, goals, meal plan, cooking steps, and nutrition coaching.\n\n"
        "I can’t answer unrelated questions (weather, sports, trivia, etc.).\n\n"
        "Try something like:\n"
        f"• “{tip}”\n"
        "• “What’s on my plan for today?”\n"
        "• “Why is this meal good for my cholesterol?”\n"
        "• “Change tofu to paneer”"
    )


def _is_plan_cook_question(message: str) -> bool:
    """Strict intent: only route to deterministic cook cards for clear plan/meal asks."""
    msg = message.lower().strip()
    meal_type = _detect_meal_type(msg) is not None
    explicit = any(
        p in msg
        for p in (
            "how to make",
            "how do i make",
            "how do i cook",
            "how to cook",
            "what's for",
            "whats for",
            "what is for",
            "what do i eat",
            "what am i eating",
            "on my plan",
            "in my plan",
            "my plan",
            "check my plan",
            "show my plan",
            "my breakfast",
            "my lunch",
            "my dinner",
            "my snack",
            "ingredients for",
            "recipe for",
            "steps for",
            "cook my",
            "make my",
        )
    )
    day_word = any(w in msg for w in ("today", "tomorrow", "tonight", "tmrw"))
    # "tomorrow breakfast" / "dinner today" etc.
    day_plus_meal = day_word and meal_type
    weekday_ask = any(
        d in msg for d in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
    ) and (meal_type or "meal" in msg or "plan" in msg or "eat" in msg)
    return explicit or day_plus_meal or weekday_ask


def _plan_grounded_answer(user_id: int, message: str) -> Optional[str]:
    """
    Deterministic answers for clear plan/cook questions so we never invent dishes.
    Returns None for general/random questions (those go to OpenAI + resilient fallback).
    """
    if not _is_plan_cook_question(message):
        return None

    plan = _current_plan(user_id)
    if not plan:
        return (
            "I don’t see an active week plan on your account yet. "
            "Open the Plan tab and generate your week first — then I can walk you through exact meals."
        )

    today = date.today()
    target = _resolve_target_date(message, today)
    meal_type = _detect_meal_type(message)
    day_meals = _meals_for_date(plan, target)

    if not day_meals:
        weekday_name = target.strftime("%A")
        day_meals = [
            m
            for m in (plan.get("meals") or [])
            if str(m.get("weekday") or "").lower() == weekday_name.lower()
        ]

    if meal_type:
        day_meals = [m for m in day_meals if str(m.get("meal_type") or "").lower() == meal_type]

    if not day_meals:
        inventory = _format_plan_inventory(plan, detailed=False)
        return (
            f"I checked your current plan (“{plan.get('title', 'Weekly plan')}”) and don’t see a "
            f"{meal_type or 'meal'} for {target.isoformat()}.\n\n"
            f"Here’s what’s actually on your plan:\n{inventory}\n\n"
            "Ask me about one of those dishes (e.g. “How do I make Thursday dinner?”) "
            "and I’ll use only that recipe."
        )

    when = "today" if target == today else ("tomorrow" if target == today + timedelta(days=1) else target.isoformat())
    header = f"From **your plan** for {when} ({target.strftime('%A %b %d')}):\n\n"
    cards = "\n\n---\n\n".join(_cook_card(m) for m in day_meals)
    footer = (
        "\n\nThese quantities and steps come only from your stored plan — not a generic recipe. "
        "Open Plan → that day → the meal → **Start cooking** for the guided cook mode."
    )
    return header + cards + footer


def _resilient_general_answer(user_id: int, message: str) -> str:
    """
    Demo-safe answer when LLMs are unavailable — never invents plan dishes,
    still handles random / off-topic questions without "failing".
    """
    user = _get_user(user_id)
    goals = get_goals_for_user(user_id, user)
    plan = _current_plan(user_id)
    lab = _get_latest_lab(user_id)
    msg = message.lower().strip()

    primary = goals[0].get("label", goals[0]["goal_type"]) if goals else "your health goals"
    lab_bit = ""
    if lab:
        lab_bit = lab.get("interpretation", {}).get("summary") or ""
        if lab_bit:
            lab_bit = f" Your latest lab note: {lab_bit}"

    tomorrow = date.today() + timedelta(days=1)
    tomorrow_line = ""
    if plan:
        t_meals = _meals_for_date(plan, tomorrow)
        if t_meals:
            bits = [
                f"{str(m.get('meal_type')).title()}: {_meal_recipe(m).get('name', 'meal')}"
                for m in t_meals
            ]
            tomorrow_line = " Tomorrow on your plan — " + "; ".join(bits) + "."

    if _is_off_topic(message) or len(msg) < 2:
        return _off_topic_redirect(user_id)

    # Nutrition / lifestyle without a specific meal ask
    if any(w in msg for w in ("cholesterol", "ldl", "lipid")):
        return (
            f"For cholesterol coaching I’m using **your** labs and plan — not a generic internet tip.{lab_bit}\n\n"
            "On your week I keep fiber-forward meals and limit saturated-fat heavy swaps unless you ask. "
            f"Primary focus: **{primary}**.{tomorrow_line}\n\n"
            "Ask “What’s for dinner tomorrow?” and I’ll pull the exact dish from your plan."
        )
    if any(w in msg for w in ("sugar", "glucose", "a1c", "diabetes")):
        return (
            f"For blood-sugar coaching I stay inside your goals and planned meals.{lab_bit}\n\n"
            f"Priority: **{primary}**.{tomorrow_line}\n\n"
            "I can walk you through tomorrow’s meals step-by-step — just ask."
        )
    if any(w in msg for w in ("water", "hydrat", "sleep", "exercise", "walk", "stress", "vitamin")):
        return (
            f"Happy to talk lifestyle in the context of **{primary}**.{lab_bit}\n\n"
            "I won’t invent meals that aren’t on your plan. "
            f"{tomorrow_line or 'Open Plan to see this week’s dishes.'}\n\n"
            "Ask a plan question anytime — e.g. “How do I cook tomorrow’s lunch?”"
        )

    return (
        f"Got it. I can answer that in coaching context for **{primary}**"
        f"{' using your labs' if lab else ''}, and I only name dishes that are on your current week plan."
        f"{tomorrow_line}\n\n"
        "If you meant a meal question, try: “How do I make tomorrow’s breakfast?” "
        "or “What’s on my plan for today?”"
    )


def _build_system_context(user_id: int) -> str:
    user = _get_user(user_id)
    goals = get_goals_for_user(user_id, user)
    plan = _current_plan(user_id)
    lab = _get_latest_lab(user_id)
    prefs = get_user_preferences(user_id)
    today = date.today().isoformat()

    goals_text = "\n".join(
        f"  {g['priority']}. {g.get('label', g['goal_type'])}"
        + (f" — current: {g.get('current_value')} {g.get('unit')}" if g.get("current_value") else "")
        for g in goals
    ) or "  None set"

    lab_text = "No lab results on file."
    if lab:
        lab_text = lab.get("interpretation", {}).get("summary") or lab.get("ai_interpretation") or "See lab results."

    if plan:
        plan_block = (
            f"Title: {plan.get('title')}\n"
            f"Dates: {plan.get('start_date') or plan.get('week_start')} → "
            f"{plan.get('end_date') or plan.get('week_end')}\n"
            f"Target calories: {plan.get('target_calories')}\n"
            f"FULL MEAL INVENTORY (authoritative — do not invent other dishes):\n"
            f"{_format_plan_inventory(plan, detailed=True)}"
        )
    else:
        plan_block = "No current week plan on file. Tell the user to generate a plan in the Plan tab."

    subs = prefs.get("substitutions", {})
    subs_text = ", ".join(f"{k}→{v}" for k, v in subs.items()) if subs else "None yet."

    return f"""You are NutriAI Coach, a precision AI dietitian inside a production app.

TODAY'S DATE: {today}

CRITICAL RULES (must follow):
1. ONLY name meals that appear in CURRENT PLAN MEAL INVENTORY below.
2. NEVER invent, substitute, or "suggest a typical breakfast" that is not on the inventory.
3. If the user asks how to cook a meal, use that meal's ingredients (with quantities) and instructions exactly.
4. If asked about a day/meal that is missing, say so and list what IS on the plan for nearby days.
5. For non-meal nutrition / lifestyle questions, answer helpfully using labs/goals — still do not invent plan dishes.
6. For off-topic / unrelated questions (weather, sports, trivia, jokes, news, stocks): DO NOT answer
   the topic. Politely refuse in 1–2 sentences and redirect to labs, goals, meal plan, or cooking help.
   Never pretend a random topic is a meal on their plan.
7. Be warm, specific, and demo-ready. Wellness coaching only — not a medical diagnosis.

USER PROFILE:
- Name: {user['first_name']} {user['last_name']}
- Dietary preference: {user.get('dietary_preference', 'omnivore')}
- Allergies: {', '.join(user.get('allergies', [])) or 'None'}
- Cuisine prefs: {', '.join(prefs.get('cuisine_preferences') or []) or 'n/a'}
- Dislikes: {', '.join(prefs.get('disliked_ingredients') or prefs.get('dislikes') or []) or 'n/a'}

HEALTH GOALS (priority order):
{goals_text}

LATEST LAB SUMMARY:
{lab_text}

CURRENT PLAN:
{plan_block}
Learned substitutions: {subs_text}

CAPABILITIES:
1. Explain / cook any meal on THEIR plan (ingredients + quantities + steps)
2. Swap ingredients across the week when asked
3. Reprioritize goals / regenerate plan when asked
4. Answer nutrition questions grounded in THEIR labs and goals
"""


def _detect_swap(message: str) -> Optional[Tuple[str, str]]:
    for pattern in SWAP_PATTERNS:
        match = re.search(pattern, message.lower(), re.IGNORECASE)
        if match:
            groups = match.groups()
            if len(groups) >= 2:
                if "instead of" in pattern:
                    return groups[1].strip(), groups[0].strip()
                return groups[0].strip(), groups[1].strip()
    return None


def _rule_based_actions(user_id: int, message: str) -> Dict[str, Any]:
    """Only structural plan changes — not free-form Q&A (that must be plan-grounded)."""
    user = _get_user(user_id)
    msg = message.lower().strip()
    plan_modified = False
    goals_updated = False
    response_parts: List[str] = []

    swap = _detect_swap(message)
    if swap:
        swap_from, swap_to = swap
        add_substitution_preference(user_id, swap_from, swap_to)
        try:
            apply_plan_modifications(user_id, swap_from, swap_to)
            plan_modified = True
            alts = get_substitution_options(swap_from)
            response_parts.append(
                f"Done — I replaced **{swap_from}** with **{swap_to}** across matching meals in your current plan. "
                f"Other options for {swap_from}: {', '.join(alts[:3]) if alts else 'ask me anytime'}."
            )
        except Exception as e:
            response_parts.append(f"I understood the swap ({swap_from} → {swap_to}) but couldn’t update the plan: {e}")

    elif any(re.search(p, msg) for p in PRIORITY_PATTERNS) and any(
        w in msg for w in ("first", "priority", "focus", "then")
    ):
        goals = get_goals_for_user(user_id, user)
        new_order = parse_priority_from_message(message, goals)
        if new_order:
            updated = update_goal_priorities(user_id, new_order)
            goals_updated = True
            plan = generate_diet_plan(user, goals_override=new_order)
            plan_modified = True
            order_text = "\n".join(f"  {g['priority']}. {g.get('label', g['goal_type'])}" for g in updated)
            response_parts.append(
                f"Priorities updated and plan regenerated:\n{order_text}\n\n"
                f"New plan: **{plan['title']}**."
            )

    elif any(re.search(p, msg) for p in REGENERATE_PATTERNS):
        plan = generate_diet_plan(user)
        plan_modified = True
        response_parts.append(
            f"Fresh 7-day plan ready: **{plan['title']}** ({plan.get('target_calories')} kcal/day). "
            "Open the Plan tab to cook each meal."
        )

    elif any(w in msg for w in ("hello", "hi", "hey", "help", "what can you")):
        plan = _current_plan(user_id)
        sample = ""
        if plan and plan.get("meals"):
            tomorrow = date.today() + timedelta(days=1)
            t_meals = _meals_for_date(plan, tomorrow)
            if t_meals:
                names = [
                    f"{m.get('meal_type')}: {_meal_recipe(m).get('name', 'meal')}" for m in t_meals
                ]
                sample = "\n\nTomorrow on your plan: " + "; ".join(names)
        response_parts.append(
            f"Hi {user['first_name']} — I’m your Coach grounded in **your** labs and current week plan.\n\n"
            "Ask things like:\n"
            "• “How do I make tomorrow’s breakfast?”\n"
            "• “What’s for dinner on Friday?”\n"
            "• “Change tofu to paneer”\n"
            "• “Why is this meal good for my cholesterol?”"
            + sample
        )

    return {
        "message": "\n\n".join(response_parts) if response_parts else "",
        "plan_modified": plan_modified,
        "goals_updated": goals_updated,
        "handled": bool(response_parts),
        "suggestions": _get_quick_suggestions(user_id),
    }


def _get_quick_suggestions(user_id: int) -> List[str]:
    plan = _current_plan(user_id)
    suggestions = [
        "How do I make tomorrow’s breakfast?",
        "What’s on my plan for today?",
        "Change tofu to paneer in my plan",
    ]
    if plan:
        tomorrow = date.today() + timedelta(days=1)
        for meal in _meals_for_date(plan, tomorrow):
            name = _meal_recipe(meal).get("name")
            if name:
                suggestions[0] = f"How do I cook {name}?"
                break
    return suggestions[:4]


async def _call_openai(system: str, history: List[Dict], message: str) -> Optional[str]:
    if not settings.OPENAI_API_KEY:
        return None
    try:
        import openai

        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        messages = [{"role": "system", "content": system}]
        for m in history[-10:]:
            messages.append({"role": m["role"], "content": m["content"]})
        messages.append({"role": "user", "content": message})

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            max_tokens=2000,
            temperature=0.2,
        )
        return response.choices[0].message.content
    except Exception:
        return None


async def _call_claude(system: str, history: List[Dict], message: str) -> Optional[str]:
    if not settings.ANTHROPIC_API_KEY:
        return None
    try:
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        messages = [{"role": m["role"], "content": m["content"]} for m in history[-10:]]
        messages.append({"role": "user", "content": message})

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            system=system,
            messages=messages,
            temperature=0.2,
        )
        return response.content[0].text
    except Exception:
        return None


async def process_chat_message(user_id: int, message: str) -> Dict[str, Any]:
    """
    Process a user chat message.

    Paths (demo-safe):
      1) Structural plan edits (swap / regenerate / priorities)
      2) Strict cook/plan questions → deterministic inventory (never invent dishes)
      3) Everything else (incl. random demo asks) → OpenAI/Claude with full plan context
      4) If LLMs fail → resilient coaching fallback (still never invents dishes)
    """
    add_chat_message(user_id, "user", message)

    # Hard block: weather / sports / trivia — never call LLM to answer those
    if _is_off_topic(message):
        final_message = _off_topic_redirect(user_id)
        suggestions = _get_quick_suggestions(user_id)
        add_chat_message(
            user_id,
            "assistant",
            final_message,
            {"plan_modified": False, "goals_updated": False, "suggestions": suggestions, "path": "off_topic"},
        )
        return {
            "response": final_message,
            "plan_modified": False,
            "goals_updated": False,
            "suggestions": suggestions,
            "updated_plan_id": None,
        }

    rule_result = _rule_based_actions(user_id, message)

    grounded = None
    if not rule_result["plan_modified"]:
        grounded = _plan_grounded_answer(user_id, message)

    system = _build_system_context(user_id)
    history = get_chat_history(user_id)

    # LLM only for in-domain coaching (nutrition, labs, goals, plan, lifestyle tied to health)
    llm_response = await _call_openai(system, history, message)
    if not llm_response:
        llm_response = await _call_claude(system, history, message)

    if rule_result["plan_modified"] and rule_result["message"]:
        final_message = rule_result["message"]
        if llm_response:
            final_message = final_message + "\n\n" + llm_response
        path = "plan_edit"
    elif grounded:
        final_message = grounded
        path = "plan_grounded"
    elif rule_result.get("handled") and rule_result["message"]:
        final_message = rule_result["message"]
        path = "greeting"
    elif llm_response:
        final_message = llm_response
        path = "llm"
    else:
        final_message = _resilient_general_answer(user_id, message)
        path = "resilient_fallback"

    suggestions = rule_result["suggestions"]
    metadata = {
        "plan_modified": rule_result["plan_modified"],
        "goals_updated": rule_result["goals_updated"],
        "suggestions": suggestions,
        "grounded": bool(grounded),
        "path": path,
    }

    add_chat_message(user_id, "assistant", final_message, metadata)

    plan = get_or_create_plan(_get_user(user_id)) if rule_result["plan_modified"] else None

    return {
        "response": final_message,
        "plan_modified": rule_result["plan_modified"],
        "goals_updated": rule_result["goals_updated"],
        "suggestions": suggestions,
        "updated_plan_id": plan["id"] if plan else None,
    }
