import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diet_plan_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/lab_result_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lab_result_model.dart';
import '../main_navigation_screen.dart';
import '../goals/goals_screen.dart';
import '../lab_results/lab_results_list_screen.dart';
import '../tracking/progress_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.firstName ?? 'User';
    final labAsync = ref.watch(latestLabResultProvider);
    final planState = ref.watch(dietPlanNotifierProvider);
    final goalsAsync = ref.watch(healthGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good morning, $userName!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Your AI-powered health dashboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Lab Results',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabResultsListScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Health Goals',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestLabResultProvider);
          ref.invalidate(healthGoalsProvider);
          await ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labAsync.when(
                data: (lab) => _buildHealthSummaryCard(lab, goalsAsync.valueOrNull),
                loading: () => const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
                error: (_, __) => _buildHealthSummaryCard(null, goalsAsync.valueOrNull),
              ),
              const SizedBox(height: 16),
              _buildAiCoachBanner(context),
              const SizedBox(height: 16),
              _buildSectionHeader('Today\'s Meals', onViewAll: () => MainNavController.switchToTab(context, 1)),
              const SizedBox(height: 12),
              _buildTodaysMealsCard(planState),
              const SizedBox(height: 16),
              _buildSectionHeader('Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 16),
              goalsAsync.when(
                data: (goals) => goals.isNotEmpty ? _buildGoalsPreview(goals) : const SizedBox(),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard(LabResult? lab, List<dynamic>? goals) {
    LabMarker? ldl;
    LabMarker? glucose;
    if (lab != null) {
      for (final m in lab.markers) {
        final name = m.name.toLowerCase();
        if (ldl == null && name.contains('ldl')) ldl = m;
        if (glucose == null && name.contains('glucose')) glucose = m;
      }
    }
    final primaryGoal = goals?.isNotEmpty == true ? goals!.first : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.favorite, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Health Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        lab != null ? 'Latest labs: ${lab.testDate}' : 'No lab results yet',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (ldl != null)
                  Expanded(child: _buildHealthMetric(ldl.name, ldl.displayValue, ldl.unit, isHigh: ldl.isHigh))
                else if (glucose != null)
                  Expanded(child: _buildHealthMetric(glucose.name, glucose.displayValue, glucose.unit, isHigh: glucose.isHigh))
                else
                  const Expanded(child: Text('Connect lab results for personalized insights')),
                const SizedBox(width: 12),
                if (primaryGoal != null)
                  Expanded(child: _buildHealthMetric('Priority #1', primaryGoal.label, '', isNormal: true)),
              ],
            ),
            if (lab?.aiInterpretation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(lab!.aiInterpretation!, style: TextStyle(fontSize: 13, color: Colors.orange.shade900))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiCoachBanner(BuildContext context) {
    return InkWell(
      onTap: () => MainNavController.switchToTab(context, 2),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.white, size: 36),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat with your AI Dietitian', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Swap ingredients, change priorities, update your 7-day plan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysMealsCard(DietPlanState planState) {
    final plan = planState.currentPlan;
    if (plan == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Loading your meal plan...'))));
    }

    final today = DateTime.now();
    final todayMeals = plan.meals.where((m) {
      final mealDate = DateTime.parse(m.date);
      return mealDate.year == today.year && mealDate.month == today.month && mealDate.day == today.day;
    }).toList();

    if (todayMeals.isEmpty) {
      final day1Meals = plan.meals.where((m) => m.day == 1).toList();
      return Card(
        child: Column(
          children: day1Meals.map((m) => _buildMealItem(
            _capitalize(m.mealType),
            m.recipe?.name ?? 'Recipe',
            '${m.recipe?.nutrition.calories ?? 0} cal',
            _mealTime(m.mealType),
            _mealIcon(m.mealType),
          )).toList(),
        ),
      );
    }

    return Card(
      child: Column(
        children: todayMeals.map((m) => _buildMealItem(
          _capitalize(m.mealType),
          m.recipe?.name ?? 'Recipe',
          '${m.recipe?.nutrition.calories ?? 0} cal',
          _mealTime(m.mealType),
          _mealIcon(m.mealType),
        )).toList(),
      ),
    );
  }

  Widget _buildGoalsPreview(List<dynamic> goals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Your Health Priorities'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: goals.take(3).map((g) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: g.priority == 1 ? AppTheme.primaryColor : Colors.grey.shade300,
                  child: Text('${g.priority}', style: TextStyle(fontSize: 12, color: g.priority == 1 ? Colors.white : Colors.black54)),
                ),
                title: Text(g.label, style: const TextStyle(fontSize: 14)),
                subtitle: g.currentValue != null ? Text('Current: ${g.currentValue} ${g.unit}', style: const TextStyle(fontSize: 11)) : null,
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetric(String label, String value, String unit, {bool isHigh = false, bool isNormal = false}) {
    final color = isHigh ? Colors.orange : (isNormal ? Colors.green : AppTheme.textSecondaryColor);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor), maxLines: 2),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
              if (unit.isNotEmpty) Text(' $unit', style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(String mealType, String recipeName, String calories, String time, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(mealType, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
      subtitle: Text(recipeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
          Text(calories, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildQuickActionCard('AI Coach', Icons.psychology, AppTheme.primaryColor, () => MainNavController.switchToTab(context, 2))),
        const SizedBox(width: 12),
        Expanded(child: _buildQuickActionCard('View Plan', Icons.restaurant_menu, Colors.green, () => MainNavController.switchToTab(context, 1))),
        const SizedBox(width: 12),
        Expanded(child: _buildQuickActionCard('Progress', Icons.bar_chart, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressScreen())))),
      ],
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (onViewAll != null) TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  String _mealTime(String type) => {'breakfast': '7:00 AM', 'lunch': '12:30 PM', 'dinner': '6:30 PM', 'snack': '3:00 PM'}[type] ?? '';
  IconData _mealIcon(String type) => {'breakfast': Icons.wb_sunny_outlined, 'lunch': Icons.lunch_dining_outlined, 'dinner': Icons.dinner_dining_outlined, 'snack': Icons.cookie_outlined}[type] ?? Icons.restaurant;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
