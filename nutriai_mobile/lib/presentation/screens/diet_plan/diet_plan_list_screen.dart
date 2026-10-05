import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/diet_plan_provider.dart';
import 'daily_meals_screen.dart';
import '../chat/ai_chat_screen.dart';

class DietPlanListScreen extends ConsumerStatefulWidget {
  const DietPlanListScreen({super.key});

  @override
  ConsumerState<DietPlanListScreen> createState() => _DietPlanListScreenState();
}

class _DietPlanListScreenState extends ConsumerState<DietPlanListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dietPlanState = ref.watch(dietPlanNotifierProvider);
    final currentPlan = dietPlanState.currentPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diet Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
            },
          ),
        ],
      ),
      body: dietPlanState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dietPlanState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dietPlanState.error!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : currentPlan == null
                  ? const Center(child: Text('No diet plan found'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlanHeader(currentPlan),
                          _buildAiRationaleCard(currentPlan),
                          _buildMacroTargets(currentPlan),
                          _buildGoals(currentPlan),
                          _buildDaysList(currentPlan),
                        ],
                      ),
                    ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'chat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
            },
            backgroundColor: AppTheme.secondaryColor,
            child: const Icon(Icons.psychology),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'newplan',
            onPressed: _showGeneratePlanDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(dynamic currentPlan) {
    final startDate = DateTime.parse(currentPlan.startDate);
    final endDate = DateTime.parse(currentPlan.endDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentPlan.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentPlan.durationDays} Days Plan',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiRationaleCard(dynamic currentPlan) {
    final rationale = currentPlan.aiRationale;
    if (rationale == null || rationale.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Rationale', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                const SizedBox(height: 4),
                Text(rationale, style: TextStyle(fontSize: 13, color: Colors.blue.shade800, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTargets(dynamic currentPlan) {
    final macros = currentPlan.macroTargets;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            'Daily Targets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem(
                'Calories',
                '${currentPlan.targetCalories}',
                'kcal',
                AppTheme.primaryColor,
              ),
              _buildMacroItem(
                'Protein',
                '${macros.proteinPercent}',
                '%',
                Colors.red,
              ),
              _buildMacroItem(
                'Carbs',
                '${macros.carbPercent}',
                '%',
                Colors.orange,
              ),
              _buildMacroItem(
                'Fat',
                '${macros.fatPercent}',
                '%',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGoals(dynamic currentPlan) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            'Your Goals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentPlan.goals.map<Widget>((goal) {
              return Chip(
                label: Text(goal),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                labelStyle: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList(dynamic currentPlan) {
    final groupedMeals = <int, List<dynamic>>{};
    for (var meal in currentPlan.meals) {
      if (!groupedMeals.containsKey(meal.day)) {
        groupedMeals[meal.day] = [];
      }
      groupedMeals[meal.day]!.add(meal);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Meal Plan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...groupedMeals.entries.map((entry) {
            final day = entry.key;
            final meals = entry.value;
            final date = DateTime.parse(currentPlan.startDate).add(Duration(days: day - 1));

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DailyMealsScreen(
                        day: day,
                        date: DateFormat('yyyy-MM-dd').format(date),
                        meals: meals,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Day',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM dd').format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${meals.length} meals planned',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showGeneratePlanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate New AI Plan'),
        content: const Text(
          'Create a fresh 7-day meal plan based on your lab results, health goals, and dietary preferences. '
          'Our AI selects from 1,500+ recipes matched to your profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(dietPlanNotifierProvider.notifier).generateNewPlan(
                    durationDays: 7,
                    goals: [],
                    targetCalories: 1800,
                    macroTargets: {'protein_percent': 25, 'carb_percent': 45, 'fat_percent': 30},
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New AI-powered meal plan generated!'), backgroundColor: AppTheme.primaryColor),
                );
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
