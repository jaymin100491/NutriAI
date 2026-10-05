"""
AI Dietitian chat service — conversational diet customization with Claude/OpenAI fallback.
Handles: ingredient swaps, goal reprioritization, meal replacements, general nutrition Q&A.
"""
from __future__ import annotations

import json
import re
from typing import Any, Dict, List, Optional, Tuple

from app.core.config import settings
from app.db.mock_data import MOCK_USERS
from app.db.store import add_chat_message, add_substitution_preference, get_chat_history, get_user_preferences
from app.services.diet_plan_engine import apply_plan_modifications, generate_diet_plan, get_or_create_plan
from app.services.goal_service import get_goals_for_user, parse_priority_from_message, update_goal_priorities
from app.services.recipe_catalog import find_substitute_recipes, get_substitution_options

# Substitution patterns: "change tofu to paneer", "I don't like tofu, use paneer instead"
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


def _get_user(user_id: int) -> Dict[str, Any]:
    from app.db.database import SessionLocal
    from app.db import repository as repo

    db = SessionLocal()
    try:
        user = repo.get_user_by_id(db, user_id)
        if user:
            return {
                "id": user.id,
                "email": user.email,
                "first_name": user.first_name or "Patient",
                "last_name": user.last_name or "",
                "dietary_preference": "omnivore",
                "allergies": [],
                "medical_conditions": [],
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


def _build_system_context(user_id: int) -> str:
    user = _get_user(user_id)
    goals = get_goals_for_user(user_id, user)
    plan = get_or_create_plan(user)
    lab = _get_latest_lab(user_id)
    prefs = get_user_preferences(user_id)

    goals_text = "\n".join(
        f"  {g['priority']}. {g.get('label', g['goal_type'])}"
        + (f" — current: {g.get('current_value')} {g.get('unit')}" if g.get("current_value") else "")
        for g in goals
    )

    lab_text = "No lab results on file."
    if lab:
        lab_text = lab.get("interpretation", {}).get("summary", "See lab results.")

    plan_summary = f"Active plan: {plan['title']}, {plan['duration_days']} days, {len(plan['meals'])} meals."
    subs = prefs.get("substitutions", {})
    subs_text = ", ".join(f"{k}→{v}" for k, v in subs.items()) if subs else "None yet."

    return f"""You are NutriAI, an expert AI dietitian. You help users customize their personalized 7-day meal plans.

USER PROFILE:
- Name: {user['first_name']} {user['last_name']}
- Dietary preference: {user.get('dietary_preference', 'omnivore')}
- Allergies: {', '.join(user.get('allergies', [])) or 'None'}
- Medical conditions: {', '.join(user.get('medical_conditions', [])) or 'None'}

HEALTH GOALS (priority order):
{goals_text}

LATEST LAB SUMMARY:
{lab_text}

CURRENT PLAN:
{plan_summary}
Learned substitutions: {subs_text}

CAPABILITIES:
1. Swap ingredients (e.g., tofu → paneer) across the 7-day plan
2. Reprioritize health goals ("fix blood sugar first, then cholesterol")
3. Regenerate the full plan based on updated priorities
4. Answer nutrition questions with empathy and evidence-based advice
5. Suggest alternatives from 1,500+ recipes

Always be warm, professional, and action-oriented. When making plan changes, confirm what you changed and why."""


def _detect_swap(message: str) -> Optional[Tuple[str, str]]:
    msg = message.lower()
    for pattern in SWAP_PATTERNS:
        match = re.search(pattern, msg, re.IGNORECASE)
        if match:
            groups = match.groups()
            if len(groups) >= 2:
                # Handle "X instead of Y" pattern
                if "instead of" in pattern:
                    return groups[1].strip(), groups[0].strip()
                return groups[0].strip(), groups[1].strip()
    return None


def _rule_based_response(user_id: int, message: str) -> Dict[str, Any]:
    """Intelligent fallback when no AI API key is configured."""
    user = _get_user(user_id)
    msg = message.lower().strip()
    plan_modified = False
    goals_updated = False
    response_parts = []

    # Check for swap request
    swap = _detect_swap(message)
    if swap:
        swap_from, swap_to = swap
        add_substitution_preference(user_id, swap_from, swap_to)
        try:
            updated_plan = apply_plan_modifications(user_id, swap_from, swap_to)
            plan_modified = True
            mod_count = updated_plan.get("customization_count", 0)
            alts = get_substitution_options(swap_from)
            response_parts.append(
                f"Done! I've updated your 7-day meal plan, replacing **{swap_from}** with **{swap_to}** "
                f"across all matching meals. Your shopping list has been refreshed too.\n\n"
                f"💡 Other alternatives for {swap_from}: {', '.join(alts[:3]) if alts else 'ask me anytime'}.\n\n"
                f"This preference is saved — future plans will automatically use {swap_to} instead of {swap_from}."
            )
        except Exception as e:
            response_parts.append(f"I understood you want to swap {swap_from} for {swap_to}, but couldn't update the plan: {e}")

    # Check for priority reordering
    elif any(re.search(p, msg) for p in PRIORITY_PATTERNS):
        goals = get_goals_for_user(user_id, user)
        new_order = parse_priority_from_message(message, goals)
        if new_order:
            updated = update_goal_priorities(user_id, new_order)
            goals_updated = True
            plan = generate_diet_plan(user, goals_override=new_order)
            plan_modified = True
            order_text = "\n".join(f"  {g['priority']}. {g.get('label', g['goal_type'])}" for g in updated)
            response_parts.append(
                f"I've reprioritized your health goals and regenerated your 7-day plan:\n\n{order_text}\n\n"
                f"Your new plan **\"{plan['title']}\"** focuses on #{updated[0].get('label')} first. "
                f"All meals for the next 7 days reflect this priority."
            )
        else:
            response_parts.append(
                "I can help reprioritize your health goals. Try saying something like:\n"
                "• \"Focus on blood sugar first, then cholesterol\"\n"
                "• \"I need to fix my diabetes before working on weight loss\""
            )

    # Regenerate plan
    elif any(re.search(p, msg) for p in REGENERATE_PATTERNS):
        plan = generate_diet_plan(user)
        plan_modified = True
        response_parts.append(
            f"I've generated a fresh 7-day plan: **{plan['title']}**.\n\n"
            f"{plan.get('ai_rationale', '')}\n\n"
            f"Target: {plan['target_calories']} cal/day. Check your Diet Plan tab to see all meals!"
        )

    # Greeting / help
    elif any(w in msg for w in ["hello", "hi", "hey", "help", "what can you"]):
        goals = get_goals_for_user(user_id, user)
        primary = goals[0] if goals else None
        response_parts.append(
            f"Hi {user['first_name']}! I'm your AI dietitian. I have your full health profile and active meal plan.\n\n"
            "Here's what I can do:\n"
            "🔄 **Swap ingredients** — \"Change tofu to paneer in my plan\"\n"
            "🎯 **Reprioritize goals** — \"Focus on blood sugar first, then cholesterol\"\n"
            "📋 **Regenerate plan** — \"Create a new 7-day plan\"\n"
            "💬 **Nutrition advice** — Ask me anything about your meals or lab results\n\n"
            + (f"Your top priority right now: **{primary.get('label')}**." if primary else "")
        )

    # Nutrition questions about specific foods
    elif "?" in message or any(w in msg for w in ["why", "how", "what", "can i", "should i", "is it"]):
        goals = get_goals_for_user(user_id, user)
        primary_goal = goals[0]["goal_type"] if goals else "wellness"
        lab = _get_latest_lab(user_id)

        if "cholesterol" in msg or "ldl" in msg:
            response_parts.append(
                "For cholesterol management, focus on:\n"
                "• Soluble fiber (oats, beans, apples) — can lower LDL by 5-10%\n"
                "• Omega-3 fatty acids (salmon, walnuts, flaxseed)\n"
                "• Limit saturated fat to <7% of calories\n"
                "• Plant sterols from fortified foods\n\n"
                "Your current plan is optimized for this. Want me to swap any ingredients?"
            )
        elif "sugar" in msg or "diabetes" in msg or "glucose" in msg:
            response_parts.append(
                "For blood sugar management:\n"
                "• Choose low glycemic index foods (quinoa, lentils, sweet potato)\n"
                "• Pair carbs with protein/fat to slow absorption\n"
                "• Eat every 3-4 hours to prevent spikes\n"
                "• Aim for 30g+ fiber daily\n\n"
                "I can reprioritize this as your #1 goal if you'd like — just say \"focus on blood sugar first.\""
            )
        elif "paneer" in msg or "tofu" in msg:
            response_parts.append(
                "**Paneer vs Tofu:**\n"
                "• Paneer: Higher protein (18g/100g), more calories, great for muscle maintenance\n"
                "• Tofu: Lower calorie, complete plant protein, better for cholesterol goals\n\n"
                "Say \"change tofu to paneer\" and I'll update your entire 7-day plan instantly!"
            )
        else:
            response_parts.append(
                f"Great question! Based on your {primary_goal.replace('_', ' ')} goal"
                + (f" and your lab results showing {lab['interpretation']['summary']}" if lab else "")
                + ", I'd recommend sticking with your current plan while we address your specific concern.\n\n"
                "Could you be more specific? Or try:\n"
                "• \"Change [ingredient] to [alternative]\"\n"
                "• \"Focus on [goal] first\"\n"
                "• \"Why is [food] in my plan?\""
            )

    else:
        # Generic acknowledgment with suggestions
        swap_from_guess = None
        for word in ["tofu", "salmon", "chicken", "eggs", "paneer", "beef"]:
            if word in msg and ("no" in msg or "don't" in msg or "hate" in msg or "dislike" in msg):
                swap_from_guess = word
                break

        if swap_from_guess:
            alts = get_substitution_options(swap_from_guess)
            response_parts.append(
                f"I hear you don't want {swap_from_guess}! Here are great alternatives: **{', '.join(alts[:4])}**.\n\n"
                f"Just tell me which you'd prefer, e.g., \"Change {swap_from_guess} to {alts[0] if alts else 'paneer'}\"."
            )
        else:
            response_parts.append(
                "I'm here to help customize your diet plan! Try:\n"
                "• \"Change tofu to paneer\"\n"
                "• \"Focus on cholesterol first, then weight loss\"\n"
                "• \"Generate a new plan\"\n"
                "• \"Why is salmon in my dinner?\""
            )

    return {
        "message": "\n\n".join(response_parts),
        "plan_modified": plan_modified,
        "goals_updated": goals_updated,
        "suggestions": _get_quick_suggestions(user_id),
    }


def _get_quick_suggestions(user_id: int) -> List[str]:
    user = _get_user(user_id)
    goals = get_goals_for_user(user_id, user)
    suggestions = [
        "Change tofu to paneer in my plan",
        "Generate a new 7-day plan",
    ]
    if len(goals) > 1:
        g1 = goals[0].get("label", goals[0]["goal_type"])
        g2 = goals[1].get("label", goals[1]["goal_type"])
        suggestions.insert(0, f"Focus on {g2} first, then {g1}")
    return suggestions[:4]


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
            max_tokens=1024,
            system=system,
            messages=messages,
        )
        return response.content[0].text
    except Exception:
        return None


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
            max_tokens=1024,
        )
        return response.choices[0].message.content
    except Exception:
        return None


async def process_chat_message(user_id: int, message: str) -> Dict[str, Any]:
    """Process a user chat message and return AI response with any plan modifications."""
    add_chat_message(user_id, "user", message)

    # Always run rule-based actions first (swaps, priority changes)
    rule_result = _rule_based_response(user_id, message)

    # Try LLM for richer response if API key available
    system = _build_system_context(user_id)
    history = get_chat_history(user_id)

    llm_response = await _call_claude(system, history, message)
    if not llm_response:
        llm_response = await _call_openai(system, history, message)

    if llm_response and not rule_result["plan_modified"]:
        final_message = llm_response
    elif llm_response and rule_result["plan_modified"]:
        final_message = rule_result["message"] + "\n\n" + llm_response
    else:
        final_message = rule_result["message"]

    metadata = {
        "plan_modified": rule_result["plan_modified"],
        "goals_updated": rule_result["goals_updated"],
        "suggestions": rule_result["suggestions"],
    }

    add_chat_message(user_id, "assistant", final_message, metadata)

    plan = get_or_create_plan(_get_user(user_id)) if rule_result["plan_modified"] else None

    return {
        "response": final_message,
        "plan_modified": rule_result["plan_modified"],
        "goals_updated": rule_result["goals_updated"],
        "suggestions": rule_result["suggestions"],
        "updated_plan_id": plan["id"] if plan else None,
    }
