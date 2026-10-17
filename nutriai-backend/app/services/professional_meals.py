"""
Professional / generic meal templates for production-looking diet plans.
Used instead of awkward procedural names during weekly plan generation.
"""
from __future__ import annotations

from typing import Any, Dict, List

# Real-world style meals — breakfast / lunch / dinner / snack across cuisines
PROFESSIONAL_MEALS: List[Dict[str, Any]] = [
    # Breakfast
    {"name": "Greek Yogurt Parfait with Berries & Walnuts", "meal_type": ["breakfast"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "heart-healthy", "nutrient-dense"], "primary_protein": "yogurt", "cal": 340, "protein": 22, "carbs": 38, "fat": 12},
    {"name": "Vegetable Omelette with Whole-Grain Toast", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "balanced"], "primary_protein": "eggs", "cal": 380, "protein": 24, "carbs": 28, "fat": 18},
    {"name": "Overnight Oats with Chia, Almond Butter & Banana", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "complex-carbs", "heart-healthy"], "primary_protein": "oats", "cal": 420, "protein": 14, "carbs": 58, "fat": 16},
    {"name": "Spinach & Paneer Scramble with Millet Roti", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "iron-rich"], "primary_protein": "paneer", "cal": 410, "protein": 26, "carbs": 32, "fat": 18},
    {"name": "Smoked Salmon Avocado Toast", "meal_type": ["breakfast"], "cuisine_type": "Mediterranean", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "heart-healthy", "high-protein"], "primary_protein": "salmon", "cal": 390, "protein": 23, "carbs": 30, "fat": 20},
    {"name": "Tofu Scramble Breakfast Bowl with Peppers", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-protein", "low-carb"], "primary_protein": "tofu", "cal": 320, "protein": 22, "carbs": 18, "fat": 16},
    {"name": "Idli with Sambar & Coconut Chutney", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["low-glycemic", "probiotic", "balanced"], "primary_protein": "lentils", "cal": 350, "protein": 12, "carbs": 62, "fat": 6},
    {"name": "Protein Smoothie Bowl (Berries, Spinach, Whey/Plant Protein)", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "antioxidant-rich"], "primary_protein": "protein", "cal": 360, "protein": 30, "carbs": 40, "fat": 8},
    # Lunch
    {"name": "Grilled Chicken Quinoa Bowl with Roasted Vegetables", "meal_type": ["lunch"], "cuisine_type": "Mediterranean", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean", "balanced"], "primary_protein": "chicken", "cal": 480, "protein": 38, "carbs": 42, "fat": 14},
    {"name": "Lentil Dal with Brown Rice & Cucumber Salad", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "cholesterol-lowering"], "primary_protein": "lentils", "cal": 450, "protein": 20, "carbs": 68, "fat": 10},
    {"name": "Mediterranean Chickpea Salad with Feta & Olive Oil", "meal_type": ["lunch"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["heart-healthy", "high-fiber", "anti-inflammatory"], "primary_protein": "chickpeas", "cal": 430, "protein": 16, "carbs": 40, "fat": 22},
    {"name": "Turkey & Avocado Wrap with Mixed Greens", "meal_type": ["lunch"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean"], "primary_protein": "turkey", "cal": 440, "protein": 32, "carbs": 36, "fat": 16},
    {"name": "Baked Salmon with Sweet Potato & Steamed Broccoli", "meal_type": ["lunch", "dinner"], "cuisine_type": "American", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "heart-healthy", "high-protein"], "primary_protein": "salmon", "cal": 520, "protein": 36, "carbs": 38, "fat": 22},
    {"name": "Buddha Bowl: Tofu, Quinoa, Kale & Tahini", "meal_type": ["lunch"], "cuisine_type": "Asian", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-fiber", "balanced"], "primary_protein": "tofu", "cal": 460, "protein": 24, "carbs": 48, "fat": 18},
    {"name": "Chicken Tikka with Quinoa Pilaf & Raita", "meal_type": ["lunch", "dinner"], "cuisine_type": "Indian", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "anti-inflammatory", "lean"], "primary_protein": "chicken", "cal": 510, "protein": 40, "carbs": 44, "fat": 16},
    {"name": "Black Bean Burrito Bowl with Brown Rice & Salsa", "meal_type": ["lunch"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "complex-carbs"], "primary_protein": "beans", "cal": 470, "protein": 18, "carbs": 72, "fat": 12},
    {"name": "Shrimp Stir-Fry with Brown Rice & Mixed Vegetables", "meal_type": ["lunch", "dinner"], "cuisine_type": "Asian", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["high-protein", "lean", "low-carb"], "primary_protein": "shrimp", "cal": 430, "protein": 34, "carbs": 40, "fat": 10},
    {"name": "Grilled Paneer Salad with Millet & Mint Dressing", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "balanced"], "primary_protein": "paneer", "cal": 450, "protein": 28, "carbs": 36, "fat": 20},
    # Dinner
    {"name": "Herb-Roasted Cod with Quinoa & Asparagus", "meal_type": ["dinner"], "cuisine_type": "Mediterranean", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["lean", "heart-healthy", "high-protein"], "primary_protein": "cod", "cal": 420, "protein": 36, "carbs": 34, "fat": 12},
    {"name": "Turkey Chili with Beans & Side Salad", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "high-fiber", "lean"], "primary_protein": "turkey", "cal": 480, "protein": 38, "carbs": 42, "fat": 14},
    {"name": "Vegetable & Tofu Coconut Curry with Cauliflower Rice", "meal_type": ["dinner"], "cuisine_type": "Thai", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "anti-inflammatory", "low-carb"], "primary_protein": "tofu", "cal": 400, "protein": 22, "carbs": 28, "fat": 22},
    {"name": "Grilled Lean Steak Tips with Roasted Vegetables", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "iron-rich", "low-carb"], "primary_protein": "beef", "cal": 490, "protein": 42, "carbs": 18, "fat": 26},
    {"name": "Baked Chicken Thighs with Mediterranean Vegetables", "meal_type": ["dinner"], "cuisine_type": "Mediterranean", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "heart-healthy", "anti-inflammatory"], "primary_protein": "chicken", "cal": 470, "protein": 38, "carbs": 22, "fat": 24},
    {"name": "Palak Paneer with Whole-Wheat Roti (Light Oil)", "meal_type": ["dinner"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["iron-rich", "high-protein", "balanced"], "primary_protein": "paneer", "cal": 460, "protein": 26, "carbs": 40, "fat": 20},
    {"name": "Miso-Glazed Salmon with Bok Choy & Brown Rice", "meal_type": ["dinner"], "cuisine_type": "Japanese", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "anti-inflammatory", "high-protein"], "primary_protein": "salmon", "cal": 500, "protein": 34, "carbs": 40, "fat": 20},
    {"name": "Chickpea & Vegetable Tagine with Couscous", "meal_type": ["dinner"], "cuisine_type": "Middle Eastern", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["plant-based", "high-fiber", "heart-healthy"], "primary_protein": "chickpeas", "cal": 440, "protein": 16, "carbs": 70, "fat": 10},
    {"name": "Tempeh Stir-Fry with Broccoli & Ginger Soy", "meal_type": ["dinner"], "cuisine_type": "Asian", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-protein", "probiotic"], "primary_protein": "tempeh", "cal": 410, "protein": 28, "carbs": 32, "fat": 16},
    {"name": "Stuffed Bell Peppers with Lean Turkey & Quinoa", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "balanced", "lean"], "primary_protein": "turkey", "cal": 450, "protein": 34, "carbs": 38, "fat": 14},
    # Snacks
    {"name": "Apple Slices with Almond Butter", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["heart-healthy", "balanced"], "primary_protein": "nuts", "cal": 220, "protein": 6, "carbs": 24, "fat": 12},
    {"name": "Cottage Cheese with Cucumber & Cherry Tomatoes", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "low-carb"], "primary_protein": "cottage cheese", "cal": 180, "protein": 20, "carbs": 8, "fat": 6},
    {"name": "Hummus with Carrot & Bell Pepper Sticks", "meal_type": ["snack"], "cuisine_type": "Middle Eastern", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["plant-based", "high-fiber"], "primary_protein": "chickpeas", "cal": 200, "protein": 8, "carbs": 22, "fat": 10},
    {"name": "Handful of Mixed Nuts & Dark Chocolate Square", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["heart-healthy", "antioxidant-rich"], "primary_protein": "nuts", "cal": 240, "protein": 6, "carbs": 14, "fat": 18},
    {"name": "Roasted Chickpeas with Spices", "meal_type": ["snack"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "high-protein"], "primary_protein": "chickpeas", "cal": 190, "protein": 10, "carbs": 26, "fat": 6},
    {"name": "Greek Yogurt with Honey & Flaxseed", "meal_type": ["snack"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "omega-3", "probiotic"], "primary_protein": "yogurt", "cal": 210, "protein": 18, "carbs": 22, "fat": 6},
    {"name": "Edamame with Sea Salt", "meal_type": ["snack"], "cuisine_type": "Japanese", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["plant-based", "high-protein"], "primary_protein": "edamame", "cal": 170, "protein": 14, "carbs": 12, "fat": 6},
    {"name": "Protein Bar Alternative: Date & Nut Energy Bites", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["nutrient-dense", "balanced"], "primary_protein": "nuts", "cal": 230, "protein": 6, "carbs": 28, "fat": 12},
]


def professional_meal_to_recipe(meal: Dict[str, Any], recipe_id: int) -> Dict[str, Any]:
    protein = meal.get("primary_protein", "protein")
    return {
        "id": recipe_id,
        "name": meal["name"],
        "slug": meal["name"].lower().replace(" ", "-").replace("&", "and")[:80],
        "description": f"A balanced {meal['meal_type'][0]} featuring {protein} — designed for sustainable nutrition goals.",
        "cuisine_type": meal["cuisine_type"],
        "meal_type": meal["meal_type"],
        "dietary_tags": meal.get("dietary_tags", []),
        "health_tags": meal.get("health_tags", []),
        "prep_time_minutes": 15,
        "cook_time_minutes": 20,
        "servings": 1,
        "difficulty": "easy",
        "image_url": "",
        "ingredients": [
            {"item": meal["name"].split(" with ")[0], "quantity": "1", "unit": "serving", "notes": "as prepared"},
            {"item": "Olive oil", "quantity": "1", "unit": "tsp", "notes": "optional"},
            {"item": "Herbs and spices", "quantity": "to taste", "unit": "", "notes": ""},
        ],
        "instructions": [
            "Prep fresh ingredients.",
            f"Prepare {meal['name']} using standard healthy cooking methods (grill, bake, steam, or sauté).",
            "Season lightly; prefer herbs, citrus, and spices over excess salt.",
            "Serve in the portion size aligned with your daily calorie target.",
        ],
        "nutrition": {
            "calories": meal.get("cal", 400),
            "protein_g": meal.get("protein", 20),
            "carbs_g": meal.get("carbs", 40),
            "fat_g": meal.get("fat", 12),
            "fiber_g": 8,
        },
        "primary_protein": protein,
        "substitutable_ingredients": [protein],
        "professional": True,
    }


def build_professional_catalog(start_id: int = 50000) -> List[Dict[str, Any]]:
    return [professional_meal_to_recipe(m, start_id + i) for i, m in enumerate(PROFESSIONAL_MEALS)]
