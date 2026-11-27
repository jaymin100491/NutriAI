import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_prefs.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../labs/paste_labs_screen.dart';
import '../main_navigation_screen.dart';

class _IntentOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? goalType;
  final bool needsLabs;
  final bool helpChoose;

  const _IntentOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.goalType,
    this.needsLabs = false,
    this.helpChoose = false,
  });
}

const _intents = <_IntentOption>[
  _IntentOption(
    id: 'lose_weight',
    title: 'Lose weight',
    subtitle: 'Sustainable calorie-aware meals you’ll actually keep',
    icon: Icons.monitor_weight_outlined,
    gradient: [Color(0xFF1F6B4A), Color(0xFF3D9B6E)],
    goalType: 'weight_loss',
  ),
  _IntentOption(
    id: 'build_muscle',
    title: 'Build muscle or tone up',
    subtitle: 'Higher protein, training-friendly plates',
    icon: Icons.fitness_center_outlined,
    gradient: [Color(0xFF1B4F72), Color(0xFF2E86AB)],
    goalType: 'muscle_gain',
  ),
  _IntentOption(
    id: 'sport',
    title: 'Fuel a sport or event',
    subtitle: 'Carb timing and recovery built into your week',
    icon: Icons.directions_run_outlined,
    gradient: [Color(0xFF6B3FA0), Color(0xFF9B59B6)],
    goalType: 'athletic_performance',
  ),
  _IntentOption(
    id: 'glp1',
    title: 'Get the most from a GLP-1',
    subtitle: 'Protein-forward, nausea-aware support meals',
    icon: Icons.medication_outlined,
    gradient: [Color(0xFF0E6655), Color(0xFF148F77)],
    goalType: 'glp1_support',
  ),
  _IntentOption(
    id: 'health_number',
    title: 'Improve a health number',
    subtitle: 'Cholesterol, A1c, blood pressure, and more',
    icon: Icons.favorite_border,
    gradient: [Color(0xFF922B21), Color(0xFFC0392B)],
    needsLabs: true,
  ),
  _IntentOption(
    id: 'gut',
    title: 'Improve my gut health',
    subtitle: 'Fiber, plants, and gentler digestion support',
    icon: Icons.spa_outlined,
    gradient: [Color(0xFF196F3D), Color(0xFF27AE60)],
    goalType: 'gut_health',
  ),
  _IntentOption(
    id: 'energy',
    title: 'Have more energy',
    subtitle: 'Steady fuel — less afternoon crash',
    icon: Icons.bolt_outlined,
    gradient: [Color(0xFFB9770E), Color(0xFFF39C12)],
    goalType: 'increase_energy',
  ),
  _IntentOption(
    id: 'healthier',
    title: 'Eat healthier overall',
    subtitle: 'Simple, balanced meals without the noise',
    icon: Icons.eco_outlined,
    gradient: [Color(0xFF1F6B4A), Color(0xFF58D68D)],
    goalType: 'eat_healthier',
  ),
  _IntentOption(
    id: 'not_sure',
    title: 'Not sure yet — help me choose',
    subtitle: 'We’ll use your labs and biometrics to guide you',
    icon: Icons.auto_awesome_outlined,
    gradient: [Color(0xFF34495E), Color(0xFF5D6D7E)],
    helpChoose: true,
  ),
];

const _healthNumbers = <_IntentOption>[
  _IntentOption(
    id: 'ldl',
    title: 'Lower cholesterol / LDL',
    subtitle: 'Heart-smart lipids through food',
    icon: Icons.monitor_heart_outlined,
    gradient: [Color(0xFF922B21), Color(0xFFE74C3C)],
    goalType: 'lower_cholesterol',
  ),
  _IntentOption(
    id: 'a1c',
    title: 'Improve blood sugar / A1c',
    subtitle: 'Low-GI patterns that stabilize energy',
    icon: Icons.bloodtype_outlined,
    gradient: [Color(0xFF6C3483), Color(0xFFA569BD)],
    goalType: 'manage_diabetes',
  ),
  _IntentOption(
    id: 'bp',
    title: 'Lower blood pressure',
    subtitle: 'DASH-style sodium-aware eating',
    icon: Icons.favorite_outline,
    gradient: [Color(0xFF1A5276), Color(0xFF3498DB)],
    goalType: 'lower_blood_pressure',
  ),
  _IntentOption(
    id: 'inflammation',
    title: 'Reduce inflammation',
    subtitle: 'Anti-inflammatory food patterns',
    icon: Icons.local_fire_department_outlined,
    gradient: [Color(0xFF935116), Color(0xFFE67E22)],
    goalType: 'reduce_inflammation',
  ),
];

/// Fitia/Alma-style first question: what do you want to change?
class IntentOnboardingScreen extends ConsumerStatefulWidget {
  final bool allowSkipToApp;
  final bool forceShow;

  const IntentOnboardingScreen({
    super.key,
    this.allowSkipToApp = true,
    this.forceShow = false,
  });

  @override
  ConsumerState<IntentOnboardingScreen> createState() => _IntentOnboardingScreenState();
}

class _IntentOnboardingScreenState extends ConsumerState<IntentOnboardingScreen> {
  bool _saving = false;
  bool _showHealthNumbers = false;
  String? _selectedId;

  Future<void> _finishAndRoute({required bool preferLabs}) async {
    final auth = ref.read(authProvider);
    final isAdmin = auth.user?.isAdmin == true;

    // Re-opened from Profile: just return to the app shell.
    if (widget.forceShow && Navigator.of(context).canPop()) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final Widget destination;
    if ((preferLabs && !isAdmin) || (!isAdmin && auth.needsLabImport)) {
      destination = const PasteLabsScreen(allowSkip: true);
    } else {
      destination = const MainNavigationScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  Future<void> _select(_IntentOption option) async {
    if (_saving) return;
    setState(() {
      _selectedId = option.id;
      _saving = true;
    });

    try {
      final userId = ref.read(authProvider).user?.id;
      await OnboardingPrefs.markIntentComplete(userId, intentId: option.id);

      if (option.helpChoose || option.needsLabs && option.goalType == null && option.id == 'health_number') {
        if (option.id == 'health_number') {
          setState(() {
            _showHealthNumbers = true;
            _saving = false;
          });
          return;
        }
        // Help me choose → labs / derive path
        if (!mounted) return;
        await _finishAndRoute(preferLabs: true);
        return;
      }

      if (option.goalType != null) {
        await ref.read(goalNotifierProvider.notifier).addGoal(
              goalType: option.goalType,
              makePrimary: true,
            );
      }

      if (!mounted) return;
      await _finishAndRoute(preferLabs: option.needsLabs || option.helpChoose);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t save preference: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _showHealthNumbers ? _healthNumbers : _intents;
    final title = _showHealthNumbers
        ? 'Which health number matters most?'
        : 'What do you want to change first?';
    final subtitle = _showHealthNumbers
        ? 'We’ll tailor meals and lab follow-ups around this marker.'
        : 'Pick one to personalize NutriAI. You can refine this anytime.';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  if (_showHealthNumbers)
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _showHealthNumbers = false;
                                _selectedId = null;
                              }),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 8),
                  const Spacer(),
                  if (widget.allowSkipToApp)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final userId = ref.read(authProvider).user?.id;
                              await OnboardingPrefs.markIntentComplete(userId, intentId: 'skipped');
                              if (!mounted) return;
                              await _finishAndRoute(preferLabs: false);
                            },
                      child: const Text('Skip for now'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NutriAI · personalized for you',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final o = options[i];
                  final selected = _selectedId == o.id;
                  return _IntentCard(
                    option: o,
                    selected: selected,
                    enabled: !_saving,
                    onTap: () => _select(o),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final _IntentOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _IntentCard({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.borderSubtle,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: option.gradient,
                  ),
                ),
                child: Icon(option.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right_rounded,
                color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
