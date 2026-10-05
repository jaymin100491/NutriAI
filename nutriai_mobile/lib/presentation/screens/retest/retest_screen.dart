import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/web_redirect.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/lab_result_provider.dart';

/// Follow-up lab scheduling — fulfillment is Labcorp-only (business funnel).
/// App branding stays neutral / wellness-first.
class RetestScreen extends ConsumerWidget {
  const RetestScreen({super.key});

  static const _labcorpLocator =
      'https://www.labcorp.com/labs-and-appointments';

  Future<void> _scheduleAtLabcorp(BuildContext context) async {
    try {
      await redirectToUrl(_labcorpLocator);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open scheduling. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labsAsync = ref.watch(allLabResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Follow-up Labs')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor.withOpacity(0.12), Colors.white],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your nutrition plan works best with fresh data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'After 8–12 weeks on your plan, recheck key markers so we can '
                  'measure improvement and refine meals. This is wellness guidance — '
                  'discuss timing with your provider.',
                  style: TextStyle(height: 1.4, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Recommended panels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          labsAsync.when(
            data: (labs) => Column(
              children: _recommendationsFromLabs(labs)
                  .map((r) => _RecCard(title: r.$1, reason: r.$2))
                  .toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _RecCard(
              title: 'Lipid Panel + HbA1c + Glucose',
              reason: 'Core metabolic markers for nutrition progress.',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _scheduleAtLabcorp(context),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Schedule at Labcorp'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF0B3D5C),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'To keep results consistent and actionable in NutriAI, follow-up '
            'collections are fulfilled through Labcorp patient service centers.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text(
            'Not medical advice. Your provider decides what to order.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _recommendationsFromLabs(List labs) {
    final names = <String>{};
    for (final lab in labs.take(2)) {
      for (final m in lab.markers) {
        names.add(m.name.toLowerCase());
      }
    }
    final recs = <(String, String)>[];
    if (names.any((n) => n.contains('a1c') || n.contains('glucose'))) {
      recs.add((
        'Hemoglobin A1c + Glucose',
        'Track glycemic response to your meal plan over 8–12 weeks.',
      ));
    }
    if (names.any((n) => n.contains('ldl') || n.contains('cholesterol') || n.contains('triglyceride'))) {
      recs.add((
        'Lipid Panel (Total / HDL / LDL / Triglycerides)',
        'Measure cholesterol changes from fiber, fats, and cuisine swaps.',
      ));
    }
    if (names.any((n) => n.contains('creat') || n.contains('egfr'))) {
      recs.add((
        'Creatinine + eGFR',
        'Kidney markers to keep protein targets safe and personalized.',
      ));
    }
    recs.add((
      'Biometrics (weight, BP, waist)',
      'Pair labs with body metrics so coaching stays precise.',
    ));
    return recs;
  }
}

class _RecCard extends StatelessWidget {
  final String title;
  final String reason;

  const _RecCard({required this.title, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.science_outlined, color: AppTheme.primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(reason),
      ),
    );
  }
}
