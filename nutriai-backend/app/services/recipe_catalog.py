"""
Procedural recipe catalog — generates 1,500+ unique, nutritionally-tagged recipes.
Supports ingredient substitutions (tofu ↔ paneer, etc.) for AI-driven customization.
"""
from __future__ import annotations

import hashlib
import re
from itertools import product
from typing import Any, Dict, List, Optional, Set

# Ingredient substitution groups — AI chat uses these for swaps
SUBSTITUTION_GROUPS: Dict[str, List[str]] = {
    "tofu": ["paneer", "tempeh", "chickpeas", "lentils"],
    "paneer": ["tofu", "cottage cheese", "halloumi"],
    "chicken": ["turkey", "tofu", "paneer", "fish", "lentils"],
    "salmon": ["mackerel", "sardines", "tofu", "chickpeas"],
    "beef": ["lentils", "mushrooms", "tempeh", "chicken"],
    "eggs": ["tofu scramble", "chickpea flour", "flax eggs"],
    "dairy milk": ["oat milk", "almond milk", "coconut milk"],
    "greek yogurt": ["coconut yogurt", "soy yogurt", "skyr"],
    "white rice": ["brown rice", "quinoa", "cauliflower rice", "millet"],
    "pasta": ["zucchini noodles", "chickpea pasta", "brown rice noodles"],
    "bread": ["whole grain roti", "sourdough", "lettuce wraps"],
}

PROTEINS = [
    {"name": "Grilled Chicken Breast", "tags": ["high-protein", "lean"], "dietary": ["omnivore"], "cal": 165, "protein": 31, "fat": 4},
    {"name": "Baked Salmon", "tags": ["heart-healthy", "omega-3", "anti-inflammatory"], "dietary": ["pescatarian", "omnivore"], "cal": 208, "protein": 20, "fat": 13},
    {"name": "Firm Tofu", "tags": ["plant-based", "heart-healthy"], "dietary": ["vegan", "vegetarian"], "cal": 144, "protein": 17, "fat": 9},
    {"name": "Paneer", "tags": ["high-protein", "vegetarian"], "dietary": ["vegetarian"], "cal": 265, "protein": 18, "fat": 20},
    {"name": "Lentils", "tags": ["high-fiber", "plant-based", "cholesterol-lowering"], "dietary": ["vegan", "vegetarian"], "cal": 116, "protein": 9, "fat": 0.4},
    {"name": "Chickpeas", "tags": ["high-fiber", "plant-based"], "dietary": ["vegan", "vegetarian"], "cal": 164, "protein": 9, "fat": 2.6},
    {"name": "Turkey Breast", "tags": ["lean", "high-protein"], "dietary": ["omnivore"], "cal": 135, "protein": 30, "fat": 1},
    {"name": "Shrimp", "tags": ["lean", "high-protein"], "dietary": ["pescatarian", "omnivore"], "cal": 99, "protein": 24, "fat": 0.3},
    {"name": "Eggs", "tags": ["high-protein"], "dietary": ["vegetarian", "omnivore"], "cal": 155, "protein": 13, "fat": 11},
    {"name": "Tempeh", "tags": ["plant-based", "probiotic"], "dietary": ["vegan", "vegetarian"], "cal": 192, "protein": 20, "fat": 11},
    {"name": "Black Beans", "tags": ["high-fiber", "plant-based"], "dietary": ["vegan", "vegetarian"], "cal": 132, "protein": 9, "fat": 0.5},
    {"name": "Cod", "tags": ["lean", "heart-healthy"], "dietary": ["pescatarian", "omnivore"], "cal": 82, "protein": 18, "fat": 0.7},
]

BASES = [
    {"name": "Quinoa", "tags": ["gluten-free", "high-protein"], "cal": 120, "carbs": 21, "fiber": 3},
    {"name": "Brown Rice", "tags": ["whole-grain"], "cal": 112, "carbs": 24, "fiber": 2},
    {"name": "Sweet Potato", "tags": ["complex-carbs", "vitamin-a"], "cal": 86, "carbs": 20, "fiber": 3},
    {"name": "Whole Wheat Roti", "tags": ["whole-grain"], "cal": 71, "carbs": 15, "fiber": 2},
    {"name": "Cauliflower Rice", "tags": ["low-carb", "gluten-free"], "cal": 25, "carbs": 5, "fiber": 2},
    {"name": "Millet", "tags": ["gluten-free", "ancient-grain"], "cal": 119, "carbs": 23, "fiber": 1},
    {"name": "Barley", "tags": ["cholesterol-lowering", "high-fiber"], "cal": 123, "carbs": 28, "fiber": 4},
    {"name": "Buckwheat", "tags": ["gluten-free"], "cal": 92, "carbs": 20, "fiber": 3},
]

VEGETABLES = [
    "Spinach", "Broccoli", "Kale", "Bell Peppers", "Zucchini", "Asparagus",
    "Green Beans", "Cauliflower", "Carrots", "Tomatoes", "Eggplant", "Okra",
    "Bok Choy", "Brussels Sprouts", "Mushrooms", "Cabbage", "Beetroot",
]

SAUCES = [
    {"name": "Lemon Herb", "cuisine": "Mediterranean", "tags": ["light", "heart-healthy"]},
    {"name": "Tikka Masala", "cuisine": "Indian", "tags": ["anti-inflammatory"]},
    {"name": "Ginger Soy", "cuisine": "Asian", "tags": ["low-sodium-option"]},
    {"name": "Pesto", "cuisine": "Italian", "tags": ["heart-healthy"]},
    {"name": "Harissa", "cuisine": "Middle Eastern", "tags": ["metabolism-boost"]},
    {"name": "Mole", "cuisine": "Mexican", "tags": ["antioxidant-rich"]},
    {"name": "Teriyaki", "cuisine": "Japanese", "tags": ["balanced"]},
    {"name": "Tahini Lemon", "cuisine": "Middle Eastern", "tags": ["calcium-rich"]},
    {"name": "Coconut Curry", "cuisine": "Thai", "tags": ["anti-inflammatory"]},
    {"name": "Garlic Olive Oil", "cuisine": "Mediterranean", "tags": ["heart-healthy"]},
]

COOKING_METHODS = ["Grilled", "Baked", "Steamed", "Stir-Fried", "Roasted", "Poached", "Slow-Cooked"]
MEAL_SLOTS = {
    "breakfast": ["bowl", "scramble", "parfait", "toast", "smoothie bowl", "oatmeal"],
    "lunch": ["bowl", "salad", "wrap", "stew", "plate"],
    "dinner": ["bowl", "curry", "plate", "stew", "skillet"],
    "snack": ["bites", "smoothie", "parfait", "hummus plate"],
}

HEALTH_GOAL_TAGS = {
    "lower_cholesterol": ["cholesterol-lowering", "heart-healthy", "high-fiber", "omega-3"],
    "weight_loss": ["lean", "low-carb", "high-protein", "high-fiber"],
    "manage_diabetes": ["low-glycemic", "high-fiber", "balanced", "complex-carbs"],
    "lower_blood_pressure": ["low-sodium-option", "heart-healthy", "potassium-rich"],
    "increase_energy": ["iron-rich", "balanced", "complex-carbs"],
    "muscle_gain": ["high-protein", "lean"],
    "gut_health": ["probiotic", "high-fiber", "plant-based"],
    "reduce_inflammation": ["anti-inflammatory", "omega-3", "antioxidant-rich"],
}

CUISINE_IMAGES = {
    "Mediterranean": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd",
    "Indian": "https://images.unsplash.com/photo-1585937421612-70a008356fbe",
    "Asian": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
    "Italian": "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38",
    "Middle Eastern": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe",
    "Mexican": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47",
    "Japanese": "https://images.unsplash.com/photo-1547592166-23ac45744acd",
    "Thai": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd",
    "American": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe",
}

_catalog: Optional[List[Dict[str, Any]]] = None


def _slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _estimate_nutrition(protein: dict, base: dict, meal_type: str) -> dict:
    portion = {"breakfast": 0.8, "lunch": 1.0, "dinner": 1.1, "snack": 0.5}.get(meal_type, 1.0)
    cal = int((protein["cal"] + base["cal"]) * portion + 80)
    return {
        "calories": cal,
        "protein_g": int(protein["protein"] * portion + 2),
        "carbs_g": int(base.get("carbs", 15) * portion + 8),
        "fat_g": int(protein.get("fat", 5) * portion + 4),
        "fiber_g": int(base.get("fiber", 3) + 2),
        "sugar_g": 6 if meal_type == "breakfast" else 4,
        "sodium_mg": 380,
        "cholesterol_mg": 0 if "vegan" in protein.get("dietary", []) else 45,
    }


def generate_recipe_catalog(target_count: int = 1500) -> List[Dict[str, Any]]:
    """Generate a diverse recipe catalog — protein-balanced (veg + non-veg + global cuisines)."""
    recipes: List[Dict[str, Any]] = []
    seen_names: Set[str] = set()
    recipe_id = 1

    from app.db.mock_data import MOCK_RECIPES as HANDCRAFTED
    for r in HANDCRAFTED:
        recipes.append(dict(r))
        seen_names.add(r["name"].lower())
        recipe_id = max(recipe_id, r["id"] + 1)

    # Round-robin proteins so vegetarian options aren't starved by chicken-first product()
    outer = list(product(BASES, VEGETABLES[:12], SAUCES, COOKING_METHODS))
    protein_idx = 0
    meal_types = list(MEAL_SLOTS.keys())

    for base, veg, sauce, method in outer:
        if len(recipes) >= target_count:
            break
        protein = PROTEINS[protein_idx % len(PROTEINS)]
        protein_idx += 1
        meal_type = meal_types[recipe_id % len(meal_types)]
        formats = MEAL_SLOTS[meal_type]
        fmt = formats[recipe_id % len(formats)]
        name = f"{method} {protein['name']} {fmt.title()} with {veg} & {sauce['name']}"
        if name.lower() in seen_names:
            continue
        seen_names.add(name.lower())

        health_tags = list(set(protein["tags"] + base["tags"] + sauce["tags"] + ["nutrient-dense"]))
        dietary_tags = list(protein.get("dietary", []))
        if "gluten-free" in base.get("tags", []):
            dietary_tags = list(set(dietary_tags + ["gluten-free"]))

        nutrition = _estimate_nutrition(protein, base, meal_type)
        cuisine = sauce["cuisine"]
        difficulty = ["easy", "medium", "hard"][recipe_id % 3]

        recipes.append({
            "id": recipe_id,
            "name": name,
            "slug": _slugify(name),
            "description": (
                f"A {method.lower()} {meal_type} featuring {protein['name'].lower()} "
                f"with {base['name'].lower()}, fresh {veg.lower()}, and {sauce['name'].lower()} — "
                f"crafted for personalized nutrition goals."
            ),
            "cuisine_type": cuisine,
            "meal_type": [meal_type],
            "dietary_tags": dietary_tags,
            "health_tags": health_tags,
            "prep_time_minutes": 10 + (recipe_id % 15),
            "cook_time_minutes": 15 + (recipe_id % 25),
            "servings": 2 + (recipe_id % 3),
            "difficulty": difficulty,
            "image_url": CUISINE_IMAGES.get(cuisine, CUISINE_IMAGES["Mediterranean"]),
            "ingredients": [
                {"item": protein["name"], "quantity": "6", "unit": "oz", "notes": "main protein"},
                {"item": base["name"], "quantity": "1", "unit": "cup", "notes": "cooked"},
                {"item": veg, "quantity": "2", "unit": "cups", "notes": "fresh, chopped"},
                {"item": sauce["name"], "quantity": "3", "unit": "tbsp", "notes": "sauce/dressing"},
                {"item": "Olive oil", "quantity": "1", "unit": "tbsp", "notes": ""},
                {"item": "Garlic", "quantity": "2", "unit": "cloves", "notes": "minced"},
                {"item": "Salt and pepper", "quantity": "to taste", "unit": "", "notes": ""},
            ],
            "instructions": [
                f"Prep all ingredients: chop {veg.lower()}, measure {base['name'].lower()}.",
                f"Season {protein['name'].lower()} with salt, pepper, and half the {sauce['name'].lower()}.",
                f"{method} until cooked through.",
                f"Prepare {base['name'].lower()}; sauté {veg.lower()} with garlic and olive oil.",
                f"Combine and finish with remaining {sauce['name'].lower()}. Serve warm.",
            ],
            "nutrition": nutrition,
            "primary_protein": protein["name"].split()[-1].lower(),
            "substitutable_ingredients": [protein["name"].split()[-1].lower()],
        })
        recipe_id += 1

    return recipes


def get_recipe_catalog() -> List[Dict[str, Any]]:
    global _catalog
    if _catalog is None:
        _catalog = generate_recipe_catalog(1500)
    return _catalog


def reset_recipe_catalog() -> None:
    """Clear cached catalog (call after generator changes)."""
    global _catalog
    _catalog = None


def get_recipe_by_id(recipe_id: int) -> Optional[Dict[str, Any]]:
    return next((r for r in get_recipe_catalog() if r["id"] == recipe_id), None)


def search_recipes(
    query: str = "",
    meal_type: Optional[str] = None,
    dietary_type: Optional[str] = None,
    health_goal: Optional[str] = None,
    exclude_allergens: Optional[List[str]] = None,
    ingredient_contains: Optional[str] = None,
    ingredient_excludes: Optional[str] = None,
    page: int = 1,
    limit: int = 20,
) -> Dict[str, Any]:
    recipes = get_recipe_catalog()
    q = query.lower()

    if q:
        recipes = [
            r for r in recipes
            if q in r["name"].lower() or q in r["description"].lower()
            or any(q in ing["item"].lower() for ing in r["ingredients"])
        ]
    if meal_type:
        recipes = [r for r in recipes if meal_type in r.get("meal_type", [])]
    if dietary_type:
        recipes = [r for r in recipes if dietary_type in r.get("dietary_tags", [])]
    if health_goal and health_goal in HEALTH_GOAL_TAGS:
        target_tags = set(HEALTH_GOAL_TAGS[health_goal])
        recipes = [
            r for r in recipes
            if target_tags & set(r.get("health_tags", []))
        ]
    if exclude_allergens:
        for allergen in exclude_allergens:
            recipes = [
                r for r in recipes
                if allergen.lower() not in " ".join(i["item"] for i in r["ingredients"]).lower()
            ]
    if ingredient_contains:
        ic = ingredient_contains.lower()
        recipes = [r for r in recipes if any(ic in i["item"].lower() for i in r["ingredients"])]
    if ingredient_excludes:
        ie = ingredient_excludes.lower()
        recipes = [r for r in recipes if not any(ie in i["item"].lower() for i in r["ingredients"])]

    total = len(recipes)
    start = (page - 1) * limit
    return {
        "recipes": recipes[start:start + limit],
        "total": total,
        "page": page,
        "limit": limit,
    }


def find_substitute_recipes(
    original_recipe: Dict[str, Any],
    swap_from: str,
    swap_to: str,
    meal_type: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Find recipes matching swap criteria for diet customization."""
    mt = meal_type or (original_recipe.get("meal_type") or ["dinner"])[0]
    health_tags = original_recipe.get("health_tags", [])

    candidates = search_recipes(
        meal_type=mt,
        ingredient_contains=swap_to,
        ingredient_excludes=swap_from,
        limit=50,
    )["recipes"]

    # Score by health tag overlap and calorie similarity
    target_cal = original_recipe.get("nutrition", {}).get("calories", 400)

    def score(r: Dict[str, Any]) -> float:
        tag_overlap = len(set(health_tags) & set(r.get("health_tags", [])))
        cal_diff = abs(r.get("nutrition", {}).get("calories", 400) - target_cal)
        return tag_overlap * 10 - cal_diff * 0.05

    candidates.sort(key=score, reverse=True)
    return candidates[:10]


def apply_ingredient_swap(recipe: Dict[str, Any], swap_from: str, swap_to: str) -> Dict[str, Any]:
    """Return a modified recipe copy with ingredient swapped."""
    import copy
    modified = copy.deepcopy(recipe)
    sf, st = swap_from.lower(), swap_to.lower()

    for ing in modified["ingredients"]:
        if sf in ing["item"].lower():
            ing["item"] = re.sub(re.escape(swap_from), swap_to.title(), ing["item"], flags=re.IGNORECASE)
            ing["notes"] = f"Swapped from {swap_from} per your preference"

    modified["name"] = re.sub(re.escape(swap_from), swap_to.title(), modified["name"], flags=re.IGNORECASE)
    modified["description"] = (
        f"Customized for you: {modified['description']} "
        f"(substituted {swap_from} with {swap_to})"
    )
    modified["id"] = int(hashlib.md5(f"{recipe['id']}-{sf}-{st}".encode()).hexdigest()[:8], 16) % 1000000
    modified["health_tags"] = list(set(modified.get("health_tags", []) + ["customized"]))
    return modified


def get_substitution_options(ingredient: str) -> List[str]:
    key = ingredient.lower().strip()
    for group_key, alternatives in SUBSTITUTION_GROUPS.items():
        if key in group_key or group_key in key:
            return alternatives
    return []
