import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/diet_plan_model.dart';
import '../../providers/diet_plan_provider.dart';
import '../../widgets/craft/craft.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final int recipeId;
  final Recipe? initialRecipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.initialRecipe,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _cooking = false;
  int _step = 0;
  final Set<int> _checkedIngredients = {};

  void _openCooking(Recipe recipe) {
    final steps = recipe.instructions;
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cooking steps available for this recipe.')),
      );
      return;
    }
    setState(() {
      _cooking = true;
      _step = 0;
    });
  }

  Recipe? _resolve(AsyncValue<Recipe?> recipeAsync) {
    return recipeAsync.valueOrNull ?? widget.initialRecipe;
  }

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final recipe = _resolve(recipeAsync);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _cooking ? 'Cook mode' : (recipe?.name ?? 'Recipe'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_cooking) {
              setState(() => _cooking = false);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: recipeAsync.when(
        data: (_) {
          if (recipe == null) {
            return CraftEmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'Recipe not found',
              body: 'This meal may have been generated for your plan. Go back and open it from Plan.',
              ctaLabel: 'Go back',
              onCta: () => Navigator.of(context).maybePop(),
            );
          }
          if (_cooking) {
            return _CookingMode(
              recipe: recipe,
              step: _step,
              checkedIngredients: _checkedIngredients,
              onToggleIngredient: (i) => setState(() {
                if (_checkedIngredients.contains(i)) {
                  _checkedIngredients.remove(i);
                } else {
                  _checkedIngredients.add(i);
                }
              }),
              onStep: (s) => setState(() => _step = s),
              onExit: () => setState(() => _cooking = false),
            );
          }
          return _RecipeBody(
            recipe: recipe,
            checkedIngredients: _checkedIngredients,
            onToggleIngredient: (i) => setState(() {
              if (_checkedIngredients.contains(i)) {
                _checkedIngredients.remove(i);
              } else {
                _checkedIngredients.add(i);
              }
            }),
            onStartCooking: () => _openCooking(recipe),
          );
        },
        loading: () {
          if (recipe != null) {
            return _RecipeBody(
              recipe: recipe,
              checkedIngredients: _checkedIngredients,
              onToggleIngredient: (i) => setState(() {
                if (_checkedIngredients.contains(i)) {
                  _checkedIngredients.remove(i);
                } else {
                  _checkedIngredients.add(i);
                }
              }),
              onStartCooking: () => _openCooking(recipe),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              CraftShimmer(height: 160),
              SizedBox(height: 14),
              CraftShimmer(height: 80),
              SizedBox(height: 14),
              CraftShimmer(height: 200),
            ],
          );
        },
        error: (_, __) {
          if (recipe != null) {
            return _RecipeBody(
              recipe: recipe,
              checkedIngredients: _checkedIngredients,
              onToggleIngredient: (i) => setState(() {
                if (_checkedIngredients.contains(i)) {
                  _checkedIngredients.remove(i);
                } else {
                  _checkedIngredients.add(i);
                }
              }),
              onStartCooking: () => _openCooking(recipe),
            );
          }
          return CraftErrorState(
            message: 'Could not load this recipe.',
            onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
          );
        },
      ),
      floatingActionButton: (_cooking || recipe == null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCooking(recipe),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start cooking'),
            ),
    );
  }
}

class _RecipeBody extends StatelessWidget {
  final Recipe recipe;
  final Set<int> checkedIngredients;
  final ValueChanged<int> onToggleIngredient;
  final VoidCallback onStartCooking;

  const _RecipeBody({
    required this.recipe,
    required this.checkedIngredients,
    required this.onToggleIngredient,
    required this.onStartCooking,
  });

  String _ingLine(Ingredient ing) {
    final amount = '${ing.quantity} ${ing.unit}'.trim();
    final base = amount.isEmpty ? ing.item : '$amount ${ing.item}';
    if (ing.notes != null && ing.notes!.isNotEmpty) {
      return '$base · ${ing.notes}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final n = recipe.nutrition;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F6B4A), Color(0xFF2F8F63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Center(child: Icon(Icons.restaurant_rounded, size: 52, color: Colors.white70)),
              Positioned(
                left: 16,
                bottom: 14,
                right: 16,
                child: Text(
                  recipe.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ).craftIn(),
        const SizedBox(height: 14),
        Text(
          recipe.description,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSecondaryColor,
            height: 1.45,
            fontSize: 14,
          ),
        ).craftIn(delayMs: 40),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(icon: Icons.schedule_rounded, label: '${recipe.totalTimeMinutes} min total'),
            _MetaChip(icon: Icons.soup_kitchen_outlined, label: '${recipe.prepTimeMinutes} prep'),
            _MetaChip(icon: Icons.local_fire_department_outlined, label: '${recipe.cookTimeMinutes} cook'),
            _MetaChip(icon: Icons.people_outline, label: '${recipe.servings} serving${recipe.servings == 1 ? '' : 's'}'),
            _MetaChip(icon: Icons.signal_cellular_alt, label: recipe.difficulty),
          ],
        ).craftIn(delayMs: 60),
        const SizedBox(height: 16),
        TrustBanner(
          verified: true,
          title: 'From your meal plan',
          subtitle:
              'Quantities and steps below are stored with this meal. Use Start cooking for a guided walkthrough.',
          sources: [
            if (recipe.cuisineType.isNotEmpty) recipe.cuisineType,
            '${n.calories} kcal',
          ],
        ).craftIn(delayMs: 80),
        const SizedBox(height: 14),
        _Card(
          title: 'Nutrition per serving',
          child: Row(
            children: [
              _Nut(label: 'Cal', value: '${n.calories}'),
              _Nut(label: 'Protein', value: '${n.proteinG.toStringAsFixed(0)}g'),
              _Nut(label: 'Carbs', value: '${n.carbsG.toStringAsFixed(0)}g'),
              _Nut(label: 'Fat', value: '${n.fatG.toStringAsFixed(0)}g'),
              _Nut(label: 'Fiber', value: '${n.fiberG.toStringAsFixed(0)}g'),
            ],
          ),
        ).craftIn(delayMs: 100),
        _Card(
          title: 'Ingredients',
          subtitle: 'Check off as you prep · exact quantities',
          child: Column(
            children: [
              for (var i = 0; i < recipe.ingredients.length; i++)
                CheckboxListTile(
                  value: checkedIngredients.contains(i),
                  onChanged: (_) => onToggleIngredient(i),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    _ingLine(recipe.ingredients[i]),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: checkedIngredients.contains(i) ? TextDecoration.lineThrough : null,
                      color: checkedIngredients.contains(i)
                          ? AppTheme.textSecondaryColor
                          : AppTheme.ink,
                    ),
                  ),
                ),
              if (recipe.ingredients.isEmpty)
                Text(
                  'No ingredients stored — rebuild the week to generate detailed quantities.',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor),
                ),
            ],
          ),
        ).craftIn(delayMs: 120),
        _Card(
          title: 'How to make it',
          subtitle: '${recipe.instructions.length} steps',
          child: Column(
            children: [
              for (var i = 0; i < recipe.instructions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recipe.instructions[i],
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              if (recipe.instructions.isEmpty)
                Text(
                  'No steps stored yet. Rebuild your week for full cook instructions.',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor),
                ),
            ],
          ),
        ).craftIn(delayMs: 140),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onStartCooking,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            'Start cooking',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ).craftIn(delayMs: 160),
      ],
    );
  }
}

class _CookingMode extends StatelessWidget {
  final Recipe recipe;
  final int step;
  final Set<int> checkedIngredients;
  final ValueChanged<int> onToggleIngredient;
  final ValueChanged<int> onStep;
  final VoidCallback onExit;

  const _CookingMode({
    required this.recipe,
    required this.step,
    required this.checkedIngredients,
    required this.onToggleIngredient,
    required this.onStep,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final steps = recipe.instructions;
    final safeStep = step.clamp(0, steps.length - 1);
    final isLast = safeStep >= steps.length - 1;
    final progress = (safeStep + 1) / steps.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(
                recipe.name,
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Step ${safeStep + 1} of ${steps.length}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.borderSubtle,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  steps[safeStep],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Mise en place',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep quantities handy while you cook',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < recipe.ingredients.length; i++)
                      CheckboxListTile(
                        value: checkedIngredients.contains(i),
                        onChanged: (_) => onToggleIngredient(i),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${recipe.ingredients[i].quantity} ${recipe.ingredients[i].unit} ${recipe.ingredients[i].item}'
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            decoration:
                                checkedIngredients.contains(i) ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: safeStep == 0 ? onExit : () => onStep(safeStep - 1),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: Text(safeStep == 0 ? 'Exit' : 'Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if (isLast) {
                        onExit();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nice work — meal complete!')),
                        );
                      } else {
                        onStep(safeStep + 1);
                      }
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: Text(isLast ? 'Done' : 'Next step'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Card({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Nut extends StatelessWidget {
  final String label;
  final String value;
  const _Nut({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textSecondaryColor)),
        ],
      ),
    );
  }
}
