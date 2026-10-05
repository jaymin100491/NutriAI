import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/goal_model.dart';
import '../../providers/diet_plan_provider.dart';
import '../../providers/goal_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(goalNotifierProvider.notifier).loadGoals(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddGoalSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) => _GoalsList(goals: goals),
      ),
    );
  }

  Future<void> _openAddGoalSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddGoalSheet(),
    );
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _selectedType;
  List<Map<String, dynamic>> _catalog = const [];

  static const _quick = [
    ('lower_blood_pressure', 'Blood pressure'),
    ('muscle_gain', 'Build muscle'),
    ('more_protein', 'More protein'),
    ('weight_loss', 'Lose weight'),
    ('weight_gain', 'Gain weight'),
    ('gut_health', 'Gut health'),
    ('better_sleep', 'Better sleep'),
    ('athletic_performance', 'Athletic performance'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final items = await ref.read(goalRepositoryProvider).getCatalog();
      if (mounted) setState(() => _catalog = items);
    } catch (_) {}
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (_selectedType == null && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a goal or type your own')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref.read(goalNotifierProvider.notifier).addGoal(
            text: text.isEmpty ? null : text,
            goalType: _selectedType,
            makePrimary: true,
          );
      await ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
      if (!mounted) return;
      Navigator.pop(context);
      final title = result['plan_title'] ?? 'your meal plan';
      final cals = result['target_calories'];
      final ai = result['ai_interpreted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cals != null
                ? (ai
                    ? 'AI mapped your goal — regenerated $title (~$cals kcal)'
                    : 'Goal added — regenerated $title (~$cals kcal)')
                : 'Goal added — meal plan regenerated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add goal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add any health goal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We’ll rebuild your meal plan around this as priority #1 — '
              'blood pressure, more protein, sleep, gut health, or type anything.',
              style: TextStyle(color: AppTheme.textSecondaryColor, height: 1.35),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quick.map((q) {
                final selected = _selectedType == q.$1;
                return ChoiceChip(
                  label: Text(q.$2),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedType = selected ? null : q.$1;
                      if (!selected) _controller.clear();
                    });
                  },
                );
              }).toList(),
            ),
            if (_catalog.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'More presets (${_catalog.length})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Or type your own goal',
                hintText: 'e.g. lower blood pressure, build muscle, more protein for gym',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_selectedType != null) setState(() => _selectedType = null);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save & regenerate meal plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsList extends ConsumerStatefulWidget {
  final List<HealthGoal> goals;
  const _GoalsList({required this.goals});

  @override
  ConsumerState<_GoalsList> createState() => _GoalsListState();
}

class _GoalsListState extends ConsumerState<_GoalsList> {
  late List<HealthGoal> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List.from(widget.goals);
  }

  @override
  void didUpdateWidget(_GoalsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals != oldWidget.goals) {
      _ordered = List.from(widget.goals);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryColor.withOpacity(0.08),
          child: const Text(
            'Drag to reorder. Your #1 goal drives calories, protein, and meal picks. '
            'Tap + Add goal for blood pressure, muscle gain, more protein — or anything you type.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
          ),
        ),
        Expanded(
          child: _ordered.isEmpty
              ? const Center(child: Text('No goals yet — tap Add goal'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _ordered.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _ordered.removeAt(oldIndex);
                      _ordered.insert(newIndex, item);
                    });
                    ref.read(goalNotifierProvider.notifier).reorderGoals(_ordered);
                  },
                  itemBuilder: (context, index) {
                    final goal = _ordered[index];
                    return _GoalCard(
                      key: ValueKey('${goal.id}_${goal.goalType}'),
                      goal: goal,
                      index: index,
                      onDelete: () async {
                        await ref.read(goalNotifierProvider.notifier).removeGoal(goal.goalType);
                        await ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final HealthGoal goal;
  final int index;
  final VoidCallback onDelete;

  const _GoalCard({
    super.key,
    required this.goal,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: index == 0 ? AppTheme.primaryColor : Colors.grey.shade300,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: index == 0 ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(goal.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.description, style: const TextStyle(fontSize: 12)),
            if (goal.currentValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Current: ${goal.currentValue} ${goal.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
            if (goal.triggeredBy != null)
              Text(
                goal.source == 'user_custom' || goal.source == 'user_added'
                    ? 'Added by you'
                    : 'From: ${goal.triggeredBy}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}
