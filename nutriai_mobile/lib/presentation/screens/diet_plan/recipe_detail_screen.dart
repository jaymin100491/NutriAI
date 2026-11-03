import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/diet_plan_model.dart';
import '../../providers/diet_plan_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final int recipeId;
  /// Prefer passing the plan-embedded recipe so detail works even when catalog lookup 404s.
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

  void _openCooking(Recipe recipe) {
    if (recipe.instructions.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _cooking ? 'Cooking mode' : (widget.initialRecipe?.name ?? 'Recipe'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
        data: (fetched) {
          final recipe = fetched ?? widget.initialRecipe;
          if (recipe == null) {
            return _NotFound(
              onBack: () => Navigator.of(context).maybePop(),
              onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
            );
          }
          if (_cooking) {
            return _CookingMode(
              recipe: recipe,
              step: _step,
              onStep: (s) => setState(() => _step = s),
              onExit: () => setState(() => _cooking = false),
            );
          }
          return _RecipeBody(
            recipe: recipe,
            onStartCooking: () => _openCooking(recipe),
          );
        },
        loading: () {
          if (widget.initialRecipe != null) {
            final recipe = widget.initialRecipe!;
            if (_cooking) {
              return _CookingMode(
                recipe: recipe,
                step: _step,
                onStep: (s) => setState(() => _step = s),
                onExit: () => setState(() => _cooking = false),
              );
            }
            return _RecipeBody(
              recipe: recipe,
              onStartCooking: () => _openCooking(recipe),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          final recipe = widget.initialRecipe;
          if (recipe != null) {
            if (_cooking) {
              return _CookingMode(
                recipe: recipe,
                step: _step,
                onStep: (s) => setState(() => _step = s),
                onExit: () => setState(() => _cooking = false),
              );
            }
            return _RecipeBody(
              recipe: recipe,
              onStartCooking: () => _openCooking(recipe),
            );
          }
          return _NotFound(
            onBack: () => Navigator.of(context).maybePop(),
            onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
          );
        },
      ),
      floatingActionButton: _cooking
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final recipe = recipeAsync.valueOrNull ?? widget.initialRecipe;
                if (recipe == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recipe not loaded yet')),
                  );
                  return;
                }
                _openCooking(recipe);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Cooking'),
            ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const _NotFound({required this.onBack, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, size: 48, color: AppTheme.textSecondaryColor),
            const SizedBox(height: 12),
            const Text('Recipe not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'This meal may have been generated for your plan and isn’t in the shared catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onBack, child: const Text('Go back')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CookingMode extends StatelessWidget {
  final Recipe recipe;
  final int step;
  final ValueChanged<int> onStep;
  final VoidCallback onExit;

  const _CookingMode({
    required this.recipe,
    required this.step,
    required this.onStep,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final steps = recipe.instructions;
    final safeStep = step.clamp(0, steps.length - 1);
    final isLast = safeStep >= steps.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(recipe.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Step ${safeStep + 1} of ${steps.length}',
            style: const TextStyle(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (safeStep + 1) / steps.length,
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.borderSubtle,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: SingleChildScrollView(
                child: Text(
                  steps[safeStep],
                  style: const TextStyle(fontSize: 22, height: 1.45, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: safeStep == 0 ? onExit : () => onStep(safeStep - 1),
                  child: Text(safeStep == 0 ? 'Exit' : 'Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                  child: Text(isLast ? 'Done' : 'Next step'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeBody extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onStartCooking;
  const _RecipeBody({required this.recipe, required this.onStartCooking});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
          ),
          child: const Center(child: Icon(Icons.restaurant, size: 56, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        Text(recipe.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          recipe.description,
          style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _chip(Icons.schedule, '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min'),
            const SizedBox(width: 8),
            _chip(Icons.people_outline, '${recipe.servings} serving'),
            const SizedBox(width: 8),
            _chip(Icons.signal_cellular_alt, recipe.difficulty),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Nutrition',
          Column(
            children: [
              _row('Calories', '${recipe.nutrition.calories} kcal'),
              _row('Protein', '${recipe.nutrition.proteinG.toStringAsFixed(0)} g'),
              _row('Carbs', '${recipe.nutrition.carbsG.toStringAsFixed(0)} g'),
              _row('Fat', '${recipe.nutrition.fatG.toStringAsFixed(0)} g'),
              _row('Fiber', '${recipe.nutrition.fiberG.toStringAsFixed(0)} g'),
            ],
          ),
        ),
        _section(
          'Ingredients',
          Column(
            children: [
              for (final ing in recipe.ingredients)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(ing.item),
                  trailing: Text(
                    '${ing.quantity} ${ing.unit}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
        _section(
          'Instructions',
          Column(
            children: [
              for (var i = 0; i < recipe.instructions.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  title: Text(recipe.instructions[i], style: const TextStyle(height: 1.35)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onStartCooking,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Cooking'),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
