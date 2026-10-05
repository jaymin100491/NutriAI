import 'package:equatable/equatable.dart';

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
    return DietPlan(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      durationDays: json['duration_days'] as int,
      goals: (json['goals'] as List<dynamic>).map((e) => e.toString()).toList(),
      targetCalories: json['target_calories'] as int,
      macroTargets: MacroTargets.fromJson(json['macro_targets'] as Map<String, dynamic>),
      meals: (json['meals'] as List<dynamic>)
          .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      shoppingList: ShoppingList.fromJson(json['shopping_list'] as Map<String, dynamic>),
      aiRationale: json['ai_rationale'] as String?,
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
      proteinPercent: json['protein_percent'] as int,
      carbPercent: json['carb_percent'] as int,
      fatPercent: json['fat_percent'] as int,
      fiberGrams: json['fiber_grams'] as int,
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
    return MealPlan(
      day: json['day'] as int,
      date: json['date'] as String,
      mealType: json['meal_type'] as String,
      recipeId: json['recipe_id'] as int,
      recipe: json['recipe'] != null ? Recipe.fromJson(json['recipe'] as Map<String, dynamic>) : null,
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
    return Recipe(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      cuisineType: json['cuisine_type'] as String,
      mealType: (json['meal_type'] as List<dynamic>).map((e) => e.toString()).toList(),
      dietaryTags: (json['dietary_tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      healthTags: (json['health_tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      prepTimeMinutes: json['prep_time_minutes'] as int,
      cookTimeMinutes: json['cook_time_minutes'] as int,
      servings: json['servings'] as int,
      difficulty: json['difficulty'] as String,
      imageUrl: json['image_url'] as String,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      instructions: (json['instructions'] as List<dynamic>).map((e) => e.toString()).toList(),
      nutrition: Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
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
      item: json['item'] as String,
      quantity: json['quantity'] as String,
      unit: json['unit'] as String,
      notes: json['notes'] as String?,
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
      calories: json['calories'] as int,
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num).toDouble(),
      sugarG: (json['sugar_g'] as num).toDouble(),
      sodiumMg: json['sodium_mg'] as int,
      cholesterolMg: json['cholesterol_mg'] as int,
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
      categories[key] = (value as List<dynamic>)
          .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
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
      item: json['item'] as String,
      quantity: json['quantity'] as String,
    );
  }

  @override
  List<Object?> get props => [item, quantity];
}
