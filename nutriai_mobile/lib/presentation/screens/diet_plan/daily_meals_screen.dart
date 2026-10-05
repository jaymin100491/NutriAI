import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/diet_plan_provider.dart';
import 'recipe_detail_screen.dart';

class DailyMealsScreen extends ConsumerWidget {
  final int day;
  final String date;
  final List<dynamic> meals;

  const DailyMealsScreen({
    super.key,
    required this.day,
    required this.date,
    required this.meals,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedDate = DateTime.parse(date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Day $day'),
            Text(
              DateFormat('EEEE, MMM dd').format(parsedDate),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: meals.isEmpty
          ? const Center(child: Text('No meals planned for this day'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDailySummary(),
                const SizedBox(height: 24),
                ...meals.map((meal) => _buildMealCard(context, ref, meal)).toList(),
              ],
            ),
    );
  }

  Widget _buildDailySummary() {
    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var meal in meals) {
      if (meal.recipe != null) {
        totalCalories += meal.recipe.nutrition.calories as int;
        totalProtein += meal.recipe.nutrition.proteinG;
        totalCarbs += meal.recipe.nutrition.carbsG;
        totalFat += meal.recipe.nutrition.fatG;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientItem('Calories', totalCalories.toString(), 'kcal', AppTheme.primaryColor),
              _buildNutrientItem('Protein', totalProtein.toStringAsFixed(1), 'g', Colors.red),
              _buildNutrientItem('Carbs', totalCarbs.toStringAsFixed(1), 'g', Colors.orange),
              _buildNutrientItem('Fat', totalFat.toStringAsFixed(1), 'g', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, WidgetRef ref, dynamic meal) {
    final recipe = meal.recipe;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: recipe != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipeId: meal.recipeId),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getMealTypeColor(meal.mealType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatMealType(meal.mealType),
                      style: TextStyle(
                        color: _getMealTypeColor(meal.mealType),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (recipe != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (recipe != null) ...[
                if (recipe.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      recipe.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRecipeInfo(Icons.local_fire_department, '${recipe.nutrition.calories} cal'),
                    const SizedBox(width: 16),
                    _buildRecipeInfo(Icons.restaurant, recipe.cuisineType),
                    const SizedBox(width: 16),
                    _buildRecipeInfo(Icons.signal_cellular_alt, recipe.difficulty),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: recipe.dietaryTags.take(3).map<Widget>((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _dislikeMeal(context, ref, meal),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text("Don't like this — swap"),
                  ),
                ),
              ] else
                Text(
                  'Recipe ID: ${meal.recipeId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dislikeMeal(BuildContext context, WidgetRef ref, dynamic meal) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dietPlanNotifierProvider.notifier).dislikeMeal(
            day: meal.day as int,
            mealType: meal.mealType as String,
          );
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Swapped with a better match for your preferences')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not swap meal: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildRecipeInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatMealType(String mealType) {
    return mealType[0].toUpperCase() + mealType.substring(1).toLowerCase();
  }
}
