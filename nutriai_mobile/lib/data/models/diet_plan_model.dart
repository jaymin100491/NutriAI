import 'package:equatable/equatable.dart';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

List<String> _asStringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

class DietPlan extends Equatable {
  final int id;
  final int userId;
  final String title;
  final String startDate;
  final String endDate;
  final int durationDays;
  final List<String> goals;
  final int targetCalories;
  final MacroTargets macroTargets;
  final List<MealPlan> meals;
  final ShoppingList shoppingList;
  final String? aiRationale;

  const DietPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.goals,
    required this.targetCalories,
    required this.macroTargets,
    required this.meals,
    required this.shoppingList,
    this.aiRationale,
  });

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    final shopping = json['shopping_list'];
    final mealsRaw = json['meals'];
    final meals = <MealPlan>[];
    if (mealsRaw is List) {
      for (final e in mealsRaw) {
        try {
          meals.add(MealPlan.fromJson(_asMap(e)));
        } catch (_) {
          // Skip malformed meal rows rather than failing the whole plan.
        }
      }
    }

    return DietPlan(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      title: _asString(json['title'], 'Weekly plan'),
      startDate: _asString(json['start_date'] ?? json['week_start']),
      endDate: _asString(json['end_date'] ?? json['week_end']),
      durationDays: _asInt(json['duration_days'], 7),
      goals: _asStringList(json['goals']),
      targetCalories: _asInt(json['target_calories'], 1800),
      macroTargets: MacroTargets.fromJson(_asMap(json['macro_targets'])),
      meals: meals,
      shoppingList: shopping is Map
          ? ShoppingList.fromJson(_asMap(shopping))
          : const ShoppingList(categories: {}),
      aiRationale: json['ai_rationale']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, userId, title, startDate, endDate];
}

class MacroTargets extends Equatable {
  final int proteinPercent;
  final int carbPercent;
  final int fatPercent;
  final int fiberGrams;

  const MacroTargets({
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
    required this.fiberGrams,
  });

  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      proteinPercent: _asInt(json['protein_percent'], 25),
      carbPercent: _asInt(json['carb_percent'], 45),
      fatPercent: _asInt(json['fat_percent'], 30),
      fiberGrams: _asInt(json['fiber_grams'], 30),
    );
  }

  @override
  List<Object?> get props => [proteinPercent, carbPercent, fatPercent, fiberGrams];
}

class MealPlan extends Equatable {
  final int day;
  final String date;
  final String mealType;
  final int recipeId;
  final Recipe? recipe;

  const MealPlan({
    required this.day,
    required this.date,
    required this.mealType,
    required this.recipeId,
    this.recipe,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    Recipe? recipe;
    if (json['recipe'] != null) {
      try {
        recipe = Recipe.fromJson(_asMap(json['recipe']));
      } catch (_) {
        recipe = null;
      }
    }
    return MealPlan(
      day: _asInt(json['day'], 1),
      date: _asString(json['date']),
      mealType: _asString(json['meal_type'], 'meal'),
      recipeId: _asInt(json['recipe_id']),
      recipe: recipe,
    );
  }

  @override
  List<Object?> get props => [day, date, mealType, recipeId];
}

class Recipe extends Equatable {
  final int id;
  final String name;
  final String description;
  final String cuisineType;
  final List<String> mealType;
  final List<String> dietaryTags;
  final List<String> healthTags;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty;
  final String imageUrl;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final Nutrition nutrition;

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisineType,
    required this.mealType,
    required this.dietaryTags,
    required this.healthTags,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.nutrition,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'];
    final ingredients = <Ingredient>[];
    if (ingredientsRaw is List) {
      for (final e in ingredientsRaw) {
        try {
          ingredients.add(Ingredient.fromJson(_asMap(e)));
        } catch (_) {}
      }
    }

    return Recipe(
      id: _asInt(json['id']),
      name: _asString(json['name'], 'Recipe'),
      description: _asString(json['description']),
      cuisineType: _asString(json['cuisine_type'], 'American'),
      mealType: _asStringList(json['meal_type']),
      dietaryTags: _asStringList(json['dietary_tags']),
      healthTags: _asStringList(json['health_tags']),
      prepTimeMinutes: _asInt(json['prep_time_minutes'], 15),
      cookTimeMinutes: _asInt(json['cook_time_minutes'], 20),
      servings: _asInt(json['servings'], 1),
      difficulty: _asString(json['difficulty'], 'easy'),
      imageUrl: _asString(json['image_url']),
      ingredients: ingredients,
      instructions: _asStringList(json['instructions']),
      nutrition: Nutrition.fromJson(_asMap(json['nutrition'])),
    );
  }

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  @override
  List<Object?> get props => [id, name, cuisineType];
}

class Ingredient extends Equatable {
  final String item;
  final String quantity;
  final String unit;
  final String? notes;

  const Ingredient({
    required this.item,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      item: _asString(json['item'], 'Ingredient'),
      quantity: _asString(json['quantity'], '1'),
      unit: _asString(json['unit']),
      notes: json['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [item, quantity, unit];
}

class Nutrition extends Equatable {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final int sodiumMg;
  final int cholesterolMg;

  const Nutrition({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
    required this.cholesterolMg,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: _asInt(json['calories']),
      proteinG: _asDouble(json['protein_g']),
      carbsG: _asDouble(json['carbs_g']),
      fatG: _asDouble(json['fat_g']),
      fiberG: _asDouble(json['fiber_g']),
      sugarG: _asDouble(json['sugar_g']),
      sodiumMg: _asInt(json['sodium_mg']),
      cholesterolMg: _asInt(json['cholesterol_mg']),
    );
  }

  @override
  List<Object?> get props => [calories, proteinG, carbsG, fatG];
}

class ShoppingList extends Equatable {
  final Map<String, List<ShoppingItem>> categories;

  const ShoppingList({required this.categories});

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final Map<String, List<ShoppingItem>> categories = {};
    json.forEach((key, value) {
      if (value is! List) {
        categories[key] = const [];
        return;
      }
      categories[key] = value
          .map((e) {
            try {
              return ShoppingItem.fromJson(_asMap(e));
            } catch (_) {
              return ShoppingItem(item: e.toString(), quantity: '');
            }
          })
          .toList();
    });
    return ShoppingList(categories: categories);
  }

  @override
  List<Object?> get props => [categories];
}

class ShoppingItem extends Equatable {
  final String item;
  final String quantity;

  const ShoppingItem({
    required this.item,
    required this.quantity,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      item: _asString(json['item'], 'Item'),
      quantity: _asString(json['quantity']),
    );
  }

  @override
  List<Object?> get props => [item, quantity];
}
