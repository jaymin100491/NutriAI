"""
Health goal derivation from lab results with priority sequencing.
Users can reorder priorities: "fix blood sugar first, then cholesterol."
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.db.mock_data import MOCK_LAB_RESULTS, MOCK_USER_GOALS
from app.db.store import get_user_goals, set_user_goals
from app.services.lab_result_service import get_lab_results_for_user

GOAL_DEFINITIONS = {
    "lower_cholesterol": {
        "label": "Lower Cholesterol",
        "description": "Reduce LDL and improve lipid profile through diet",
        "icon": "heart",
        "lab_triggers": ["ldl cholesterol", "triglycerides", "total cholesterol"],
        "abnormal_status": ["high"],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 35},
        "health_tags": ["cholesterol-lowering", "heart-healthy", "high-fiber", "omega-3"],
    },
    "manage_diabetes": {
        "label": "Manage Blood Sugar",
        "description": "Stabilize glucose and HbA1c with low-GI nutrition",
        "icon": "glucose",
        "lab_triggers": ["glucose", "hba1c", "a1c"],
        "abnormal_status": ["high"],
        "calories": 1700,
        "macros": {"protein_percent": 25, "carb_percent": 40, "fat_percent": 35, "fiber_grams": 35},
        "health_tags": ["low-glycemic", "high-fiber", "balanced", "complex-carbs"],
    },
    "lower_blood_pressure": {
        "label": "Lower Blood Pressure",
        "description": "DASH-style eating to reduce hypertension",
        "icon": "pressure",
        "lab_triggers": ["blood pressure", "sodium"],
        "abnormal_status": ["high"],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 30},
        "health_tags": ["low-sodium-option", "heart-healthy", "potassium-rich"],
    },
    "weight_loss": {
        "label": "Weight Loss",
        "description": "Calorie-aware plan for sustainable weight reduction",
        "icon": "scale",
        "lab_triggers": ["bmi", "weight"],
        "abnormal_status": ["high"],
        "calories": 1600,
        "macros": {"protein_percent": 30, "carb_percent": 40, "fat_percent": 30, "fiber_grams": 30},
        "health_tags": ["lean", "low-carb", "high-protein", "high-fiber"],
    },
    "muscle_gain": {
        "label": "Build Muscle / Gain Strength",
        "description": "Higher-calorie, high-protein meals to support muscle growth",
        "icon": "fitness",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 2400,
        "macros": {"protein_percent": 35, "carb_percent": 40, "fat_percent": 25, "fiber_grams": 30},
        "health_tags": ["high-protein", "lean"],
    },
    "weight_gain": {
        "label": "Healthy Weight Gain",
        "description": "Calorie-dense, nutrient-rich meals for healthy weight gain",
        "icon": "scale_up",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 2600,
        "macros": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 28},
        "health_tags": ["high-protein", "balanced", "nutrient-dense"],
    },
    "increase_vitamin_d": {
        "label": "Boost Vitamin D",
        "description": "Increase Vitamin D through diet and fortified foods",
        "icon": "sun",
        "lab_triggers": ["vitamin d"],
        "abnormal_status": ["low"],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 30},
        "health_tags": ["nutrient-dense", "heart-healthy"],
    },
    "reduce_inflammation": {
        "label": "Reduce Inflammation",
        "description": "Anti-inflammatory foods to lower systemic inflammation",
        "icon": "flame",
        "lab_triggers": ["crp", "c-reactive protein", "esr"],
        "abnormal_status": ["high"],
        "calories": 1750,
        "macros": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 32},
        "health_tags": ["anti-inflammatory", "omega-3", "antioxidant-rich"],
    },
    "gut_health": {
        "label": "Improve Gut Health",
        "description": "Fiber-rich, probiotic foods for digestive wellness",
        "icon": "gut",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 40},
        "health_tags": ["probiotic", "high-fiber", "plant-based"],
    },
    "increase_energy": {
        "label": "Increase Energy",
        "description": "Iron and B-vitamin rich meals for sustained energy",
        "icon": "energy",
        "lab_triggers": ["iron", "ferritin", "b12", "vitamin b12"],
        "abnormal_status": ["low"],
        "calories": 1900,
        "macros": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 30},
        "health_tags": ["iron-rich", "balanced", "complex-carbs"],
    },
    "better_sleep": {
        "label": "Better Sleep",
        "description": "Magnesium- and tryptophan-supportive evening meals; lighter dinners",
        "icon": "sleep",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 45, "fat_percent": 30, "fiber_grams": 30},
        "health_tags": ["balanced", "nutrient-dense", "anti-inflammatory"],
    },
    "athletic_performance": {
        "label": "Athletic Performance",
        "description": "Carb-timed, high-protein meals for training and recovery",
        "icon": "sport",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 2500,
        "macros": {"protein_percent": 30, "carb_percent": 45, "fat_percent": 25, "fiber_grams": 30},
        "health_tags": ["high-protein", "complex-carbs", "lean"],
    },
    "more_protein": {
        "label": "Higher Protein Intake",
        "description": "Protein-forward meals across the day",
        "icon": "protein",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 2000,
        "macros": {"protein_percent": 35, "carb_percent": 35, "fat_percent": 30, "fiber_grams": 28},
        "health_tags": ["high-protein", "lean"],
    },
    "heart_health": {
        "label": "Heart Health",
        "description": "Mediterranean-style heart-protective eating",
        "icon": "heart",
        "lab_triggers": [],
        "abnormal_status": [],
        "calories": 1800,
        "macros": {"protein_percent": 25, "carb_percent": 50, "fat_percent": 25, "fiber_grams": 35},
        "health_tags": ["heart-healthy", "omega-3", "high-fiber"],
    },
    "kidney_support": {
        "label": "Kidney-Friendly Eating",
        "description": "Moderate protein and sodium-aware meals (wellness guidance)",
        "icon": "kidney",
        "lab_triggers": ["creatinine", "egfr", "bun"],
        "abnormal_status": ["high", "low"],
        "calories": 1800,
        "macros": {"protein_percent": 20, "carb_percent": 55, "fat_percent": 25, "fiber_grams": 30},
        "health_tags": ["low-sodium-option", "balanced", "heart-healthy"],
    },
}

# Free-text → known goal mapping (first match wins by specificity order)
_GOAL_ALIASES = [
    (("blood pressure", "hypertension", "bp ", " high bp", "lower bp"), "lower_blood_pressure"),
    (("cholesterol", "ldl", "triglyceride", "lipid", "hdl"), "lower_cholesterol"),
    (("blood sugar", "diabetes", "glucose", "a1c", "hba1c", "prediabet", "insulin"), "manage_diabetes"),
    (("lose weight", "weight loss", "fat loss", "slim", "cut fat", "lose fat"), "weight_loss"),
    (("gain weight", "underweight", "put on weight"), "weight_gain"),
    (("muscle", "bulk", "strength", "hypertrophy", "gain muscle", "toned", "gym"), "muscle_gain"),
    (("more protein", "high protein", "protein intake", "extra protein"), "more_protein"),
    (("vitamin d", "vit d"), "increase_vitamin_d"),
    (("inflammation", "anti-inflammatory", "arthritis", "joint pain", "skin", "acne"), "reduce_inflammation"),
    (("gut", "digestion", "bloating", "microbiome", "constipation", "ibs"), "gut_health"),
    (("energy", "fatigue", "tired", "iron", "b12", "focus", "brain"), "increase_energy"),
    (("sleep", "insomnia", "rest", "sleep better"), "better_sleep"),
    (("athletic", "training", "workout", "performance", "endurance", "sports"), "athletic_performance"),
    (("heart", "cardiac", "cardiovascular"), "heart_health"),
    (("kidney", "renal", "egfr", "creatinine"), "kidney_support"),
]


def list_catalog_goals() -> List[Dict[str, Any]]:
    return [
        {
            "goal_type": gt,
            "label": defn["label"],
            "description": defn["description"],
            "calories": defn.get("calories"),
            "macros": defn.get("macros"),
        }
        for gt, defn in GOAL_DEFINITIONS.items()
    ]


def _slugify_goal(text: str) -> str:
    import re

    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug[:48] or "custom_goal"


def _infer_custom_nutrition(text: str) -> Dict[str, Any]:
    """
    Always return a complete, demo-safe nutrition profile for any free-text goal.
    Random/unknown goals still get a balanced high-quality plan (never empty/broken).
    """
    t = (text or "").lower().strip()
    calories = 1900
    protein = 28
    carbs = 42
    fat = 30
    fiber = 32
    tags = ["balanced", "nutrient-dense", "high-fiber"]

    if any(k in t for k in ("protein", "muscle", "strength", "gym", "toned", "lift")):
        protein, carbs, fat, calories = 35, 38, 27, 2300
        tags = ["high-protein", "lean", "nutrient-dense"]
    if any(k in t for k in ("gain", "bulk", "appetite", "underweight", "mass")):
        calories = max(calories, 2500)
        protein = max(protein, 30)
        tags = list(set(tags + ["high-protein", "nutrient-dense", "complex-carbs"]))
    if any(k in t for k in ("lose", "cut", "deficit", "slim", "fat loss", "weight loss", "lighter")):
        calories = 1600
        protein = max(protein, 32)
        carbs = 38
        fiber = 35
        tags = list(set(tags + ["lean", "high-protein", "high-fiber", "low-carb"]))
    if any(k in t for k in ("plant", "vegan", "fiber", "gut", "digest", "bloating")):
        fiber = 40
        tags = list(set(tags + ["plant-based", "high-fiber", "probiotic"]))
    if any(k in t for k in ("anti-inflam", "joint", "inflam", "skin", "acne")):
        tags = list(set(tags + ["anti-inflammatory", "omega-3", "antioxidant-rich"]))
    if any(k in t for k in ("low sodium", "salt", "pressure", "hypertension", "heart")):
        fat = 25
        tags = list(set(tags + ["low-sodium-option", "heart-healthy", "potassium-rich"]))
    if any(k in t for k in ("sugar", "glucose", "diabetes", "a1c", "carb")):
        carbs = 38
        fiber = 36
        protein = max(protein, 28)
        tags = list(set(tags + ["low-glycemic", "high-fiber", "balanced", "complex-carbs"]))
    if any(k in t for k in ("energy", "fatigue", "tired", "focus", "brain", "iron")):
        calories = max(calories, 1950)
        tags = list(set(tags + ["iron-rich", "complex-carbs", "balanced"]))
    if any(k in t for k in ("sleep", "insomnia", "rest", "night")):
        tags = list(set(tags + ["balanced", "anti-inflammatory", "nutrient-dense"]))
    if any(k in t for k in ("athlete", "training", "workout", "performance", "endurance", "sport")):
        calories = max(calories, 2500)
        protein = max(protein, 30)
        carbs = 45
        tags = list(set(tags + ["high-protein", "complex-carbs", "lean"]))

    return {
        "calories": calories,
        "macros": {
            "protein_percent": protein,
            "carb_percent": carbs,
            "fat_percent": fat,
            "fiber_grams": fiber,
        },
        "health_tags": tags,
        "demo_safe": True,
    }


def resolve_goal_request(
    *,
    text: Optional[str] = None,
    goal_type: Optional[str] = None,
) -> Dict[str, Any]:
    """Resolve a catalog goal or invent a custom nutrition-backed goal from free text."""
    if goal_type and goal_type in GOAL_DEFINITIONS:
        defn = GOAL_DEFINITIONS[goal_type]
        return {
            "goal_type": goal_type,
            "label": defn["label"],
            "description": defn["description"],
            "target_value": None,
            "current_value": None,
            "unit": "",
            "status": "active",
            "source": "user_added",
            "triggered_by": "user",
            "nutrition_profile": {
                "calories": defn["calories"],
                "macros": defn["macros"],
                "health_tags": defn["health_tags"],
            },
        }

    raw = (text or "").strip()
    if not raw:
        raise ValueError("Provide a goal description or choose a goal type")

    lower = raw.lower()
    for aliases, mapped in _GOAL_ALIASES:
        if any(a in lower for a in aliases):
            defn = GOAL_DEFINITIONS[mapped]
            return {
                "goal_type": mapped,
                "label": defn["label"],
                "description": f"{defn['description']} (from: “{raw}”)",
                "target_value": None,
                "current_value": None,
                "unit": "",
                "status": "active",
                "source": "user_added",
                "triggered_by": raw,
                "nutrition_profile": {
                    "calories": defn["calories"],
                    "macros": defn["macros"],
                    "health_tags": defn["health_tags"],
                },
            }

    nutrition = _infer_custom_nutrition(raw)
    slug = _slugify_goal(raw)
    return {
        "goal_type": f"custom_{slug}",
        "label": raw[:80],
        "description": (
            f"Custom goal: {raw}. "
            f"NutriAI mapped this to ~{nutrition['calories']} kcal/day with "
            f"{nutrition['macros']['protein_percent']}% protein focus for a full personalized week."
        ),
        "target_value": None,
        "current_value": None,
        "unit": "",
        "status": "active",
        "source": "user_custom",
        "triggered_by": raw,
        "nutrition_profile": nutrition,
    }


def add_user_goal(
    user_id: int,
    *,
    text: Optional[str] = None,
    goal_type: Optional[str] = None,
    make_primary: bool = True,
) -> List[Dict[str, Any]]:
    """Add any user goal (catalog or free-text) and optionally make it #1 priority."""
    current = get_user_goals(user_id) or []
    new_goal = resolve_goal_request(text=text, goal_type=goal_type)

    # Replace existing same type, else append
    current = [g for g in current if g.get("goal_type") != new_goal["goal_type"]]
    if make_primary:
        new_goal["priority"] = 1
        for g in current:
            g["priority"] = int(g.get("priority", 1)) + 1
        current = [new_goal] + current
    else:
        new_goal["priority"] = len(current) + 1
        current.append(new_goal)

    for i, g in enumerate(current, 1):
        g["id"] = i
        g["priority"] = i

    return set_user_goals(user_id, current)


def remove_user_goal(user_id: int, goal_type: str) -> List[Dict[str, Any]]:
    current = get_user_goals(user_id) or []
    current = [g for g in current if g.get("goal_type") != goal_type]
    for i, g in enumerate(current, 1):
        g["id"] = i
        g["priority"] = i
    return set_user_goals(user_id, current)


def _parse_reference_range(ref: str) -> tuple:
    ref = ref.strip()
    if ref.startswith("<"):
        return (0, float(ref[1:]))
    if ref.startswith(">"):
        return (float(ref[1:]), 9999)
    if "-" in ref:
        parts = ref.split("-")
        return (float(parts[0]), float(parts[1]))
    return (0, 9999)


def derive_goals_from_labs(lab_results: List[Dict[str, Any]], user: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Auto-derive prioritized health goals from abnormal lab markers."""
    derived: Dict[str, Dict[str, Any]] = {}
    priority = 1

    for lab in lab_results:
        tests = lab.get("results", {}).get("tests", [])
        for test in tests:
            test_name = test["name"].lower()
            status = test.get("status", "normal")
            if status == "normal":
                continue

            for goal_type, defn in GOAL_DEFINITIONS.items():
                if any(trigger in test_name for trigger in defn["lab_triggers"]):
                    if status in defn["abnormal_status"] or status in ("high", "low"):
                        if goal_type not in derived:
                            ref_min, ref_max = _parse_reference_range(test.get("reference_range", "0-100"))
                            derived[goal_type] = {
                                "goal_type": goal_type,
                                "label": defn["label"],
                                "description": defn["description"],
                                "target_value": ref_max if status == "high" else ref_min,
                                "current_value": test["value"],
                                "unit": test.get("unit", ""),
                                "status": "active",
                                "priority": priority,
                                "source": "lab_derived",
                                "triggered_by": test["name"],
                            }
                            priority += 1

    # Add goals from medical conditions
    condition_goal_map = {
        "high_cholesterol": "lower_cholesterol",
        "pre_diabetes": "manage_diabetes",
        "diabetes": "manage_diabetes",
        "hypertension": "lower_blood_pressure",
    }
    for condition in user.get("medical_conditions", []):
        goal_type = condition_goal_map.get(condition)
        if goal_type and goal_type not in derived:
            defn = GOAL_DEFINITIONS[goal_type]
            derived[goal_type] = {
                "goal_type": goal_type,
                "label": defn["label"],
                "description": defn["description"],
                "target_value": None,
                "current_value": None,
                "unit": "",
                "status": "active",
                "priority": priority,
                "source": "medical_condition",
                "triggered_by": condition,
            }
            priority += 1

    # Default wellness goal if nothing abnormal
    if not derived:
        derived["increase_energy"] = {
            "goal_type": "increase_energy",
            "label": GOAL_DEFINITIONS["increase_energy"]["label"],
            "description": GOAL_DEFINITIONS["increase_energy"]["description"],
            "target_value": None,
            "current_value": None,
            "unit": "",
            "status": "active",
            "priority": 1,
            "source": "default",
            "triggered_by": "general wellness",
        }

    goals = sorted(derived.values(), key=lambda g: g["priority"])
    for i, g in enumerate(goals, 1):
        g["id"] = i
        g["priority"] = i
    return goals


def get_goals_for_user(
    user_id: int,
    user: Dict[str, Any],
    db: Optional[Session] = None,
) -> List[Dict[str, Any]]:
    stored = get_user_goals(user_id)
    if stored:
        return sorted(stored, key=lambda g: g["priority"])

    mock = [g for g in MOCK_USER_GOALS if g["user_id"] == user_id]
    if mock:
        goals = []
        for g in mock:
            defn = GOAL_DEFINITIONS.get(g["goal_type"], {})
            goals.append({**g, "label": defn.get("label", g["goal_type"]), "description": defn.get("description", "")})
        set_user_goals(user_id, goals)
        return goals

    labs = []
    if db is not None:
        labs = get_lab_results_for_user(db, user_id)
    if not labs:
        labs = [r for r in MOCK_LAB_RESULTS if r["user_id"] == user_id]
    goals = derive_goals_from_labs(labs, user)
    set_user_goals(user_id, goals)
    return goals


def update_goal_priorities(user_id: int, ordered_goal_types: List[str]) -> List[Dict[str, Any]]:
    """Reorder goals based on user instruction (e.g., 'focus on diabetes first')."""
    current = get_user_goals(user_id) or []
    goal_map = {g["goal_type"]: g for g in current}

    reordered = []
    for i, gt in enumerate(ordered_goal_types, 1):
        if gt in goal_map:
            g = goal_map[gt]
            g["priority"] = i
            reordered.append(g)

    # Append any goals not mentioned, at lower priority
    for g in current:
        if g["goal_type"] not in ordered_goal_types:
            g["priority"] = len(reordered) + 1
            reordered.append(g)

    reordered.sort(key=lambda g: g["priority"])
    return set_user_goals(user_id, reordered)


def parse_priority_from_message(message: str, current_goals: List[Dict[str, Any]]) -> Optional[List[str]]:
    """Parse natural language priority changes."""
    msg = message.lower()
    priority_keywords = {
        "cholesterol": "lower_cholesterol",
        "ldl": "lower_cholesterol",
        "blood sugar": "manage_diabetes",
        "diabetes": "manage_diabetes",
        "glucose": "manage_diabetes",
        "sugar": "manage_diabetes",
        "blood pressure": "lower_blood_pressure",
        "hypertension": "lower_blood_pressure",
        "weight": "weight_loss",
        "vitamin d": "increase_vitamin_d",
        "inflammation": "reduce_inflammation",
        "energy": "increase_energy",
        "gut": "gut_health",
    }

  # Detect "first X, then Y" patterns
    if "first" in msg or "priority" in msg or "focus on" in msg:
        mentioned = []
        for keyword, goal_type in priority_keywords.items():
            if keyword in msg:
                if goal_type not in mentioned:
                    mentioned.append(goal_type)
        if mentioned:
            existing = [g["goal_type"] for g in current_goals if g["goal_type"] not in mentioned]
            return mentioned + existing
    return None
