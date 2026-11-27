"""
Professional meal seeds for catalog fallback when live AI is unavailable.
Includes authentic Indian/Mexican/etc. dishes with real quantities + cook steps.
"""
from __future__ import annotations

from typing import Any, Dict, List

PROFESSIONAL_MEALS: List[Dict[str, Any]] = [
    # Breakfast
    {"name": "Greek Yogurt Parfait with Berries & Walnuts", "meal_type": ["breakfast"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "heart-healthy", "nutrient-dense"], "primary_protein": "yogurt", "cal": 340, "protein": 22, "carbs": 38, "fat": 12},
    {"name": "Vegetable Omelette with Whole-Grain Toast", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "balanced"], "primary_protein": "eggs", "cal": 380, "protein": 24, "carbs": 28, "fat": 18},
    {"name": "Overnight Oats with Chia, Almond Butter & Banana", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "complex-carbs", "heart-healthy"], "primary_protein": "oats", "cal": 420, "protein": 14, "carbs": 58, "fat": 16},
    {"name": "Spinach & Paneer Scramble with Millet Roti", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "iron-rich"], "primary_protein": "paneer", "cal": 410, "protein": 26, "carbs": 32, "fat": 18},
    {"name": "Smoked Salmon Avocado Toast", "meal_type": ["breakfast"], "cuisine_type": "Mediterranean", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "heart-healthy", "high-protein"], "primary_protein": "salmon", "cal": 390, "protein": 23, "carbs": 30, "fat": 20},
    {"name": "Tofu Scramble Breakfast Bowl with Peppers", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-protein", "low-carb"], "primary_protein": "tofu", "cal": 320, "protein": 22, "carbs": 18, "fat": 16},
    {"name": "Idli with Sambar & Coconut Chutney", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["low-glycemic", "probiotic", "balanced"], "primary_protein": "lentils", "cal": 350, "protein": 12, "carbs": 62, "fat": 6},
    {"name": "Masala Oats with Vegetables", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "complex-carbs", "heart-healthy"], "primary_protein": "oats", "cal": 360, "protein": 12, "carbs": 54, "fat": 10},
    {"name": "Poha with Peas & Peanuts", "meal_type": ["breakfast"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["balanced", "high-fiber"], "primary_protein": "peanuts", "cal": 380, "protein": 11, "carbs": 58, "fat": 12},
    {"name": "Huevos Rancheros with Black Beans", "meal_type": ["breakfast"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "high-fiber"], "primary_protein": "eggs", "cal": 420, "protein": 22, "carbs": 36, "fat": 20},
    {"name": "Breakfast Burrito with Eggs, Salsa & Avocado", "meal_type": ["breakfast"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "balanced"], "primary_protein": "eggs", "cal": 440, "protein": 24, "carbs": 40, "fat": 20},
    {"name": "Protein Smoothie Bowl (Berries, Spinach, Whey/Plant Protein)", "meal_type": ["breakfast"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "antioxidant-rich"], "primary_protein": "protein", "cal": 360, "protein": 30, "carbs": 40, "fat": 8},
    # Lunch
    {"name": "Grilled Chicken Quinoa Bowl with Roasted Vegetables", "meal_type": ["lunch"], "cuisine_type": "Mediterranean", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean", "balanced"], "primary_protein": "chicken", "cal": 480, "protein": 38, "carbs": 42, "fat": 14},
    {"name": "Lentil Dal with Brown Rice & Cucumber Salad", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "cholesterol-lowering"], "primary_protein": "lentils", "cal": 450, "protein": 20, "carbs": 68, "fat": 10},
    {"name": "Chana Masala with Brown Rice", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "heart-healthy"], "primary_protein": "chickpeas", "cal": 460, "protein": 18, "carbs": 70, "fat": 12},
    {"name": "Rajma Bowl with Jeera Rice & Salad", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "complex-carbs"], "primary_protein": "beans", "cal": 470, "protein": 17, "carbs": 72, "fat": 10},
    {"name": "Mediterranean Chickpea Salad with Feta & Olive Oil", "meal_type": ["lunch"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["heart-healthy", "high-fiber", "anti-inflammatory"], "primary_protein": "chickpeas", "cal": 430, "protein": 16, "carbs": 40, "fat": 22},
    {"name": "Turkey & Avocado Wrap with Mixed Greens", "meal_type": ["lunch"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean"], "primary_protein": "turkey", "cal": 440, "protein": 32, "carbs": 36, "fat": 16},
    {"name": "Baked Salmon with Sweet Potato & Steamed Broccoli", "meal_type": ["lunch", "dinner"], "cuisine_type": "American", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "heart-healthy", "high-protein"], "primary_protein": "salmon", "cal": 520, "protein": 36, "carbs": 38, "fat": 22},
    {"name": "Buddha Bowl: Tofu, Quinoa, Kale & Tahini", "meal_type": ["lunch"], "cuisine_type": "Asian", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-fiber", "balanced"], "primary_protein": "tofu", "cal": 460, "protein": 24, "carbs": 48, "fat": 18},
    {"name": "Chicken Tikka with Quinoa Pilaf & Raita", "meal_type": ["lunch", "dinner"], "cuisine_type": "Indian", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "anti-inflammatory", "lean"], "primary_protein": "chicken", "cal": 510, "protein": 40, "carbs": 44, "fat": 16},
    {"name": "Black Bean Burrito Bowl with Brown Rice & Salsa", "meal_type": ["lunch"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "complex-carbs"], "primary_protein": "beans", "cal": 470, "protein": 18, "carbs": 72, "fat": 12},
    {"name": "Chicken Fajita Bowl with Peppers & Brown Rice", "meal_type": ["lunch", "dinner"], "cuisine_type": "Mexican", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean", "balanced"], "primary_protein": "chicken", "cal": 490, "protein": 38, "carbs": 48, "fat": 14},
    {"name": "Fish Tacos with Cabbage Slaw & Lime", "meal_type": ["lunch", "dinner"], "cuisine_type": "Mexican", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["high-protein", "lean", "heart-healthy"], "primary_protein": "fish", "cal": 450, "protein": 32, "carbs": 42, "fat": 16},
    {"name": "Shrimp Stir-Fry with Brown Rice & Mixed Vegetables", "meal_type": ["lunch", "dinner"], "cuisine_type": "Asian", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["high-protein", "lean", "low-carb"], "primary_protein": "shrimp", "cal": 430, "protein": 34, "carbs": 40, "fat": 10},
    {"name": "Grilled Paneer Salad with Millet & Mint Dressing", "meal_type": ["lunch"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "balanced"], "primary_protein": "paneer", "cal": 450, "protein": 28, "carbs": 36, "fat": 20},
    # Dinner
    {"name": "Herb-Roasted Cod with Quinoa & Asparagus", "meal_type": ["dinner"], "cuisine_type": "Mediterranean", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["lean", "heart-healthy", "high-protein"], "primary_protein": "cod", "cal": 420, "protein": 36, "carbs": 34, "fat": 12},
    {"name": "Turkey Chili with Beans & Side Salad", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "high-fiber", "lean"], "primary_protein": "turkey", "cal": 480, "protein": 38, "carbs": 42, "fat": 14},
    {"name": "Vegetable & Tofu Coconut Curry with Cauliflower Rice", "meal_type": ["dinner"], "cuisine_type": "Thai", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "anti-inflammatory", "low-carb"], "primary_protein": "tofu", "cal": 400, "protein": 22, "carbs": 28, "fat": 22},
    {"name": "Grilled Lean Steak Tips with Roasted Vegetables", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "iron-rich", "low-carb"], "primary_protein": "beef", "cal": 490, "protein": 42, "carbs": 18, "fat": 26},
    {"name": "Baked Chicken Thighs with Mediterranean Vegetables", "meal_type": ["dinner"], "cuisine_type": "Mediterranean", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "heart-healthy", "anti-inflammatory"], "primary_protein": "chicken", "cal": 470, "protein": 38, "carbs": 22, "fat": 24},
    {"name": "Palak Paneer with Whole-Wheat Roti (Light Oil)", "meal_type": ["dinner"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian"], "health_tags": ["iron-rich", "high-protein", "balanced"], "primary_protein": "paneer", "cal": 460, "protein": 26, "carbs": 40, "fat": 20},
    {"name": "Baingan Bharta with Millet Roti & Salad", "meal_type": ["dinner"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "heart-healthy"], "primary_protein": "vegetables", "cal": 400, "protein": 12, "carbs": 58, "fat": 14},
    {"name": "Tandoori Tofu with Vegetable Pulao", "meal_type": ["dinner"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["plant-based", "high-protein", "anti-inflammatory"], "primary_protein": "tofu", "cal": 430, "protein": 24, "carbs": 48, "fat": 14},
    {"name": "Turkey Soft Tacos with Pico de Gallo", "meal_type": ["dinner"], "cuisine_type": "Mexican", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "lean", "balanced"], "primary_protein": "turkey", "cal": 460, "protein": 36, "carbs": 40, "fat": 16},
    {"name": "Vegetarian Enchiladas with Black Beans & Salsa Verde", "meal_type": ["dinner"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian"], "health_tags": ["high-fiber", "plant-based", "balanced"], "primary_protein": "beans", "cal": 450, "protein": 20, "carbs": 58, "fat": 14},
    {"name": "Miso-Glazed Salmon with Bok Choy & Brown Rice", "meal_type": ["dinner"], "cuisine_type": "Japanese", "dietary_tags": ["pescatarian", "omnivore"], "health_tags": ["omega-3", "anti-inflammatory", "high-protein"], "primary_protein": "salmon", "cal": 500, "protein": 34, "carbs": 40, "fat": 20},
    {"name": "Chickpea & Vegetable Tagine with Couscous", "meal_type": ["dinner"], "cuisine_type": "Middle Eastern", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["plant-based", "high-fiber", "heart-healthy"], "primary_protein": "chickpeas", "cal": 440, "protein": 16, "carbs": 70, "fat": 10},
    {"name": "Tempeh Stir-Fry with Broccoli & Ginger Soy", "meal_type": ["dinner"], "cuisine_type": "Asian", "dietary_tags": ["vegan", "vegetarian"], "health_tags": ["plant-based", "high-protein", "probiotic"], "primary_protein": "tempeh", "cal": 410, "protein": 28, "carbs": 32, "fat": 16},
    {"name": "Stuffed Bell Peppers with Lean Turkey & Quinoa", "meal_type": ["dinner"], "cuisine_type": "American", "dietary_tags": ["omnivore"], "health_tags": ["high-protein", "balanced", "lean"], "primary_protein": "turkey", "cal": 450, "protein": 34, "carbs": 38, "fat": 14},
    # Snacks
    {"name": "Apple Slices with Almond Butter", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["heart-healthy", "balanced"], "primary_protein": "nuts", "cal": 220, "protein": 6, "carbs": 24, "fat": 12},
    {"name": "Cottage Cheese with Cucumber & Cherry Tomatoes", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "low-carb"], "primary_protein": "cottage cheese", "cal": 180, "protein": 20, "carbs": 8, "fat": 6},
    {"name": "Roasted Chana with Spices", "meal_type": ["snack"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "high-protein"], "primary_protein": "chickpeas", "cal": 200, "protein": 10, "carbs": 28, "fat": 6},
    {"name": "Sprouted Moong Salad", "meal_type": ["snack"], "cuisine_type": "Indian", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["high-fiber", "plant-based", "low-glycemic"], "primary_protein": "lentils", "cal": 180, "protein": 12, "carbs": 26, "fat": 2},
    {"name": "Guacamole with Veggie Sticks", "meal_type": ["snack"], "cuisine_type": "Mexican", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["heart-healthy", "balanced"], "primary_protein": "avocado", "cal": 210, "protein": 4, "carbs": 14, "fat": 18},
    {"name": "Greek Yogurt with Berries", "meal_type": ["snack"], "cuisine_type": "Mediterranean", "dietary_tags": ["vegetarian"], "health_tags": ["high-protein", "probiotic"], "primary_protein": "yogurt", "cal": 190, "protein": 16, "carbs": 22, "fat": 4},
    {"name": "Handful of Mixed Nuts & Seeds", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["heart-healthy", "nutrient-dense"], "primary_protein": "nuts", "cal": 200, "protein": 6, "carbs": 8, "fat": 18},
    {"name": "Protein Bar Alternative: Date & Nut Energy Bites", "meal_type": ["snack"], "cuisine_type": "American", "dietary_tags": ["vegetarian", "vegan"], "health_tags": ["nutrient-dense", "balanced"], "primary_protein": "nuts", "cal": 230, "protein": 6, "carbs": 28, "fat": 12},
]


_CUISINE_RECIPES: Dict[str, Dict[str, Any]] = {
    "idli with sambar": {
        "ingredients": [
            {"item": "idli", "quantity": "3", "unit": "pieces"},
            {"item": "sambar", "quantity": "1", "unit": "cup"},
            {"item": "coconut chutney", "quantity": "2", "unit": "tbsp"},
        ],
        "instructions": [
            "Warm idlis in a steamer or microwave until soft.",
            "Heat sambar; thin with a splash of water if needed.",
            "Serve idlis with hot sambar and coconut chutney on the side.",
        ],
    },
    "masala oats": {
        "ingredients": [
            {"item": "rolled oats", "quantity": "1/2", "unit": "cup"},
            {"item": "mixed vegetables", "quantity": "1/2", "unit": "cup"},
            {"item": "mustard seeds", "quantity": "1/4", "unit": "tsp"},
            {"item": "curry leaves", "quantity": "4", "unit": "leaves"},
            {"item": "turmeric", "quantity": "1/8", "unit": "tsp"},
        ],
        "instructions": [
            "Temper mustard seeds and curry leaves in 1 tsp oil.",
            "Add vegetables, turmeric, and 1 cup water; bring to a simmer.",
            "Stir in oats; cook 4–5 minutes until porridge-thick. Season and serve.",
        ],
    },
    "poha with peas": {
        "ingredients": [
            {"item": "thick poha (flattened rice)", "quantity": "1", "unit": "cup"},
            {"item": "green peas", "quantity": "1/3", "unit": "cup"},
            {"item": "peanuts", "quantity": "2", "unit": "tbsp"},
            {"item": "onion", "quantity": "1/4", "unit": "medium"},
            {"item": "lemon juice", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": [
            "Rinse poha; drain and fluff with a pinch of salt and turmeric.",
            "Sauté onion, peas, and peanuts 3 minutes.",
            "Fold in poha; finish with lemon juice and serve warm.",
        ],
    },
    "spinach & paneer scramble": {
        "ingredients": [
            {"item": "paneer", "quantity": "80", "unit": "g"},
            {"item": "spinach", "quantity": "1.5", "unit": "cups"},
            {"item": "egg whites or tofu", "quantity": "2", "unit": "servings"},
            {"item": "millet roti", "quantity": "1", "unit": "piece"},
            {"item": "cumin", "quantity": "1/4", "unit": "tsp"},
        ],
        "instructions": [
            "Crumble paneer; wilt spinach in a nonstick pan with cumin.",
            "Add egg whites or crumbled tofu; scramble until set.",
            "Serve with warm millet roti.",
        ],
    },
    "lentil dal": {
        "ingredients": [
            {"item": "cooked lentils (dal)", "quantity": "1", "unit": "cup"},
            {"item": "brown rice", "quantity": "3/4", "unit": "cup"},
            {"item": "cucumber salad", "quantity": "1", "unit": "cup"},
            {"item": "cumin seeds", "quantity": "1/2", "unit": "tsp"},
            {"item": "turmeric", "quantity": "1/4", "unit": "tsp"},
        ],
        "instructions": [
            "Simmer dal with turmeric and salt until creamy.",
            "Temper cumin seeds in 1 tsp oil; pour over dal.",
            "Serve with brown rice and cucumber salad.",
        ],
    },
    "palak paneer": {
        "ingredients": [
            {"item": "paneer", "quantity": "100", "unit": "g"},
            {"item": "spinach", "quantity": "2", "unit": "cups"},
            {"item": "onion", "quantity": "1/2", "unit": "small"},
            {"item": "garlic", "quantity": "2", "unit": "cloves"},
            {"item": "whole-wheat roti", "quantity": "1", "unit": "piece"},
            {"item": "oil", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": [
            "Blanch spinach; blend with garlic into a smooth puree.",
            "Sauté onion in 1 tsp oil; add spinach puree and simmer 5 minutes.",
            "Add paneer cubes; cook 3–4 minutes. Serve with roti.",
        ],
    },
    "chana masala": {
        "ingredients": [
            {"item": "cooked chickpeas", "quantity": "1", "unit": "cup"},
            {"item": "onion", "quantity": "1/2", "unit": "medium"},
            {"item": "tomato", "quantity": "1", "unit": "medium"},
            {"item": "chana masala spice", "quantity": "1", "unit": "tsp"},
            {"item": "brown rice", "quantity": "3/4", "unit": "cup"},
        ],
        "instructions": [
            "Sauté onion until soft; add tomato and spices.",
            "Stir in chickpeas and simmer 8–10 minutes.",
            "Serve over brown rice.",
        ],
    },
    "rajma bowl": {
        "ingredients": [
            {"item": "cooked kidney beans (rajma)", "quantity": "1", "unit": "cup"},
            {"item": "onion", "quantity": "1/2", "unit": "medium"},
            {"item": "tomato", "quantity": "1", "unit": "medium"},
            {"item": "jeera rice", "quantity": "3/4", "unit": "cup"},
            {"item": "garam masala", "quantity": "1/2", "unit": "tsp"},
        ],
        "instructions": [
            "Sauté onion and tomato; add garam masala.",
            "Simmer rajma 10 minutes until saucy.",
            "Serve over jeera rice with a side salad.",
        ],
    },
    "chicken tikka": {
        "ingredients": [
            {"item": "chicken breast", "quantity": "120", "unit": "g"},
            {"item": "yogurt marinade", "quantity": "2", "unit": "tbsp"},
            {"item": "tikka spice", "quantity": "1", "unit": "tsp"},
            {"item": "quinoa", "quantity": "3/4", "unit": "cup"},
            {"item": "raita", "quantity": "2", "unit": "tbsp"},
        ],
        "instructions": [
            "Marinate chicken in yogurt and tikka spice 15+ minutes.",
            "Grill or bake at 400°F until cooked through (about 15–18 min).",
            "Serve with quinoa pilaf and raita.",
        ],
    },
    "baingan bharta": {
        "ingredients": [
            {"item": "eggplant", "quantity": "1", "unit": "medium"},
            {"item": "onion", "quantity": "1/2", "unit": "medium"},
            {"item": "tomato", "quantity": "1", "unit": "medium"},
            {"item": "millet roti", "quantity": "1", "unit": "piece"},
            {"item": "cumin", "quantity": "1/2", "unit": "tsp"},
        ],
        "instructions": [
            "Roast eggplant until soft; mash flesh.",
            "Sauté onion, tomato, and cumin; fold in mashed eggplant.",
            "Serve with millet roti and salad.",
        ],
    },
    "tandoori tofu": {
        "ingredients": [
            {"item": "firm tofu", "quantity": "120", "unit": "g"},
            {"item": "yogurt or plant yogurt", "quantity": "2", "unit": "tbsp"},
            {"item": "tandoori spice", "quantity": "1", "unit": "tsp"},
            {"item": "vegetable pulao", "quantity": "1", "unit": "cup"},
        ],
        "instructions": [
            "Marinate tofu cubes in yogurt and tandoori spice 15 minutes.",
            "Bake or air-fry at 400°F for 12–15 minutes.",
            "Serve over vegetable pulao.",
        ],
    },
    "grilled paneer salad": {
        "ingredients": [
            {"item": "paneer", "quantity": "100", "unit": "g"},
            {"item": "cooked millet", "quantity": "3/4", "unit": "cup"},
            {"item": "mixed greens", "quantity": "2", "unit": "cups"},
            {"item": "mint yogurt dressing", "quantity": "2", "unit": "tbsp"},
        ],
        "instructions": [
            "Grill or pan-sear paneer slices 2 minutes per side.",
            "Toss greens and millet with mint dressing.",
            "Top with paneer and serve.",
        ],
    },
    "roasted chana": {
        "ingredients": [
            {"item": "roasted chickpeas", "quantity": "3/4", "unit": "cup"},
            {"item": "chaat masala", "quantity": "1/4", "unit": "tsp"},
            {"item": "lemon juice", "quantity": "1/2", "unit": "tsp"},
        ],
        "instructions": [
            "Toss warm roasted chickpeas with chaat masala.",
            "Finish with lemon juice; serve as a snack.",
        ],
    },
    "sprouted moong": {
        "ingredients": [
            {"item": "sprouted moong", "quantity": "1", "unit": "cup"},
            {"item": "cucumber", "quantity": "1/2", "unit": "cup"},
            {"item": "tomato", "quantity": "1/4", "unit": "cup"},
            {"item": "lemon juice", "quantity": "1", "unit": "tsp"},
            {"item": "chaat masala", "quantity": "1/4", "unit": "tsp"},
        ],
        "instructions": [
            "Combine sprouts, cucumber, and tomato.",
            "Season with lemon and chaat masala; toss and serve chilled.",
        ],
    },
    "black bean burrito": {
        "ingredients": [
            {"item": "black beans", "quantity": "3/4", "unit": "cup"},
            {"item": "brown rice", "quantity": "3/4", "unit": "cup"},
            {"item": "salsa", "quantity": "1/4", "unit": "cup"},
            {"item": "avocado", "quantity": "1/4", "unit": "fruit"},
            {"item": "lettuce", "quantity": "1", "unit": "cup"},
        ],
        "instructions": [
            "Warm black beans with a pinch of cumin.",
            "Build bowl: rice, beans, salsa, avocado, lettuce.",
            "Squeeze lime over the top and serve.",
        ],
    },
    "huevos rancheros": {
        "ingredients": [
            {"item": "eggs", "quantity": "2", "unit": "large"},
            {"item": "corn tortillas", "quantity": "2", "unit": "pieces"},
            {"item": "black beans", "quantity": "1/2", "unit": "cup"},
            {"item": "salsa", "quantity": "1/4", "unit": "cup"},
        ],
        "instructions": [
            "Warm tortillas and heat black beans.",
            "Fry or scramble eggs.",
            "Plate tortillas, beans, eggs; top with salsa.",
        ],
    },
    "breakfast burrito": {
        "ingredients": [
            {"item": "eggs", "quantity": "2", "unit": "large"},
            {"item": "whole-wheat tortilla", "quantity": "1", "unit": "large"},
            {"item": "salsa", "quantity": "3", "unit": "tbsp"},
            {"item": "avocado", "quantity": "1/4", "unit": "fruit"},
            {"item": "black beans", "quantity": "1/3", "unit": "cup"},
        ],
        "instructions": [
            "Scramble eggs; warm tortilla and beans.",
            "Fill tortilla with eggs, beans, salsa, and avocado.",
            "Roll tightly and serve.",
        ],
    },
    "chicken fajita": {
        "ingredients": [
            {"item": "chicken breast", "quantity": "120", "unit": "g"},
            {"item": "bell peppers", "quantity": "1", "unit": "cup"},
            {"item": "onion", "quantity": "1/2", "unit": "medium"},
            {"item": "brown rice", "quantity": "3/4", "unit": "cup"},
            {"item": "fajita seasoning", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": [
            "Slice chicken; sauté with fajita seasoning until cooked.",
            "Add peppers and onion; cook until tender-crisp.",
            "Serve over brown rice.",
        ],
    },
    "fish tacos": {
        "ingredients": [
            {"item": "white fish", "quantity": "120", "unit": "g"},
            {"item": "corn tortillas", "quantity": "2", "unit": "pieces"},
            {"item": "cabbage slaw", "quantity": "1", "unit": "cup"},
            {"item": "lime", "quantity": "1/2", "unit": "fruit"},
        ],
        "instructions": [
            "Season fish; pan-sear 3–4 minutes per side.",
            "Warm tortillas; flake fish into them.",
            "Top with cabbage slaw and lime juice.",
        ],
    },
    "turkey soft tacos": {
        "ingredients": [
            {"item": "ground turkey", "quantity": "120", "unit": "g"},
            {"item": "corn tortillas", "quantity": "2", "unit": "pieces"},
            {"item": "pico de gallo", "quantity": "1/3", "unit": "cup"},
            {"item": "lettuce", "quantity": "1", "unit": "cup"},
            {"item": "cumin", "quantity": "1/2", "unit": "tsp"},
        ],
        "instructions": [
            "Brown turkey with cumin until cooked through.",
            "Warm tortillas; fill with turkey and lettuce.",
            "Top with pico de gallo and serve.",
        ],
    },
    "vegetarian enchiladas": {
        "ingredients": [
            {"item": "corn tortillas", "quantity": "2", "unit": "pieces"},
            {"item": "black beans", "quantity": "3/4", "unit": "cup"},
            {"item": "salsa verde", "quantity": "1/3", "unit": "cup"},
            {"item": "onion", "quantity": "1/4", "unit": "medium"},
            {"item": "cheese or nutritional yeast", "quantity": "2", "unit": "tbsp"},
        ],
        "instructions": [
            "Warm beans with onion; fill tortillas and roll.",
            "Place in a small baking dish; cover with salsa verde.",
            "Bake at 375°F for 12 minutes; finish with cheese or nutritional yeast.",
        ],
    },
    "guacamole with veggie": {
        "ingredients": [
            {"item": "avocado", "quantity": "1/2", "unit": "fruit"},
            {"item": "lime juice", "quantity": "1", "unit": "tsp"},
            {"item": "tomato", "quantity": "2", "unit": "tbsp"},
            {"item": "carrot/cucumber sticks", "quantity": "1", "unit": "cup"},
        ],
        "instructions": [
            "Mash avocado with lime, tomato, and a pinch of salt.",
            "Serve with fresh veggie sticks.",
        ],
    },
}


def _detail_for(meal: Dict[str, Any]) -> Dict[str, Any]:
    name = (meal.get("name") or "").lower()
    for key, detail in _CUISINE_RECIPES.items():
        if key in name:
            return detail
    protein = meal.get("primary_protein", "protein")
    return {
        "ingredients": [
            {"item": protein, "quantity": "1", "unit": "serving"},
            {"item": "vegetables", "quantity": "1", "unit": "cup"},
            {"item": "olive oil", "quantity": "1", "unit": "tsp"},
            {"item": "herbs and spices", "quantity": "to taste", "unit": ""},
        ],
        "instructions": [
            f"Gather ingredients for {meal.get('name')}.",
            "Prep produce and portion proteins.",
            f"Cook using a healthy method suited to {meal.get('cuisine_type', 'this')} cuisine.",
            "Season with herbs/spices; keep added salt moderate; plate one serving.",
        ],
    }


def professional_meal_to_recipe(meal: Dict[str, Any], recipe_id: int) -> Dict[str, Any]:
    protein = meal.get("primary_protein", "protein")
    detail = _detail_for(meal)
    return {
        "id": recipe_id,
        "name": meal["name"],
        "slug": meal["name"].lower().replace(" ", "-").replace("&", "and")[:80],
        "description": (
            f"A {meal['cuisine_type']} {meal['meal_type'][0]} featuring {protein} — "
            "built for sustainable coaching goals."
        ),
        "cuisine_type": meal["cuisine_type"],
        "meal_type": meal["meal_type"],
        "dietary_tags": meal.get("dietary_tags", []),
        "health_tags": meal.get("health_tags", []),
        "prep_time_minutes": 15,
        "cook_time_minutes": 20,
        "servings": 1,
        "difficulty": "easy",
        "image_url": "",
        "ingredients": detail["ingredients"],
        "instructions": detail["instructions"],
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
