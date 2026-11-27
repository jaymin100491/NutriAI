import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_user_detail_screen.dart';
import 'sample_lab_order_screen.dart';

/// Single operations console — overview, patients, cohort — production admin UX.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const AdminConsoleScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  late int _index;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  Map<String, dynamic>? _cohort;
  final _search = TextEditingController();
  String? _arcFilter;
  bool _retestOnly = false;
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, 2);
    _loadAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final stats = await dio.get(ApiConstants.adminStats);
      final users = await dio.get(
        ApiConstants.adminUsers,
        queryParameters: {
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        },
      );
      final cohort = await dio.get(
        ApiConstants.adminCohort,
        queryParameters: {
          if (_arcFilter != null) 'arc': _arcFilter,
          if (_retestOnly) 'retest_ready': true,
        },
      );
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(stats.data as Map);
        _users = (users.data as Map)['users'] as List<dynamic>? ?? [];
        _cohort = Map<String, dynamic>.from(cohort.data as Map);
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

  Future<void> _seedCohort({bool force = false}) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(
        ApiConstants.adminCohortSeed,
        queryParameters: {'force': force},
      );
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(force ? 'Cohort refreshed' : 'Cohort seeded')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openPatient(int id, {String? name}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(userId: id, titleHint: name),
      ),
    ).then((_) => _loadAll());
  }

  List<dynamic> get _filteredUsers {
    var list = List<dynamic>.from(_users);
    if (_activeOnly) {
      list = list.where((u) => (u as Map)['is_active'] == true).toList();
    }
    if (_retestOnly && _index == 1) {
      list = list.where((u) => (u as Map)['retest_ready'] == true).toList();
    }
    if (_arcFilter != null && _index == 1) {
      list = list.where((u) => (u as Map)['outcome_arc'] == _arcFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        title: const Text('NutriAI Operations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _stats == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _stats == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadAll, child: const Text('Retry')),
                    ],
                  ),
                )
              : wide
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: (i) => setState(() => _index = i),
                          labelType: NavigationRailLabelType.all,
                          backgroundColor: Colors.white,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard),
                              label: Text('Overview'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.people_outline),
                              selectedIcon: Icon(Icons.people),
                              label: Text('Patients'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.groups_outlined),
                              selectedIcon: Icon(Icons.groups),
                              label: Text('Cohort'),
                            ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: _body()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _body()),
                        NavigationBar(
                          selectedIndex: _index,
                          onDestinationSelected: (i) => setState(() => _index = i),
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard),
                              label: 'Overview',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.people_outline),
                              selectedIcon: Icon(Icons.people),
                              label: 'Patients',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.groups_outlined),
                              selectedIcon: Icon(Icons.groups),
                              label: 'Cohort',
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }

  Widget _body() {
    switch (_index) {
      case 0:
        return _OverviewPane(
          stats: _stats ?? {},
          users: _users,
          onOpenPatients: () => setState(() => _index = 1),
          onOpenCohort: () => setState(() => _index = 2),
          onOpenPatient: _openPatient,
        );
      case 1:
        return _PatientsPane(
          users: _filteredUsers,
          search: _search,
          activeOnly: _activeOnly,
          retestOnly: _retestOnly,
          arcFilter: _arcFilter,
          loading: _loading,
          onSearch: _loadAll,
          onActiveOnly: (v) => setState(() => _activeOnly = v),
          onRetestOnly: (v) => setState(() => _retestOnly = v),
          onArcFilter: (v) => setState(() => _arcFilter = v),
          onOpen: _openPatient,
        );
      default:
        return _CohortPane(
          data: _cohort ?? {},
          loading: _loading,
          arcFilter: _arcFilter,
          retestOnly: _retestOnly,
          onArcFilter: (v) {
            setState(() => _arcFilter = v);
            _loadAll();
          },
          onRetestOnly: (v) {
            setState(() => _retestOnly = v);
            _loadAll();
          },
          onSeed: () => _seedCohort(force: false),
          onForce: () => _seedCohort(force: true),
          onOpen: _openPatient,
        );
    }
  }
}

class _OverviewPane extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List users;
  final VoidCallback onOpenPatients;
  final VoidCallback onOpenCohort;
  final void Function(int id, {String? name}) onOpenPatient;

  const _OverviewPane({
    required this.stats,
    required this.users,
    required this.onOpenPatients,
    required this.onOpenCohort,
    required this.onOpenPatient,
  });

  @override
  Widget build(BuildContext context) {
    final cohort = Map<String, dynamic>.from((stats['cohort'] as Map?) ?? {});
    final byArc = Map<String, dynamic>.from((cohort['by_arc'] as Map?) ?? {});
    final recent = users.take(8).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Live operations console',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Patient plans, biometrics, labs, and cohort outcomes in one place.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 1000 ? 5 : (c.maxWidth > 700 ? 3 : 2);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _Kpi('Patients', '${stats['users'] ?? 0}', 'Total accounts', Icons.people_alt_outlined),
                _Kpi('Active', '${stats['active_users'] ?? 0}', 'Can sign in', Icons.verified_outlined),
                _Kpi('Diet plans', '${stats['diet_plans'] ?? 0}', 'Weekly plans stored', Icons.restaurant_menu_outlined),
                _Kpi('Biometrics', '${stats['tracking_entries'] ?? 0}', 'Daily check-ins', Icons.monitor_heart_outlined),
                _Kpi('Lab panels', '${stats['lab_results'] ?? 0}', 'Results on file', Icons.science_outlined),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Panel(
                title: 'Demo cohort health',
                trailing: TextButton(onPressed: onOpenCohort, child: const Text('Open cohort')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cohort['total'] ?? 0} personas · ${cohort['retest_ready'] ?? 0} retest-ready · '
                      '${cohort['with_meal_swap'] ?? 0} with meal swaps',
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: byArc.entries
                          .map((e) => Chip(
                                label: Text('${e.key}: ${e.value}'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.teal.shade50,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Jump into a patient',
          trailing: TextButton(onPressed: onOpenPatients, child: const Text('All patients')),
          child: recent.isEmpty
              ? const Text('No users loaded.')
              : Column(
                  children: [
                    for (final raw in recent)
                      Builder(builder: (_) {
                        final u = Map<String, dynamic>.from(raw as Map);
                        final name =
                            '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: Text('${u['id']}', style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(name.isEmpty ? '${u['email']}' : name),
                          subtitle: Text(
                            '${u['email']} · check-in ${u['last_checkin'] ?? '—'} · '
                            'wt ${u['latest_weight_lbs'] ?? '—'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => onOpenPatient(
                            u['id'] as int,
                            name: name.isEmpty ? null : name,
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PatientsPane extends StatelessWidget {
  final List users;
  final TextEditingController search;
  final bool activeOnly;
  final bool retestOnly;
  final String? arcFilter;
  final bool loading;
  final VoidCallback onSearch;
  final ValueChanged<bool> onActiveOnly;
  final ValueChanged<bool> onRetestOnly;
  final ValueChanged<String?> onArcFilter;
  final void Function(int id, {String? name}) onOpen;

  const _PatientsPane({
    required this.users,
    required this.search,
    required this.activeOnly,
    required this.retestOnly,
    required this.arcFilter,
    required this.loading,
    required this.onSearch,
    required this.onActiveOnly,
    required this.onRetestOnly,
    required this.onArcFilter,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: search,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: onSearch),
                ),
                onSubmitted: (_) => onSearch(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Active only'),
                    selected: activeOnly,
                    onSelected: onActiveOnly,
                  ),
                  FilterChip(
                    label: const Text('Retest ready'),
                    selected: retestOnly,
                    onSelected: onRetestOnly,
                  ),
                  for (final arc in ['improved', 'mixed', 'adjusted', 'flat', 'early'])
                    ChoiceChip(
                      label: Text(arc),
                      selected: arcFilter == arc,
                      onSelected: (v) => onArcFilter(v ? arc : null),
                    ),
                  Text('${users.length} shown', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: users.isEmpty
              ? const Center(child: Text('No patients match these filters.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = Map<String, dynamic>.from(users[i] as Map);
                    final stats = Map<String, dynamic>.from((u['stats'] as Map?) ?? {});
                    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                    final active = u['is_active'] as bool? ?? true;
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpen(u['id'] as int, name: name.isEmpty ? null : name),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '#',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty ? '${u['email']}' : name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${u['email']}',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _TinyPill(active ? 'Active' : 'Inactive',
                                            active ? const Color(0xFF0F7B3F) : const Color(0xFFB42318)),
                                        if (u['outcome_arc'] != null)
                                          _TinyPill('${u['outcome_arc']}', const Color(0xFF175CD3)),
                                        if (u['retest_ready'] == true)
                                          const _TinyPill('Retest', Color(0xFFB54708)),
                                        _TinyPill(
                                          'Plans ${stats['diet_plans'] ?? 0}',
                                          const Color(0xFF344054),
                                        ),
                                        _TinyPill(
                                          'Bio ${stats['tracking_entries'] ?? 0}',
                                          const Color(0xFF344054),
                                        ),
                                        if (u['latest_weight_lbs'] != null)
                                          _TinyPill('Wt ${u['latest_weight_lbs']}', const Color(0xFF344054)),
                                        if (u['last_checkin'] != null)
                                          _TinyPill('Last ${u['last_checkin']}', const Color(0xFF344054)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CohortPane extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool loading;
  final String? arcFilter;
  final bool retestOnly;
  final ValueChanged<String?> onArcFilter;
  final ValueChanged<bool> onRetestOnly;
  final VoidCallback onSeed;
  final VoidCallback onForce;
  final void Function(int id, {String? name}) onOpen;

  const _CohortPane({
    required this.data,
    required this.loading,
    required this.arcFilter,
    required this.retestOnly,
    required this.onArcFilter,
    required this.onRetestOnly,
    required this.onSeed,
    required this.onForce,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final users = (data['users'] as List?) ?? [];
    final byArc = Map<String, dynamic>.from((data['by_arc'] as Map?) ?? {});

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Illustrative 55-persona cohort',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  OutlinedButton(onPressed: loading ? null : onSeed, child: const Text('Seed')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: loading ? null : onForce, child: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${data['total'] ?? users.length} personas · '
                '${data['retest_ready'] ?? 0} retest-ready · '
                '${data['with_meal_swap'] ?? 0} meal swaps',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Retest ready'),
                    selected: retestOnly,
                    onSelected: onRetestOnly,
                  ),
                  for (final e in byArc.entries)
                    ChoiceChip(
                      label: Text('${e.key} (${e.value})'),
                      selected: arcFilter == e.key,
                      onSelected: (v) => onArcFilter(v ? e.key.toString() : null),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = Map<String, dynamic>.from(users[i] as Map);
              final retest = u['retest_ready'] == true;
              final name = '${u['name'] ?? ''}';
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: retest ? Colors.orange.shade50 : AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: Icon(
                      retest ? Icons.science : Icons.person,
                      color: retest ? Colors.orange.shade800 : AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${u['email'] ?? ''} · arc=${u['arc'] ?? '—'} · '
                    'diet=${u['diet'] ?? '—'}'
                    '${retest ? ' · RETEST READY' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        child: const Text('Workspace'),
                        onPressed: () => onOpen(u['id'] as int, name: name),
                      ),
                      if (retest)
                        TextButton(
                          child: const Text('Lab order'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SampleLabOrderScreen(
                                  userId: u['id'] as int,
                                  userName: name,
                                  adminView: true,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  onTap: () => onOpen(u['id'] as int, name: name),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  const _Kpi(this.label, this.value, this.hint, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(hint, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String label;
  final Color color;
  const _TinyPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
