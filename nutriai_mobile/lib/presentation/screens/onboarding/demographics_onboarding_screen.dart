import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/craft/craft.dart';
import '../main_navigation_screen.dart';

/// Post-lab demographics so BMR/TDEE uses real sex, age, and activity.
class DemographicsOnboardingScreen extends ConsumerStatefulWidget {
  const DemographicsOnboardingScreen({super.key});

  @override
  ConsumerState<DemographicsOnboardingScreen> createState() =>
      _DemographicsOnboardingScreenState();
}

class _DemographicsOnboardingScreenState
    extends ConsumerState<DemographicsOnboardingScreen> {
  String _sex = 'male';
  String _activity = 'moderate';
  final _dobController = TextEditingController(text: '1991-04-10');
  bool _saving = false;
  String? _error;

  static const _activities = <Map<String, String>>[
    {'id': 'sedentary', 'label': 'Sedentary', 'hint': 'Desk job, little exercise'},
    {'id': 'light', 'label': 'Light', 'hint': 'Walks 1–3 days/week'},
    {'id': 'moderate', 'label': 'Moderate', 'hint': 'Exercise 3–5 days/week'},
    {'id': 'active', 'label': 'Active', 'hint': 'Hard exercise 6–7 days/week'},
    {'id': 'very_active', 'label': 'Very active', 'hint': 'Physical job + training'},
  ];

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dob = _dobController.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      setState(() => _error = 'Use date of birth as YYYY-MM-DD');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.put(
        ApiConstants.dietPlanPreferences,
        data: {
          'sex': _sex,
          'date_of_birth': dob,
          'activity_level': _activity,
          'demographics_complete': true,
          'regenerate_plan': false,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'About you',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ).craftIn(),
            const SizedBox(height: 6),
            Text(
              'Step 1 of coaching setup',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: AppTheme.textSecondaryColor,
              ),
            ).craftIn(delayMs: 40),
            const SizedBox(height: 16),
            TrustBanner(
              verified: true,
              title: 'Why we ask',
              subtitle:
                  'Sex, age, and activity drive Mifflin–St Jeor BMR → TDEE before meals are built. Numbers stay on your profile.',
              sources: const ['method: Mifflin–St Jeor', 'engine: nutrition'],
            ).craftIn(delayMs: 80),
            const SizedBox(height: 22),
            Text(
              'Sex',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ).craftIn(delayMs: 100),
            const SizedBox(height: 20),
            TextField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: 'Date of birth (YYYY-MM-DD)',
              ),
              keyboardType: TextInputType.datetime,
            ).craftIn(delayMs: 120),
            const SizedBox(height: 20),
            Text(
              'Activity level',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._activities.asMap().entries.map((entry) {
              final a = entry.value;
              final selected = _activity == a['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.chipBg : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppTheme.primaryColor : AppTheme.borderSubtle,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      a['label']!,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      a['hint']!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    onTap: () => setState(() => _activity = a['id']!),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : null,
                  ),
                ).craftIn(delayMs: 140 + entry.key * 30),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Continue to NutriAI',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
            ).craftIn(delayMs: 280),
          ],
        ),
      ),
    );
  }
}
