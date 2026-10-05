import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/diet_plan_provider.dart';

class DietaryPreferencesScreen extends ConsumerStatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  ConsumerState<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState
    extends ConsumerState<DietaryPreferencesScreen> {
  static const _dietOptions = [
    ('omnivore', 'Omnivore', 'Meat, fish, dairy, and plants'),
    ('pescatarian', 'Pescatarian', 'Fish and plants — no meat'),
    ('vegetarian', 'Vegetarian', 'No meat or fish'),
    ('vegan', 'Vegan', 'Plant-based only'),
  ];

  static const _cuisineOptions = [
    'Indian',
    'Mediterranean',
    'Mexican',
    'Thai',
    'Japanese',
    'Italian',
    'Middle Eastern',
    'Asian',
  ];

  String _dietaryPreference = 'omnivore';
  final Set<String> _cuisines = {};
  final List<String> _dislikes = [];
  final _dislikeController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dislikeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs =
          await ref.read(dietPlanRepositoryProvider).getPreferences();
      if (!mounted) return;
      setState(() {
        _dietaryPreference =
            (prefs['dietary_preference'] as String?) ?? 'omnivore';
        _cuisines
          ..clear()
          ..addAll(
            ((prefs['cuisine_preferences'] as List?) ?? const [])
                .map((e) => e.toString()),
          );
        _dislikes
          ..clear()
          ..addAll(
            ((prefs['dislikes'] as List?) ?? const []).map((e) => e.toString()),
          );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(dietPlanNotifierProvider.notifier).updatePreferences(
            dietaryPreference: _dietaryPreference,
            cuisinePreferences: _cuisines.toList(),
            dislikes: _dislikes,
            regeneratePlan: true,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _dietaryPreference == 'vegetarian' || _dietaryPreference == 'vegan'
                ? 'Saved — regenerating a $_dietaryPreference meal plan…'
                : 'Saved — your meal plan was regenerated for $_dietaryPreference.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save preferences: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addDislike() {
    final value = _dislikeController.text.trim().toLowerCase();
    if (value.isEmpty) return;
    setState(() {
      if (!_dislikes.contains(value)) _dislikes.add(value);
      _dislikeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dietary Preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'How do you eat?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We’ll rebuild your 7-day plan when you save — veg, non-veg, or plant-based.',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                ..._dietOptions.map((opt) {
                  final (value, label, subtitle) = opt;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<String>(
                      value: value,
                      groupValue: _dietaryPreference,
                      title: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(subtitle),
                      onChanged: (v) {
                        if (v != null) setState(() => _dietaryPreference = v);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 24),
                const Text(
                  'Favorite cuisines',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cuisineOptions.map((c) {
                    final selected = _cuisines.contains(c);
                    return FilterChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _cuisines.add(c);
                          } else {
                            _cuisines.remove(c);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Foods you don’t like',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dislikeController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. shrimp, mushrooms, cilantro',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addDislike(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addDislike,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dislikes
                      .map(
                        (d) => Chip(
                          label: Text(d),
                          onDeleted: () =>
                              setState(() => _dislikes.remove(d)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save & regenerate meal plan'),
                ),
              ],
            ),
    );
  }
}
