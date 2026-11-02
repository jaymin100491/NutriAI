import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.firstName ?? 'there';
    final labAsync = ref.watch(latestLabResultProvider);
    final planState = ref.watch(dietPlanNotifierProvider);
    final goalsAsync = ref.watch(healthGoalsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            ref.invalidate(latestLabResultProvider);
            ref.invalidate(healthGoalsProvider);
            await ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()},',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _RoundIconButton(
                        icon: Icons.science_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LabResultsListScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        icon: Icons.flag_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GoalsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    labAsync.when(
                      data: (lab) => _HealthHero(lab: lab, goals: goalsAsync.valueOrNull),
                      loading: () => const _SkeletonCard(height: 140),
                      error: (_, __) => _HealthHero(lab: null, goals: goalsAsync.valueOrNull),
                    ),
                    const SizedBox(height: 14),
                    _CoachBanner(onTap: () => MainNavController.switchToTab(context, 2)),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: "Today's meals",
                      action: 'Full plan',
                      onAction: () => MainNavController.switchToTab(context, 1),
                    ),
                    const SizedBox(height: 10),
                    _TodaysMeals(planState: planState),
                    const SizedBox(height: 22),
                    const _SectionTitle(title: 'Quick actions'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            label: 'AI Coach',
                            icon: Icons.auto_awesome,
                            color: AppTheme.primaryColor,
                            onTap: () => MainNavController.switchToTab(context, 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            label: 'Plan',
                            icon: Icons.restaurant_menu_rounded,
                            color: const Color(0xFF1B4F72),
                            onTap: () => MainNavController.switchToTab(context, 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            label: 'Progress',
                            icon: Icons.insights_outlined,
                            color: AppTheme.accentColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProgressScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    goalsAsync.when(
                      data: (goals) => goals.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  title: 'Your priorities',
                                  action: 'Manage',
                                  onAction: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _GoalsStrip(goals: goals),
                              ],
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthHero extends StatelessWidget {
  final LabResult? lab;
  final List<dynamic>? goals;
  const _HealthHero({required this.lab, required this.goals});

  @override
  Widget build(BuildContext context) {
    LabMarker? ldl;
    LabMarker? glucose;
    if (lab != null) {
      for (final m in lab!.markers) {
        final name = m.name.toLowerCase();
        if (ldl == null && name.contains('ldl')) ldl = m;
        if (glucose == null && name.contains('glucose')) glucose = m;
      }
    }
    final primaryGoal = goals?.isNotEmpty == true ? goals!.first : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Health snapshot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      lab != null ? 'Latest labs · ${lab!.testDate}' : 'Add labs to unlock deeper coaching',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: ldl?.name ?? 'Labs',
                  value: ldl != null
                      ? '${ldl.displayValue}${ldl.unit.isNotEmpty ? ' ${ldl.unit}' : ''}'
                      : (glucose != null
                          ? '${glucose.displayValue}'
                          : '—'),
                  alert: ldl?.isHigh == true || glucose?.isHigh == true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: 'Focus',
                  value: primaryGoal?.label?.toString() ?? 'Set a goal',
                  alert: false,
                ),
              ),
            ],
          ),
          if (lab?.aiInterpretation != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6ED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                lab!.aiInterpretation!,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF7A4E1D)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CoachBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F6B4A), Color(0xFF2F8F63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talk to your AI dietitian',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Swap meals, change priorities, reshape your week',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaysMeals extends StatelessWidget {
  final DietPlanState planState;
  const _TodaysMeals({required this.planState});

  @override
  Widget build(BuildContext context) {
    final plan = planState.currentPlan;
    if (planState.isLoading && plan == null) {
      return const _SkeletonCard(height: 160);
    }
    if (plan == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          planState.error ?? 'No meals for today yet — open Plan to generate your week.',
          style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.4),
        ),
      );
    }

    final today = DateTime.now();
    var meals = plan.meals.where((m) {
      try {
        final mealDate = DateTime.parse(m.date);
        return mealDate.year == today.year && mealDate.month == today.month && mealDate.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();
    if (meals.isEmpty) {
      meals = plan.meals.where((m) => m.day == 1).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < meals.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _MealRow(
              mealType: _cap(meals[i].mealType),
              name: meals[i].recipe?.name ?? 'Meal',
              calories: '${meals[i].recipe?.nutrition.calories ?? 0} cal',
              time: _time(meals[i].mealType),
              icon: _icon(meals[i].mealType),
            ),
          ],
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  String _time(String type) =>
      {'breakfast': '7:00 AM', 'lunch': '12:30 PM', 'dinner': '6:30 PM', 'snack': '3:00 PM'}[type] ?? '';
  IconData _icon(String type) =>
      {
        'breakfast': Icons.wb_sunny_outlined,
        'lunch': Icons.lunch_dining_outlined,
        'dinner': Icons.dinner_dining_outlined,
        'snack': Icons.cookie_outlined,
      }[type] ??
      Icons.restaurant;
}

class _MealRow extends StatelessWidget {
  final String mealType;
  final String name;
  final String calories;
  final String time;
  final IconData icon;

  const _MealRow({
    required this.mealType,
    required this.name,
    required this.calories,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mealType, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
              Text(calories, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsStrip extends StatelessWidget {
  final List goals;
  const _GoalsStrip({required this.goals});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: goals.length.clamp(0, 6),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final g = goals[i];
          final primary = g.priority == 1;
          return Container(
            width: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primary ? AppTheme.primaryColor : AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary ? 'PRIMARY' : 'PRIORITY ${g.priority}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: primary ? Colors.white70 : AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${g.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: primary ? Colors.white : AppTheme.ink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;
  const _MetricPill({required this.label, required this.value, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: alert ? AppTheme.warningColor : AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.borderSubtle)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppTheme.ink)),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
    );
  }
}
