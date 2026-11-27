import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/diet_plan_provider.dart';
import '../../widgets/craft/craft.dart';
import 'daily_meals_screen.dart';
import 'diet_plan_history_screen.dart';
import '../main_navigation_screen.dart';

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
      final n = ref.read(dietPlanNotifierProvider.notifier);
      n.loadCurrentDietPlan();
      n.loadSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dietPlanState = ref.watch(dietPlanNotifierProvider);
    final currentPlan = dietPlanState.currentPlan;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Your week',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Past plans',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DietPlanHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final n = ref.read(dietPlanNotifierProvider.notifier);
              n.loadCurrentDietPlan();
              n.loadSchedule();
            },
          ),
        ],
      ),
      body: dietPlanState.isLoading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                CraftShimmer(height: 88),
                SizedBox(height: 14),
                CraftShimmer(height: 160),
                SizedBox(height: 14),
                CraftShimmer(height: 120),
                SizedBox(height: 14),
                CraftShimmer(height: 200),
              ],
            )
          : dietPlanState.error != null
              ? CraftErrorState(
                  message: dietPlanState.error!,
                  onRetry: () {
                    ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
                  },
                )
              : currentPlan == null
                  ? CraftEmptyState(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'No plan yet',
                      body:
                          'Generate a week of meals from your labs, goals, and calorie engine — or ask Coach to build one.',
                      ctaLabel: 'Talk to Coach',
                      onCta: () => MainNavController.switchToTab(context, 3),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildScheduleBanner(dietPlanState.schedule).craftIn(),
                          _buildPlanHeader(currentPlan).craftIn(delayMs: 40),
                          _buildEngineTargetsCard(currentPlan).craftIn(delayMs: 80),
                          _buildAiRationaleCard(currentPlan).craftIn(delayMs: 110),
                          _buildMacroTargets(currentPlan).craftIn(delayMs: 140),
                          _buildGoals(currentPlan).craftIn(delayMs: 160),
                          _buildDaysList(currentPlan).craftIn(delayMs: 180),
                          const SizedBox(height: 88),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGeneratePlanDialog,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Rebuild week'),
      ),
    );
  }

  Widget _buildScheduleBanner(Map<String, dynamic>? schedule) {
    if (schedule == null) return const SizedBox.shrink();
    final isFriday = schedule['is_friday'] == true;
    final note = schedule['message']?.toString() ??
        'Mon–Sun fixed week. Next week’s plan is prepared every Friday from your biometrics.';
    final current = schedule['current_week'] as Map?;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFriday ? AppTheme.accentColor.withValues(alpha: 0.35) : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFriday ? Icons.event_available_rounded : Icons.calendar_view_week_rounded,
                size: 18,
                color: isFriday ? AppTheme.accentColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                isFriday ? 'Friday release day' : 'Weekly cadence',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          if (current != null) ...[
            const SizedBox(height: 6),
            Text(
              'This week: ${current['start']} → ${current['end']}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ],
          if (isFriday)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await ref.read(dietPlanNotifierProvider.notifier).generateWeekly(nextWeek: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Next week’s Mon–Sun plan is ready')),
                    );
                  }
                },
                child: const Text('Generate next week'),
              ),
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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6B4A), Color(0xFF2F8F63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentPlan.title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d, yyyy').format(endDate)}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              _HeaderChip(label: '${currentPlan.durationDays} days'),
              _HeaderChip(label: '${currentPlan.targetCalories} kcal/day'),
              _HeaderChip(
                label: 'Ask Coach',
                onTap: () => MainNavController.switchToTab(context, 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineTargetsCard(dynamic currentPlan) {
    final engine = currentPlan.nutritionEngine as Map<String, dynamic>?;
    if (engine == null || engine.isEmpty) return const SizedBox.shrink();

    final notes = (engine['notes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final labs = engine['labs'] is Map
        ? Map<String, dynamic>.from(engine['labs'] as Map)
        : <String, dynamic>{};
    final method = engine['method']?.toString() ?? '';
    final bmr = engine['bmr'];
    final tdee = engine['tdee'];
    final labBits = labs.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}: ${e.value}')
        .take(6)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrustBanner(
            verified: true,
            title: 'Nutrition engine targets',
            subtitle:
                'Target ${currentPlan.targetCalories} kcal'
                '${bmr != null ? ' · BMR $bmr' : ''}'
                '${tdee != null ? ' · TDEE $tdee' : ''}'
                '${method.isNotEmpty ? ' · $method' : ''}',
            sources: [
              if (method.isNotEmpty) method,
              if (labBits.isNotEmpty) 'labs: $labBits',
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How we got here',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  ...notes.take(4).map(
                        (n) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: AppTheme.primaryColor)),
                              Expanded(
                                child: Text(
                                  n,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chef rationale',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              const Spacer(),
              const ProvenanceChip(label: 'AI meals', icon: Icons.psychology_outlined),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rationale,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.45,
              color: AppTheme.textSecondaryColor,
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

    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CraftSectionHeader(
            title: 'This week’s days',
            subtitle: '${groupedMeals.length} days · tap to open meals',
            action: 'Coach',
            onAction: () => MainNavController.switchToTab(context, 3),
          ),
          const SizedBox(height: 12),
          ...groupedMeals.entries.map((entry) {
            final day = entry.key;
            final meals = entry.value;
            final date = DateTime.parse(currentPlan.startDate).add(Duration(days: day - 1));
            final isToday =
                date.year == today.year && date.month == today.month && date.day == today.day;
            final cals = meals.fold<int>(0, (sum, m) {
              try {
                return sum + ((m.recipe?.nutrition.calories as int?) ?? 0);
              } catch (_) {
                return sum;
              }
            });

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isToday ? AppTheme.chipBg : Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
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
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isToday ? AppTheme.primaryColor.withValues(alpha: 0.35) : AppTheme.borderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.primaryColor : AppTheme.chipBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date).toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isToday ? Colors.white70 : AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                '${date.day}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isToday ? Colors.white : AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('EEEE, MMM d').format(date),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (isToday)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Today',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${meals.length} meals · $cals kcal',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showGeneratePlanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rebuild this week',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Recreate Mon–Sunday meals from your labs, goals, and calorie engine. Past weeks stay in history.',
          style: GoogleFonts.plusJakartaSans(height: 1.4, color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(dietPlanNotifierProvider.notifier).generateWeekly(nextWeek: false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mon–Sun plan updated'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              }
            },
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _HeaderChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: child);
  }
}
