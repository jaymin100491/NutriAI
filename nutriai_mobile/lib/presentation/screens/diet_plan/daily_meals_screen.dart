import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/diet_plan_model.dart';
import '../../providers/diet_plan_provider.dart';
import '../../widgets/craft/craft.dart';
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE').format(parsedDate),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              DateFormat('MMM d · Day $day').format(parsedDate),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
      body: meals.isEmpty
          ? const CraftEmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'No meals this day',
              body: 'Rebuild the week from Plan, or ask Coach to fill this day.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _buildDailySummary().craftIn(),
                const SizedBox(height: 18),
                CraftSectionHeader(
                  title: 'Meals',
                  subtitle: '${meals.length} plated for this day',
                ).craftIn(delayMs: 40),
                const SizedBox(height: 12),
                ...meals.asMap().entries.map(
                      (e) => _buildMealCard(context, ref, e.value).craftIn(delayMs: 70 + e.key * 40),
                    ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily nutrition',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Nutrient(label: 'Calories', value: '$totalCalories', unit: 'kcal', color: AppTheme.primaryColor)),
              Expanded(child: _Nutrient(label: 'Protein', value: totalProtein.toStringAsFixed(0), unit: 'g', color: AppTheme.accentColor)),
              Expanded(child: _Nutrient(label: 'Carbs', value: totalCarbs.toStringAsFixed(0), unit: 'g', color: const Color(0xFFC47A1A))),
              Expanded(child: _Nutrient(label: 'Fat', value: totalFat.toStringAsFixed(0), unit: 'g', color: const Color(0xFF1B4F72))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, WidgetRef ref, dynamic meal) {
    final recipe = meal.recipe;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: recipe != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: meal.recipeId,
                      initialRecipe: recipe is Recipe ? recipe : null,
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatMealType(meal.mealType),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (recipe != null)
                    Text(
                      '${recipe.totalTimeMinutes} min · ${recipe.nutrition.calories} kcal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (recipe != null) ...[
                if (recipe.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      recipe.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.chipBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.restaurant, size: 40, color: AppTheme.primaryColor),
                        );
                      },
                    ),
                  ),
                if (recipe.imageUrl.isNotEmpty) const SizedBox(height: 12),
                Text(
                  recipe.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  recipe.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ProvenanceChip(label: recipe.cuisineType, icon: Icons.public),
                    ProvenanceChip(label: recipe.difficulty, icon: Icons.signal_cellular_alt),
                    ...recipe.dietaryTags.take(2).map<Widget>(
                          (tag) => ProvenanceChip(label: tag.toString()),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _dislikeMeal(context, ref, meal),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Swap meal'),
                  ),
                ),
              ] else
                Text(
                  'Recipe unavailable',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor),
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
        SnackBar(content: Text('Could not swap meal: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  String _formatMealType(String mealType) {
    return mealType[0].toUpperCase() + mealType.substring(1).toLowerCase();
  }
}

class _Nutrient extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _Nutrient({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          unit,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }
}
