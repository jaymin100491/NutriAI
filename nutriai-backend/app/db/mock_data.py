"""
Mock data for the NutriAI application.
This will be replaced with real database queries later.
"""
from datetime import date, datetime, timedelta
import random

# Mock Users
MOCK_USERS = [
    {
        "id": 1,
        "email": "1@1.com",
        "first_name": "Test",
        "last_name": "User",
        "date_of_birth": "1985-03-15",
        "gender": "male",
        "height_inches": 70,
        "current_weight_lbs": 182,
        "subscription_tier": "premium",
        "dietary_preference": "omnivore",
        "allergies": [],
        "medical_conditions": ["high_cholesterol"],
        "created_at": "2026-01-15T10:00:00Z"
    },
    {
        "id": 2,
        "email": "john.doe@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "date_of_birth": "1985-03-15",
        "gender": "male",
        "height_inches": 70,
        "current_weight_lbs": 185,
        "subscription_tier": "premium",
        "dietary_preference": "omnivore",
        "allergies": ["peanuts"],
        "medical_conditions": ["high_cholesterol"],
        "created_at": "2026-01-15T10:00:00Z"
    },
    {
        "id": 3,
        "email": "sarah.smith@example.com",
        "first_name": "Sarah",
        "last_name": "Smith",
        "date_of_birth": "1990-07-22",
        "gender": "female",
        "height_inches": 65,
        "current_weight_lbs": 145,
        "subscription_tier": "basic",
        "dietary_preference": "vegetarian",
        "allergies": [],
        "medical_conditions": ["pre_diabetes"],
        "created_at": "2026-02-01T14:30:00Z"
    },
    {
        "id": 4,
        "email": "mike.johnson@example.com",
        "first_name": "Mike",
        "last_name": "Johnson",
        "date_of_birth": "1978-11-08",
        "gender": "male",
        "height_inches": 72,
        "current_weight_lbs": 220,
        "subscription_tier": "professional",
        "dietary_preference": "omnivore",
        "allergies": ["shellfish"],
        "medical_conditions": ["hypertension", "high_cholesterol"],
        "created_at": "2026-01-20T09:15:00Z"
    }
]

# Mock Lab Results
MOCK_LAB_RESULTS = [
    {
        "id": 1,
        "user_id": 1,
        "test_date": "2026-03-01",
        "results": {
            "tests": [
                {
                    "name": "LDL Cholesterol",
                    "value": 160,
                    "unit": "mg/dL",
                    "reference_range": "<100",
                    "status": "high",
                    "category": "Lipid Panel"
                },
                {
                    "name": "HDL Cholesterol",
                    "value": 45,
                    "unit": "mg/dL",
                    "reference_range": ">40",
                    "status": "normal",
                    "category": "Lipid Panel"
                },
                {
                    "name": "Triglycerides",
                    "value": 175,
                    "unit": "mg/dL",
                    "reference_range": "<150",
                    "status": "high",
                    "category": "Lipid Panel"
                },
                {
                    "name": "Glucose (Fasting)",
                    "value": 98,
                    "unit": "mg/dL",
                    "reference_range": "70-100",
                    "status": "normal",
                    "category": "Metabolic Panel"
                }
            ]
        },
        "interpretation": {
            "summary": "Your cholesterol levels show room for improvement with LDL at 160 mg/dL (target <100).",
            "concerns": ["Elevated LDL cholesterol", "Borderline high triglycerides"],
            "recommendations": [
                "Reduce saturated fat intake to <7% of daily calories",
                "Increase soluble fiber (oats, beans, apples)",
                "Add omega-3 rich foods (fatty fish, walnuts)",
                "Increase physical activity to 150 min/week"
            ]
        }
    },
    {
        "id": 2,
        "user_id": 2,
        "test_date": "2026-02-15",
        "results": {
            "tests": [
                {
                    "name": "Glucose (Fasting)",
                    "value": 110,
                    "unit": "mg/dL",
                    "reference_range": "70-100",
                    "status": "high",
                    "category": "Metabolic Panel"
                },
                {
                    "name": "HbA1c",
                    "value": 6.2,
                    "unit": "%",
                    "reference_range": "<5.7",
                    "status": "high",
                    "category": "Diabetes Screening"
                },
                {
                    "name": "Vitamin D",
                    "value": 22,
                    "unit": "ng/mL",
                    "reference_range": "30-100",
                    "status": "low",
                    "category": "Vitamins"
                }
            ]
        },
        "interpretation": {
            "summary": "Pre-diabetic range detected. Blood sugar control is essential.",
            "concerns": ["Elevated fasting glucose", "HbA1c in pre-diabetic range", "Low Vitamin D"],
            "recommendations": [
                "Focus on low glycemic index foods",
                "Limit refined carbohydrates and sugars",
                "Increase fiber intake to 30g per day",
                "Add Vitamin D rich foods or supplementation"
            ]
        }
    }
]

# Mock Recipes
MOCK_RECIPES = [
    {
        "id": 1,
        "name": "Grilled Salmon with Quinoa and Roasted Vegetables",
        "slug": "grilled-salmon-quinoa-vegetables",
        "description": "Heart-healthy omega-3 rich salmon with protein-packed quinoa and colorful roasted vegetables",
        "cuisine_type": "Mediterranean",
        "meal_type": ["dinner", "lunch"],
        "dietary_tags": ["gluten-free", "dairy-free", "pescatarian"],
        "health_tags": ["heart-healthy", "high-protein", "anti-inflammatory"],
        "prep_time_minutes": 15,
        "cook_time_minutes": 30,
        "servings": 4,
        "difficulty": "medium",
        "image_url": "https://images.unsplash.com/photo-1467003909585-2f8a72700288",
        "ingredients": [
            {"item": "Salmon fillets", "quantity": "4", "unit": "pieces", "notes": "6 oz each"},
            {"item": "Quinoa", "quantity": "1.5", "unit": "cups", "notes": "uncooked"},
            {"item": "Broccoli florets", "quantity": "2", "unit": "cups"},
            {"item": "Bell peppers", "quantity": "2", "unit": "pieces", "notes": "mixed colors, sliced"},
            {"item": "Olive oil", "quantity": "3", "unit": "tbsp"},
            {"item": "Lemon", "quantity": "2", "unit": "pieces"},
            {"item": "Garlic", "quantity": "3", "unit": "cloves", "notes": "minced"},
            {"item": "Salt and pepper", "quantity": "to taste", "unit": ""}
        ],
        "instructions": [
            "Preheat oven to 425°F (220°C).",
            "Cook quinoa according to package directions.",
            "Toss broccoli and bell peppers with 2 tbsp olive oil, salt, and pepper. Roast for 20 minutes.",
            "Season salmon with salt, pepper, and minced garlic.",
            "Heat 1 tbsp olive oil in a pan over medium-high heat.",
            "Sear salmon skin-side down for 4-5 minutes, flip and cook for 3-4 minutes more.",
            "Serve salmon over quinoa with roasted vegetables. Garnish with lemon wedges."
        ],
        "nutrition": {
            "calories": 450,
            "protein_g": 38,
            "carbs_g": 42,
            "fat_g": 16,
            "fiber_g": 8,
            "sugar_g": 6,
            "sodium_mg": 420,
            "cholesterol_mg": 75
        }
    },
    {
        "id": 2,
        "name": "Greek Yogurt Parfait with Berries and Granola",
        "slug": "greek-yogurt-parfait-berries-granola",
        "description": "Protein-rich breakfast with antioxidant berries and crunchy homemade granola",
        "cuisine_type": "American",
        "meal_type": ["breakfast", "snack"],
        "dietary_tags": ["vegetarian", "gluten-free-option"],
        "health_tags": ["high-protein", "probiotic", "antioxidant-rich"],
        "prep_time_minutes": 10,
        "cook_time_minutes": 0,
        "servings": 2,
        "difficulty": "easy",
        "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777",
        "ingredients": [
            {"item": "Greek yogurt", "quantity": "2", "unit": "cups", "notes": "plain, non-fat"},
            {"item": "Mixed berries", "quantity": "1.5", "unit": "cups", "notes": "strawberries, blueberries, raspberries"},
            {"item": "Granola", "quantity": "0.5", "unit": "cup", "notes": "low-sugar"},
            {"item": "Honey", "quantity": "2", "unit": "tbsp"},
            {"item": "Chia seeds", "quantity": "1", "unit": "tbsp"},
            {"item": "Almonds", "quantity": "2", "unit": "tbsp", "notes": "sliced"}
        ],
        "instructions": [
            "In a glass or bowl, layer 1/2 cup Greek yogurt.",
            "Add a layer of mixed berries (about 1/2 cup).",
            "Sprinkle 2 tbsp granola.",
            "Repeat layers.",
            "Top with remaining berries, chia seeds, and sliced almonds.",
            "Drizzle with honey before serving."
        ],
        "nutrition": {
            "calories": 320,
            "protein_g": 22,
            "carbs_g": 45,
            "fat_g": 7,
            "fiber_g": 6,
            "sugar_g": 28,
            "sodium_mg": 85,
            "cholesterol_mg": 10
        }
    },
    {
        "id": 3,
        "name": "Mediterranean Chickpea Salad",
        "slug": "mediterranean-chickpea-salad",
        "description": "Fiber-rich plant-based salad with fresh vegetables and tangy lemon dressing",
        "cuisine_type": "Mediterranean",
        "meal_type": ["lunch", "dinner", "side"],
        "dietary_tags": ["vegan", "gluten-free", "dairy-free"],
        "health_tags": ["high-fiber", "plant-based", "heart-healthy"],
        "prep_time_minutes": 15,
        "cook_time_minutes": 0,
        "servings": 4,
        "difficulty": "easy",
        "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd",
        "ingredients": [
            {"item": "Chickpeas", "quantity": "2", "unit": "cans", "notes": "15 oz each, drained and rinsed"},
            {"item": "Cherry tomatoes", "quantity": "2", "unit": "cups", "notes": "halved"},
            {"item": "Cucumber", "quantity": "1", "unit": "large", "notes": "diced"},
            {"item": "Red onion", "quantity": "0.5", "unit": "cup", "notes": "finely chopped"},
            {"item": "Kalamata olives", "quantity": "0.5", "unit": "cup", "notes": "pitted and halved"},
            {"item": "Fresh parsley", "quantity": "0.25", "unit": "cup", "notes": "chopped"},
            {"item": "Lemon juice", "quantity": "3", "unit": "tbsp", "notes": "fresh"},
            {"item": "Olive oil", "quantity": "3", "unit": "tbsp"},
            {"item": "Garlic", "quantity": "2", "unit": "cloves", "notes": "minced"},
            {"item": "Salt and pepper", "quantity": "to taste", "unit": ""}
        ],
        "instructions": [
            "In a large bowl, combine chickpeas, tomatoes, cucumber, red onion, olives, and parsley.",
            "In a small bowl, whisk together lemon juice, olive oil, garlic, salt, and pepper.",
            "Pour dressing over salad and toss well to combine.",
            "Refrigerate for at least 30 minutes to allow flavors to meld.",
            "Serve chilled or at room temperature."
        ],
        "nutrition": {
            "calories": 280,
            "protein_g": 10,
            "carbs_g": 35,
            "fat_g": 12,
            "fiber_g": 10,
            "sugar_g": 6,
            "sodium_mg": 380,
            "cholesterol_mg": 0
        }
    },
    {
        "id": 4,
        "name": "Oatmeal with Walnuts and Cinnamon",
        "slug": "oatmeal-walnuts-cinnamon",
        "description": "Cholesterol-lowering steel-cut oats with heart-healthy walnuts",
        "cuisine_type": "American",
        "meal_type": ["breakfast"],
        "dietary_tags": ["vegan", "dairy-free"],
        "health_tags": ["heart-healthy", "cholesterol-lowering", "high-fiber"],
        "prep_time_minutes": 5,
        "cook_time_minutes": 20,
        "servings": 2,
        "difficulty": "easy",
        "image_url": "https://images.unsplash.com/photo-1517673132405-a56a62b18caf",
        "ingredients": [
            {"item": "Steel-cut oats", "quantity": "1", "unit": "cup"},
            {"item": "Water", "quantity": "3", "unit": "cups"},
            {"item": "Walnuts", "quantity": "0.25", "unit": "cup", "notes": "chopped"},
            {"item": "Ground cinnamon", "quantity": "1", "unit": "tsp"},
            {"item": "Banana", "quantity": "1", "unit": "medium", "notes": "sliced"},
            {"item": "Maple syrup", "quantity": "2", "unit": "tbsp"},
            {"item": "Salt", "quantity": "1", "unit": "pinch"}
        ],
        "instructions": [
            "Bring water to a boil in a medium saucepan.",
            "Add oats and a pinch of salt, reduce heat to low.",
            "Simmer for 20-25 minutes, stirring occasionally, until oats are tender.",
            "Stir in cinnamon.",
            "Divide oatmeal between two bowls.",
            "Top each bowl with walnuts, banana slices, and drizzle with maple syrup.",
            "Serve hot."
        ],
        "nutrition": {
            "calories": 340,
            "protein_g": 10,
            "carbs_g": 52,
            "fat_g": 12,
            "fiber_g": 8,
            "sugar_g": 16,
            "sodium_mg": 150,
            "cholesterol_mg": 0
        }
    },
    {
        "id": 5,
        "name": "Grilled Chicken with Roasted Sweet Potato and Green Beans",
        "slug": "grilled-chicken-sweet-potato-green-beans",
        "description": "Lean protein with complex carbs and nutrient-dense vegetables",
        "cuisine_type": "American",
        "meal_type": ["dinner", "lunch"],
        "dietary_tags": ["gluten-free", "dairy-free"],
        "health_tags": ["high-protein", "balanced-meal", "nutrient-dense"],
        "prep_time_minutes": 15,
        "cook_time_minutes": 35,
        "servings": 4,
        "difficulty": "medium",
        "image_url": "https://images.unsplash.com/photo-1532550907401-a500c9a57435",
        "ingredients": [
            {"item": "Chicken breasts", "quantity": "4", "unit": "pieces", "notes": "6 oz each"},
            {"item": "Sweet potatoes", "quantity": "2", "unit": "large", "notes": "cubed"},
            {"item": "Green beans", "quantity": "1", "unit": "lb", "notes": "trimmed"},
            {"item": "Olive oil", "quantity": "4", "unit": "tbsp"},
            {"item": "Garlic powder", "quantity": "2", "unit": "tsp"},
            {"item": "Paprika", "quantity": "1", "unit": "tsp"},
            {"item": "Fresh rosemary", "quantity": "2", "unit": "tbsp", "notes": "chopped"},
            {"item": "Salt and pepper", "quantity": "to taste", "unit": ""}
        ],
        "instructions": [
            "Preheat oven to 400°F (200°C).",
            "Toss sweet potato cubes with 2 tbsp olive oil, salt, pepper, and rosemary. Roast for 25-30 minutes.",
            "Season chicken breasts with garlic powder, paprika, salt, and pepper.",
            "Heat 1 tbsp olive oil in a grill pan over medium-high heat.",
            "Grill chicken for 6-7 minutes per side until cooked through (internal temp 165°F).",
            "In the last 10 minutes, toss green beans with 1 tbsp olive oil and roast alongside sweet potatoes.",
            "Serve chicken with roasted sweet potatoes and green beans."
        ],
        "nutrition": {
            "calories": 420,
            "protein_g": 42,
            "carbs_g": 35,
            "fat_g": 12,
            "fiber_g": 7,
            "sugar_g": 8,
            "sodium_mg": 480,
            "cholesterol_mg": 110
        }
    },
    {
        "id": 6,
        "name": "Avocado Toast with Poached Egg",
        "slug": "avocado-toast-poached-egg",
        "description": "Healthy fats and protein-rich breakfast on whole grain toast",
        "cuisine_type": "American",
        "meal_type": ["breakfast", "brunch"],
        "dietary_tags": ["vegetarian"],
        "health_tags": ["high-protein", "heart-healthy"],
        "prep_time_minutes": 5,
        "cook_time_minutes": 10,
        "servings": 2,
        "difficulty": "easy",
        "image_url": "https://images.unsplash.com/photo-1541519227354-08fa5d50c44d",
        "ingredients": [
            {"item": "Whole grain bread", "quantity": "4", "unit": "slices"},
            {"item": "Avocado", "quantity": "2", "unit": "medium", "notes": "ripe"},
            {"item": "Eggs", "quantity": "4", "unit": "large"},
            {"item": "Cherry tomatoes", "quantity": "1", "unit": "cup", "notes": "halved"},
            {"item": "Lemon juice", "quantity": "1", "unit": "tbsp"},
            {"item": "Red pepper flakes", "quantity": "0.5", "unit": "tsp"},
            {"item": "Salt and black pepper", "quantity": "to taste", "unit": ""}
        ],
        "instructions": [
            "Toast bread slices until golden brown.",
            "Mash avocados with lemon juice, salt, and pepper.",
            "Bring a pot of water to a gentle simmer, add a splash of vinegar.",
            "Crack each egg into a small bowl, then slide into simmering water.",
            "Poach eggs for 3-4 minutes until whites are set but yolks are runny.",
            "Spread mashed avocado on toasted bread.",
            "Top each toast with a poached egg and cherry tomatoes.",
            "Sprinkle with red pepper flakes, salt, and pepper."
        ],
        "nutrition": {
            "calories": 380,
            "protein_g": 18,
            "carbs_g": 32,
            "fat_g": 22,
            "fiber_g": 10,
            "sugar_g": 4,
            "sodium_mg": 320,
            "cholesterol_mg": 375
        }
    }
]

# Mock Diet Plans
def generate_mock_diet_plan(user_id: int):
    """Generate a mock 7-day diet plan."""
    base_date = date.today()
    meals = []

    for day in range(7):
        day_date = base_date + timedelta(days=day)
        meals.extend([
            {
                "day": day + 1,
                "date": day_date.isoformat(),
                "meal_type": "breakfast",
                "recipe_id": random.choice([2, 4]),
                "recipe": next((r for r in MOCK_RECIPES if r["id"] in [2, 4]), None)
            },
            {
                "day": day + 1,
                "date": day_date.isoformat(),
                "meal_type": "lunch",
                "recipe_id": random.choice([3, 5]),
                "recipe": next((r for r in MOCK_RECIPES if r["id"] in [3, 5]), None)
            },
            {
                "day": day + 1,
                "date": day_date.isoformat(),
                "meal_type": "dinner",
                "recipe_id": random.choice([1, 5]),
                "recipe": next((r for r in MOCK_RECIPES if r["id"] in [1, 5]), None)
            },
            {
                "day": day + 1,
                "date": day_date.isoformat(),
                "meal_type": "snack",
                "recipe_id": 2,
                "recipe": next((r for r in MOCK_RECIPES if r["id"] == 2), None)
            }
        ])

    return {
        "id": 1,
        "user_id": user_id,
        "title": "Heart-Healthy 7-Day Plan",
        "start_date": base_date.isoformat(),
        "end_date": (base_date + timedelta(days=6)).isoformat(),
        "duration_days": 7,
        "goals": ["lower_cholesterol", "weight_loss"],
        "target_calories": 1800,
        "macro_targets": {
            "protein_percent": 25,
            "carb_percent": 45,
            "fat_percent": 30,
            "fiber_grams": 30
        },
        "meals": meals,
        "shopping_list": {
            "produce": [
                {"item": "Spinach", "quantity": "2 bunches"},
                {"item": "Broccoli", "quantity": "2 heads"},
                {"item": "Bell peppers", "quantity": "4 pieces"},
                {"item": "Cherry tomatoes", "quantity": "2 pints"},
                {"item": "Cucumber", "quantity": "2 large"},
                {"item": "Sweet potatoes", "quantity": "4 large"},
                {"item": "Green beans", "quantity": "2 lbs"},
                {"item": "Mixed berries", "quantity": "2 containers"},
                {"item": "Bananas", "quantity": "4 pieces"},
                {"item": "Lemons", "quantity": "6 pieces"}
            ],
            "protein": [
                {"item": "Salmon fillets", "quantity": "1.5 lbs"},
                {"item": "Chicken breasts", "quantity": "2 lbs"},
                {"item": "Greek yogurt", "quantity": "32 oz"},
                {"item": "Chickpeas", "quantity": "4 cans"}
            ],
            "grains": [
                {"item": "Quinoa", "quantity": "1 lb"},
                {"item": "Steel-cut oats", "quantity": "1 container"}
            ],
            "pantry": [
                {"item": "Olive oil", "quantity": "1 bottle"},
                {"item": "Walnuts", "quantity": "8 oz"},
                {"item": "Almonds", "quantity": "8 oz"},
                {"item": "Granola", "quantity": "1 bag"},
                {"item": "Honey", "quantity": "1 bottle"}
            ]
        }
    }

# Mock Daily Tracking
def generate_mock_tracking(user_id: int, days: int = 30):
    """Generate mock daily tracking data."""
    tracking_data = []
    base_date = date.today() - timedelta(days=days)
    base_weight = 185 if user_id == 1 else 145

    for day in range(days):
        tracking_date = base_date + timedelta(days=day)
        # Simulate gradual weight loss
        weight = base_weight - (day * 0.1)

        tracking_data.append({
            "id": day + 1,
            "user_id": user_id,
            "date": tracking_date.isoformat(),
            "weight_lbs": round(weight, 1),
            "systolic_bp": random.randint(118, 135),
            "diastolic_bp": random.randint(75, 88),
            "water_intake_oz": random.randint(48, 80),
            "sleep_hours": round(random.uniform(6.0, 8.5), 1),
            "mood": random.choice(["great", "good", "okay"]),
            "adherence_percent": random.randint(70, 100)
        })

    return tracking_data

# Mock User Goals
MOCK_USER_GOALS = [
    {
        "id": 1,
        "user_id": 1,
        "goal_type": "lower_cholesterol",
        "target_value": 100,
        "current_value": 160,
        "unit": "mg/dL",
        "status": "active",
        "priority": 1
    },
    {
        "id": 2,
        "user_id": 1,
        "goal_type": "weight_loss",
        "target_value": 170,
        "current_value": 185,
        "unit": "lbs",
        "status": "active",
        "priority": 2
    },
    {
        "id": 3,
        "user_id": 2,
        "goal_type": "manage_diabetes",
        "target_value": 5.7,
        "current_value": 6.2,
        "unit": "% HbA1c",
        "status": "active",
        "priority": 1
    }
]
