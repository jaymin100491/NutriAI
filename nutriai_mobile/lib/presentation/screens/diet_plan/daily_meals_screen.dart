import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/diet_plan_model.dart';
import '../../providers/diet_plan_provider.dart';
import '../../widgets/craft/craft.dart';
import 'recipe_detail_screen.dart';

class DailyMealsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<DailyMealsScreen> createState() => _DailyMealsScreenState();
}

class _DailyMealsScreenState extends ConsumerState<DailyMealsScreen> {
  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

  /// meal_type → done | skipped
  Map<String, String> _statusByMeal = {};
  bool _loadingStatus = true;
  String? _savingMealType;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStatuses);
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await ref
          .read(dietPlanNotifierProvider.notifier)
          .getMealAdherenceStatuses(date: widget.date);
      if (!mounted) return;
      setState(() {
        _statusByMeal = statuses;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStatus = false);
    }
  }

  List<dynamic> get _orderedMeals {
    final copy = List<dynamic>.from(widget.meals);
    copy.sort((a, b) {
      final ai = _mealOrder.indexOf((a.mealType as String?)?.toLowerCase() ?? '');
      final bi = _mealOrder.indexOf((b.mealType as String?)?.toLowerCase() ?? '');
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.parse(widget.date);
    final ordered = _orderedMeals;

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
              DateFormat('MMM d · Day ${widget.day}').format(parsedDate),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
      body: ordered.isEmpty
          ? const CraftEmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'No meals this day',
              body: 'Rebuild the week from Plan, or ask Coach to fill this day.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _buildDailySummary(ordered).craftIn(),
                const SizedBox(height: 18),
                CraftSectionHeader(
                  title: 'Meals',
                  subtitle: _statusSubtitle(ordered.length),
                ).craftIn(delayMs: 40),
                const SizedBox(height: 12),
                if (_loadingStatus)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  ...ordered.asMap().entries.map(
                        (e) => _buildMealCard(e.value).craftIn(delayMs: 70 + e.key * 40),
                      ),
              ],
            ),
    );
  }

  String _statusSubtitle(int mealCount) {
    final done = _statusByMeal.values.where((s) => s == 'done').length;
    final skipped = _statusByMeal.values.where((s) => s == 'skipped').length;
    if (done == 0 && skipped == 0) {
      return '$mealCount plated · breakfast → snack';
    }
    return '$done done · $skipped skipped · $mealCount plated';
  }

  Widget _buildDailySummary(List<dynamic> ordered) {
    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var meal in ordered) {
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

  Widget _buildMealCard(dynamic meal) {
    final recipe = meal.recipe;
    final mealType = (meal.mealType as String?)?.toLowerCase() ?? '';
    final status = _statusByMeal[mealType];
    final saving = _savingMealType == mealType;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == 'done'
              ? AppTheme.successColor.withValues(alpha: 0.45)
              : status == 'skipped'
                  ? AppTheme.warningColor.withValues(alpha: 0.45)
                  : AppTheme.borderSubtle,
          width: status != null ? 1.5 : 1,
        ),
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
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    _StatusBadge(status: status),
                  ],
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
                if (saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else
                  Row(
                    children: [
                      _AdherenceButton(
                        label: 'Done',
                        icon: Icons.check_circle_outline,
                        selected: status == 'done',
                        selectedColor: AppTheme.successColor,
                        onPressed: () => _logAdherence(meal, 'done'),
                      ),
                      _AdherenceButton(
                        label: 'Skipped',
                        icon: Icons.skip_next_rounded,
                        selected: status == 'skipped',
                        selectedColor: AppTheme.warningColor,
                        onPressed: () => _logAdherence(meal, 'skipped'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _dislikeMeal(meal),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Swap'),
                      ),
                    ],
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

  Future<void> _logAdherence(dynamic meal, String status) async {
    final mealType = (meal.mealType as String?)?.toLowerCase() ?? '';
    // Tapping the same status again is a no-op visually (already logged)
    if (_statusByMeal[mealType] == status) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'done' ? 'Already marked done' : 'Already marked skipped',
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingMealType = mealType);
    try {
      final result = await ref.read(dietPlanNotifierProvider.notifier).logMealAdherence(
            day: meal.day as int,
            mealType: meal.mealType as String,
            status: status,
            recipeName: meal.recipe?.name as String?,
            date: meal.date as String?,
          );
      if (!mounted) return;
      setState(() {
        _statusByMeal = {..._statusByMeal, mealType: status};
        _savingMealType = null;
      });
      final msg = result['message']?.toString() ??
          (status == 'done' ? 'Logged as done' : 'Logged as skipped');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingMealType = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not log meal: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _dislikeMeal(dynamic meal) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dietPlanNotifierProvider.notifier).dislikeMeal(
            day: meal.day as int,
            mealType: meal.mealType as String,
          );
      if (mounted) {
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final done = status == 'done';
    final color = done ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.skip_next_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            done ? 'Done' : 'Skipped',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  const _AdherenceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: selectedColor,
            backgroundColor: selectedColor.withValues(alpha: 0.12),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
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
