import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../main_navigation_screen.dart';

/// Short post-lab screen so BMR/TDEE uses real sex, age, and activity.
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
      appBar: AppBar(title: const Text('About you')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: const Text(
                'We use sex, age, and activity to calculate your calorie target '
                '(Mifflin–St Jeor BMR → TDEE) before building meals.',
                style: TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sex', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: 'Date of birth (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 20),
            const Text('Activity level', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._activities.map((a) {
              final selected = _activity == a['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  selected: selected,
                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
                    ),
                  ),
                  title: Text(a['label']!),
                  subtitle: Text(a['hint']!),
                  onTap: () => setState(() => _activity = a['id']!),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                      : null,
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue to NutriAI'),
            ),
          ],
        ),
      ),
    );
  }
}
