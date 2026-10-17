import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/diet_plan_provider.dart';

class DietPlanHistoryScreen extends ConsumerStatefulWidget {
  const DietPlanHistoryScreen({super.key});

  @override
  ConsumerState<DietPlanHistoryScreen> createState() => _DietPlanHistoryScreenState();
}

class _DietPlanHistoryScreenState extends ConsumerState<DietPlanHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dietPlanNotifierProvider.notifier).loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(dietPlanNotifierProvider).history;
    final loading = ref.watch(dietPlanNotifierProvider).isLoading && history == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past diet plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dietPlanNotifierProvider.notifier).loadHistory(),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : history == null || history.plans.isEmpty
              ? const Center(child: Text('No past plans yet — upload labs to get started.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (history.improvementHint != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(history.improvementHint!, style: const TextStyle(fontSize: 13, height: 1.35)),
                      ),
                    Text('${history.total} plans stored', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    ...history.plans.map((p) {
                      final notes = (p['biometric_notes'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      final isCurrent = p['is_current'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          leading: Icon(
                            isCurrent ? Icons.star : Icons.history,
                            color: isCurrent ? AppTheme.primaryColor : Colors.grey,
                          ),
                          title: Text(p['title']?.toString() ?? 'Diet plan'),
                          subtitle: Text(
                            '${p['week_start'] ?? '?'} → ${p['week_end'] ?? '?'}'
                            '${p['target_calories'] != null ? ' · ${p['target_calories']} kcal' : ''}'
                            '${isCurrent ? ' · CURRENT' : ''}',
                          ),
                          children: [
                            if (p['primary_goal'] != null)
                              ListTile(
                                dense: true,
                                title: const Text('Primary goal'),
                                subtitle: Text('${p['primary_goal']}'),
                              ),
                            if (notes.isNotEmpty)
                              ListTile(
                                dense: true,
                                title: const Text('Biometric adaptations'),
                                subtitle: Text(notes.join('\n')),
                              ),
                            ListTile(
                              dense: true,
                              title: const Text('Created'),
                              subtitle: Text('${p['created_at'] ?? '—'}'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
