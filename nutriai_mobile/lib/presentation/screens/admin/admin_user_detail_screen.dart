import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import 'sample_lab_order_screen.dart';

/// Admin: full detail for one user — current + past diet plans, goals, labs.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;
  final String? titleHint;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.titleHint,
  });

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('${ApiConstants.adminUsers}/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(res.data as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (_data?['user'] as Map?) ?? {};
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final title = name.isNotEmpty ? name : (widget.titleHint ?? 'User ${widget.userId}');
    final plans = (_data?['diet_plans'] as List?) ?? [];
    final prefs = (_data?['preferences'] as Map?) ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'Plans (${plans.length})'),
                  Tab(text: 'Goals'),
                  Tab(text: 'Labs'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.teal.shade50,
                      child: Text(
                        '${user['email']}\n'
                        'role=${user['role']} · active=${user['is_active']} · '
                        'arc=${prefs['outcome_arc'] ?? '—'} · '
                        'retest=${prefs['retest_ready'] == true} · '
                        'diet=${prefs['dietary_preference'] ?? '—'} · '
                        'cuisines=${((prefs['cuisine_preferences'] as List?) ?? []).join(", ")}',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                    if (prefs['retest_ready'] == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SampleLabOrderScreen(
                                  userId: widget.userId,
                                  userName: title,
                                  adminView: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.science),
                          label: const Text('Open sample lab order'),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _PlansTab(plans: plans),
                          _GoalsTab(goals: (_data?['goals'] as List?) ?? []),
                          _LabsTab(labs: (_data?['lab_results'] as List?) ?? []),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PlansTab extends StatelessWidget {
  final List plans;
  const _PlansTab({required this.plans});

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Center(child: Text('No diet plans stored for this user.'));
    }
    final sorted = List<Map>.from(plans.map((e) => Map<String, dynamic>.from(e as Map)));
    sorted.sort((a, b) {
      final ac = a['is_current'] == true ? 1 : 0;
      final bc = b['is_current'] == true ? 1 : 0;
      if (ac != bc) return bc.compareTo(ac);
      return '${b['created_at']}'.compareTo('${a['created_at']}');
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final p = sorted[i];
        final payload = Map<String, dynamic>.from((p['payload'] as Map?) ?? {});
        final isCurrent = p['is_current'] == true;
        final meals = (payload['meals'] as List?) ?? [];
        final bio = (payload['biometric_notes'] as List?) ?? [];
        final swap = payload['meal_substitution'];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: isCurrent || i == 0,
            leading: Icon(
              isCurrent ? Icons.star : Icons.history,
              color: isCurrent ? AppTheme.primaryColor : Colors.grey,
            ),
            title: Text(
              '${payload['title'] ?? 'Diet plan'}',
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${isCurrent ? "CURRENT · " : "PAST · "}'
              '${payload['week_start'] ?? payload['start_date'] ?? "?"} → '
              '${payload['week_end'] ?? payload['end_date'] ?? "?"} · '
              '${payload['target_calories'] ?? "—"} kcal · '
              '${meals.length} meals · created ${p['created_at'] ?? "—"}',
            ),
            children: [
              if (payload['ai_rationale'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('${payload['ai_rationale']}', style: const TextStyle(fontSize: 12, height: 1.35)),
                ),
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Biometrics: ${bio.join(" · ")}', style: const TextStyle(fontSize: 12)),
                ),
              if (swap is Map)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Meal swap: ${swap['original']} → ${swap['replacement']} (${swap['reason']})',
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                  ),
                ),
              const Divider(),
              ...meals.take(28).map((m) {
                final meal = Map<String, dynamic>.from(m as Map);
                final recipe = Map<String, dynamic>.from((meal['recipe'] as Map?) ?? {});
                return ListTile(
                  dense: true,
                  title: Text(
                    'Day ${meal['day']} ${meal['weekday'] ?? ''} · ${meal['meal_type']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${recipe['name'] ?? "Meal"}'
                    '${recipe['cuisine_type'] != null ? " · ${recipe['cuisine_type']}" : ""}'
                    '${meal['substituted'] == true ? " · SWAPPED" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
              if (meals.length > 28)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Showing first 28 meals…'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GoalsTab extends StatelessWidget {
  final List goals;
  const _GoalsTab({required this.goals});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const Center(child: Text('No goals'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: goals.map((g) {
        final m = Map<String, dynamic>.from(g as Map);
        return Card(
          child: ListTile(
            title: Text('${m['label'] ?? m['goal_type']}'),
            subtitle: Text(
              'priority ${m['priority']} · status=${m['status'] ?? "—"} · '
              '${m['notes'] ?? m['description'] ?? ""}',
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LabsTab extends StatelessWidget {
  final List labs;
  const _LabsTab({required this.labs});

  @override
  Widget build(BuildContext context) {
    if (labs.isEmpty) return const Center(child: Text('No lab results'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: labs.length,
      itemBuilder: (context, i) {
        final lab = Map<String, dynamic>.from(labs[i] as Map);
        final tests = ((lab['results'] as Map?)?['tests'] as List?) ?? [];
        return Card(
          child: ExpansionTile(
            title: Text('${lab['panel_title'] ?? lab['test_type'] ?? "Lab panel"}'),
            subtitle: Text('Date: ${lab['test_date'] ?? "—"} · ${tests.length} markers'),
            children: tests.take(20).map((t) {
              final m = Map<String, dynamic>.from(t as Map);
              return ListTile(
                dense: true,
                title: Text('${m['name']}'),
                subtitle: Text('${m['value']} ${m['unit'] ?? ""} · ${m['status'] ?? ""}'),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
