import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import 'sample_lab_order_screen.dart';

/// Production-style admin patient workspace: overview, biometrics, plans, labs, care.
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
  bool _acting = false;
  String? _error;
  Map<String, dynamic>? _data;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
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

  Future<void> _generateWeek({required bool nextWeek}) async {
    setState(() => _acting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(
        '${ApiConstants.adminUsers}/${widget.userId}/generate-week',
        queryParameters: {'next_week': nextWeek},
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextWeek ? 'Next-week plan released' : 'Current week plan regenerated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _toggleActive() async {
    final user = (_data?['user'] as Map?) ?? {};
    final active = user['is_active'] as bool? ?? true;
    setState(() => _acting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.patch(
        '${ApiConstants.adminUsers}/${widget.userId}',
        data: {'is_active': !active},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from((_data?['user'] as Map?) ?? {});
    final prefs = Map<String, dynamic>.from((_data?['preferences'] as Map?) ?? {});
    final bio = Map<String, dynamic>.from((_data?['biometric_summary'] as Map?) ?? {});
    final plans = (_data?['diet_plans'] as List?) ?? [];
    final labs = (_data?['lab_results'] as List?) ?? [];
    final goals = (_data?['goals'] as List?) ?? [];
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final title = name.isNotEmpty ? name : (widget.titleHint ?? 'Patient ${widget.userId}');
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (!_loading && _error == null)
              Text(
                user['email']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _acting ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: !wide,
                indicatorColor: Colors.white,
                tabs: [
                  const Tab(text: 'Overview'),
                  Tab(text: 'Biometrics (${bio['entry_count'] ?? 0})'),
                  Tab(text: 'Plans (${plans.length})'),
                  Tab(text: 'Labs (${labs.length})'),
                  Tab(text: 'Care (${goals.length})'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    _PatientHeader(
                      user: user,
                      prefs: prefs,
                      bio: bio,
                      currentPlan: (_data?['current_plan_summary'] as Map?)?.cast<String, dynamic>(),
                      acting: _acting,
                      onGenerateThisWeek: () => _generateWeek(nextWeek: false),
                      onGenerateNextWeek: () => _generateWeek(nextWeek: true),
                      onToggleActive: _toggleActive,
                      onLabOrder: prefs['retest_ready'] == true
                          ? () {
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
                            }
                          : null,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _OverviewTab(
                            user: user,
                            prefs: prefs,
                            bio: bio,
                            currentPlan: (_data?['current_plan_summary'] as Map?)
                                ?.cast<String, dynamic>(),
                            goals: goals,
                            labs: labs,
                            onOpenBiometrics: () => _tabs.animateTo(1),
                            onOpenPlans: () => _tabs.animateTo(2),
                            onOpenLabs: () => _tabs.animateTo(3),
                          ),
                          _BiometricsTab(bio: bio),
                          _PlansTab(plans: plans),
                          _LabsTab(labs: labs),
                          _CareTab(
                            goals: goals,
                            prefs: prefs,
                            acting: _acting,
                            onGenerateThisWeek: () => _generateWeek(nextWeek: false),
                            onGenerateNextWeek: () => _generateWeek(nextWeek: true),
                            onToggleActive: _toggleActive,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> prefs;
  final Map<String, dynamic> bio;
  final Map<String, dynamic>? currentPlan;
  final bool acting;
  final VoidCallback onGenerateThisWeek;
  final VoidCallback onGenerateNextWeek;
  final VoidCallback onToggleActive;
  final VoidCallback? onLabOrder;

  const _PatientHeader({
    required this.user,
    required this.prefs,
    required this.bio,
    required this.currentPlan,
    required this.acting,
    required this.onGenerateThisWeek,
    required this.onGenerateNextWeek,
    required this.onToggleActive,
    required this.onLabOrder,
  });

  @override
  Widget build(BuildContext context) {
    final latest = Map<String, dynamic>.from((bio['latest'] as Map?) ?? {});
    final active = user['is_active'] as bool? ?? true;
    final arc = (prefs['outcome_arc'] ?? user['outcome_arc'] ?? '—').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                label: active ? 'Active' : 'Inactive',
                color: active ? const Color(0xFF0F7B3F) : const Color(0xFFB42318),
              ),
              _StatusPill(label: 'Role · ${(user['role'] ?? 'user').toString().toUpperCase()}'),
              _StatusPill(label: 'Arc · ${arc.replaceAll('_', ' ')}'),
              if (prefs['retest_ready'] == true)
                const _StatusPill(label: 'Retest ready', color: Color(0xFFB54708)),
              _StatusPill(
                label:
                    'Diet · ${(prefs['dietary_preference'] ?? user['dietary_preference'] ?? '—').toString()}',
              ),
              if (latest['date'] != null) _StatusPill(label: 'Last check-in · ${latest['date']}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: acting ? null : onGenerateThisWeek,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Regenerate this week'),
              ),
              OutlinedButton.icon(
                onPressed: acting ? null : onGenerateNextWeek,
                icon: const Icon(Icons.event, size: 18),
                label: const Text('Release next week'),
              ),
              if (onLabOrder != null)
                OutlinedButton.icon(
                  onPressed: acting ? null : onLabOrder,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Sample lab order'),
                ),
              TextButton(
                onPressed: acting ? null : onToggleActive,
                child: Text(active ? 'Deactivate' : 'Activate'),
              ),
            ],
          ),
          if (currentPlan != null) ...[
            const SizedBox(height: 10),
            Text(
              'Current plan · ${currentPlan!['title'] ?? 'Weekly plan'} · '
              '${currentPlan!['week_start'] ?? '?'} → ${currentPlan!['week_end'] ?? '?'} · '
              '${currentPlan!['target_calories'] ?? '—'} kcal · '
              '${currentPlan!['meal_count'] ?? 0} meals',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> prefs;
  final Map<String, dynamic> bio;
  final Map<String, dynamic>? currentPlan;
  final List goals;
  final List labs;
  final VoidCallback onOpenBiometrics;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenLabs;

  const _OverviewTab({
    required this.user,
    required this.prefs,
    required this.bio,
    required this.currentPlan,
    required this.goals,
    required this.labs,
    required this.onOpenBiometrics,
    required this.onOpenPlans,
    required this.onOpenLabs,
  });

  @override
  Widget build(BuildContext context) {
    final latest = Map<String, dynamic>.from((bio['latest'] as Map?) ?? {});
    final deltas = Map<String, dynamic>.from(
      ((bio['deltas'] as Map?)?['vs_baseline'] as Map?) ?? {},
    );
    final weekly = (bio['weekly'] as List?) ?? [];
    final cuisines = ((prefs['cuisine_preferences'] as List?) ?? []).join(', ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cols == 1 ? 2.8 : 1.7,
              children: [
                _MetricCard(
                  label: 'Weight',
                  value: latest['weight_lbs'] != null ? '${latest['weight_lbs']} lbs' : '—',
                  hint: _deltaLabel(deltas['weight_lbs'], 'vs baseline'),
                  onTap: onOpenBiometrics,
                ),
                _MetricCard(
                  label: 'Blood pressure',
                  value: latest['systolic_bp'] != null
                      ? '${latest['systolic_bp']}/${latest['diastolic_bp'] ?? '—'}'
                      : '—',
                  hint: _deltaLabel(deltas['systolic_bp'], 'sys vs baseline'),
                  onTap: onOpenBiometrics,
                ),
                _MetricCard(
                  label: 'Glucose',
                  value: latest['blood_glucose'] != null ? '${latest['blood_glucose']} mg/dL' : '—',
                  hint: _deltaLabel(deltas['blood_glucose'], 'vs baseline'),
                  onTap: onOpenBiometrics,
                ),
                _MetricCard(
                  label: 'Adherence',
                  value: latest['adherence_percent'] != null
                      ? '${latest['adherence_percent']}%'
                      : '—',
                  hint: '${bio['entry_count'] ?? 0} check-ins logged',
                  onTap: onOpenBiometrics,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickPanel(
                title: 'Care snapshot',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Goals', '${goals.length} active care goals'),
                    _kv('Labs', '${labs.length} panels on file'),
                    _kv('Plans', '${(user['stats'] as Map?)?['diet_plans'] ?? '—'} weekly plans'),
                    _kv('Cuisines', cuisines.isEmpty ? '—' : cuisines),
                    if (currentPlan != null)
                      _kv(
                        'This week',
                        '${currentPlan!['week_start'] ?? '?'} → ${currentPlan!['week_end'] ?? '?'}',
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(onPressed: onOpenPlans, child: const Text('Open plans')),
                        TextButton(onPressed: onOpenLabs, child: const Text('Open labs')),
                        TextButton(onPressed: onOpenBiometrics, child: const Text('Open biometrics')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _QuickPanel(
          title: 'Recent weekly biometric averages',
          child: weekly.isEmpty
              ? const Text('No biometric history yet.', style: TextStyle(color: Colors.grey))
              : Column(
                  children: [
                    for (final w in weekly.take(6))
                      _WeeklyRow(week: Map<String, dynamic>.from(w as Map)),
                  ],
                ),
        ),
      ],
    );
  }

  String _deltaLabel(dynamic v, String suffix) {
    if (v == null) return suffix;
    final n = (v as num).toDouble();
    final sign = n > 0 ? '+' : '';
    return '$sign${n.toStringAsFixed(n.abs() >= 10 ? 0 : 1)} $suffix';
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _BiometricsTab extends StatefulWidget {
  final Map<String, dynamic> bio;
  const _BiometricsTab({required this.bio});

  @override
  State<_BiometricsTab> createState() => _BiometricsTabState();
}

class _BiometricsTabState extends State<_BiometricsTab> {
  String _view = 'weekly'; // weekly | daily

  @override
  Widget build(BuildContext context) {
    final weekly = (widget.bio['weekly'] as List?) ?? [];
    final daily = (widget.bio['daily'] as List?) ?? [];
    final chronDaily = daily.reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly'), icon: Icon(Icons.calendar_view_week, size: 16)),
                ButtonSegment(value: 'daily', label: Text('Daily'), icon: Icon(Icons.today, size: 16)),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
            const Spacer(),
            Text(
              '${widget.bio['entry_count'] ?? 0} entries',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (chronDaily.isNotEmpty) ...[
          _ChartCard(
            title: 'Weight trend',
            child: _simpleLine(
              chronDaily,
              (e) => (e['weight_lbs'] as num?)?.toDouble(),
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Systolic BP',
            child: _simpleLine(
              chronDaily,
              (e) => (e['systolic_bp'] as num?)?.toDouble(),
              color: const Color(0xFFB42318),
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Blood glucose',
            child: _simpleLine(
              chronDaily,
              (e) => (e['blood_glucose'] as num?)?.toDouble(),
              color: const Color(0xFFB54708),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_view == 'weekly')
          if (weekly.isEmpty)
            const _EmptyBlock('No weekly biometric averages yet.')
          else
            for (var i = 0; i < weekly.length; i++)
              Builder(builder: (_) {
                final m = Map<String, dynamic>.from(weekly[i] as Map);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    title: Text(m['label']?.toString() ?? '${m['week_start']}'),
                    subtitle: Text(
                      '${m['entries'] ?? 0} check-ins · '
                      'wt ${m['avg_weight_lbs'] ?? '—'} · '
                      'BP ${m['avg_systolic_bp'] ?? '—'}/${m['avg_diastolic_bp'] ?? '—'} · '
                      'glu ${m['avg_blood_glucose'] ?? '—'} · '
                      'sleep ${m['avg_sleep_hours'] ?? '—'}h · '
                      'adh ${m['avg_adherence_percent'] ?? '—'}%',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MiniStat('Avg weight', '${m['avg_weight_lbs'] ?? '—'} lbs'),
                            _MiniStat('Avg BP', '${m['avg_systolic_bp'] ?? '—'}/${m['avg_diastolic_bp'] ?? '—'}'),
                            _MiniStat('Avg glucose', '${m['avg_blood_glucose'] ?? '—'}'),
                            _MiniStat('Avg sleep', '${m['avg_sleep_hours'] ?? '—'} h'),
                            _MiniStat('Avg adherence', '${m['avg_adherence_percent'] ?? '—'}%'),
                            _MiniStat('Avg mood', '${m['avg_mood'] ?? '—'}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              })
        else if (daily.isEmpty)
          const _EmptyBlock('No daily biometric entries yet.')
        else
          for (final d in daily)
            Builder(builder: (_) {
              final m = Map<String, dynamic>.from(d as Map);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: const Icon(Icons.monitor_heart_outlined, color: AppTheme.primaryColor, size: 20),
                  ),
                  title: Text(m['date']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Weight ${m['weight_lbs'] ?? '—'} lbs · '
                    'BP ${m['systolic_bp'] ?? '—'}/${m['diastolic_bp'] ?? '—'} · '
                    'Glu ${m['blood_glucose'] ?? '—'} · '
                    'Sleep ${m['sleep_hours'] ?? '—'}h · '
                    'Adherence ${m['adherence_percent'] ?? '—'}%'
                    '${m['notes'] != null ? '\n${m['notes']}' : ''}',
                    style: const TextStyle(height: 1.35),
                  ),
                  isThreeLine: m['notes'] != null,
                ),
              );
            }),
      ],
    );
  }

  Widget _simpleLine(
    List entries,
    double? Function(Map<String, dynamic>) extractor, {
    required Color color,
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final m = Map<String, dynamic>.from(entries[i] as Map);
      final v = extractor(m);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Not enough points to chart', style: TextStyle(color: Colors.grey))),
      );
    }
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansTab extends StatelessWidget {
  final List plans;
  const _PlansTab({required this.plans});

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _EmptyBlock('No diet plans stored for this patient.');
    final sorted = List<Map>.from(plans.map((e) => Map<String, dynamic>.from(e as Map)));
    sorted.sort((a, b) {
      final ac = a['is_current'] == true ? 1 : 0;
      final bc = b['is_current'] == true ? 1 : 0;
      if (ac != bc) return bc.compareTo(ac);
      return '${b['created_at']}'.compareTo('${a['created_at']}');
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
              isCurrent ? Icons.star_rounded : Icons.history,
              color: isCurrent ? AppTheme.primaryColor : Colors.grey,
            ),
            title: Text(
              '${payload['title'] ?? 'Diet plan'}',
              style: TextStyle(fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
            ),
            subtitle: Text(
              '${isCurrent ? 'CURRENT' : 'PAST'} · '
              '${payload['week_start'] ?? payload['start_date'] ?? '?'} → '
              '${payload['week_end'] ?? payload['end_date'] ?? '?'} · '
              '${payload['target_calories'] ?? '—'} kcal · ${meals.length} meals',
            ),
            children: [
              if (payload['ai_rationale'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('${payload['ai_rationale']}', style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ),
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Plan biometric notes: ${bio.join(' · ')}', style: const TextStyle(fontSize: 12)),
                ),
              if (swap is Map)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Meal swap: ${swap['original']} → ${swap['replacement']} (${swap['reason']})',
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                  ),
                ),
              const Divider(height: 1),
              ...meals.take(28).map((m) {
                final meal = Map<String, dynamic>.from(m as Map);
                final recipe = Map<String, dynamic>.from((meal['recipe'] as Map?) ?? {});
                return ListTile(
                  dense: true,
                  title: Text(
                    'Day ${meal['day']} ${meal['weekday'] ?? ''} · ${meal['meal_type']}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${recipe['name'] ?? 'Meal'}'
                    '${recipe['cuisine_type'] != null ? ' · ${recipe['cuisine_type']}' : ''}'
                    '${meal['substituted'] == true ? ' · SWAPPED' : ''}',
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _LabsTab extends StatelessWidget {
  final List labs;
  const _LabsTab({required this.labs});

  @override
  Widget build(BuildContext context) {
    if (labs.isEmpty) return const _EmptyBlock('No lab results on file.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: labs.length,
      itemBuilder: (context, i) {
        final lab = Map<String, dynamic>.from(labs[i] as Map);
        final tests = ((lab['results'] as Map?)?['tests'] as List?) ??
            (lab['tests'] as List?) ??
            [];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: i == 0,
            title: Text('${lab['panel_title'] ?? lab['test_type'] ?? 'Lab panel'}'),
            subtitle: Text('Date: ${lab['test_date'] ?? '—'} · ${tests.length} markers'),
            children: tests.take(40).map((t) {
              final m = Map<String, dynamic>.from(t as Map);
              final status = (m['status'] ?? '').toString().toLowerCase();
              final color = status.contains('high') || status.contains('low') || status.contains('abnormal')
                  ? const Color(0xFFB42318)
                  : Colors.grey.shade700;
              return ListTile(
                dense: true,
                title: Text('${m['name']}'),
                subtitle: Text('${m['value']} ${m['unit'] ?? ''} · ${m['status'] ?? ''}',
                    style: TextStyle(color: color)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CareTab extends StatelessWidget {
  final List goals;
  final Map<String, dynamic> prefs;
  final bool acting;
  final VoidCallback onGenerateThisWeek;
  final VoidCallback onGenerateNextWeek;
  final VoidCallback onToggleActive;

  const _CareTab({
    required this.goals,
    required this.prefs,
    required this.acting,
    required this.onGenerateThisWeek,
    required this.onGenerateNextWeek,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _QuickPanel(
          title: 'Care actions',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: acting ? null : onGenerateThisWeek,
                child: const Text('Regenerate this week'),
              ),
              OutlinedButton(
                onPressed: acting ? null : onGenerateNextWeek,
                child: const Text('Friday release (next week)'),
              ),
              TextButton(onPressed: acting ? null : onToggleActive, child: const Text('Toggle account status')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _QuickPanel(
          title: 'Preferences',
          child: Text(
            'Diet: ${prefs['dietary_preference'] ?? '—'}\n'
            'Cuisines: ${((prefs['cuisine_preferences'] as List?) ?? []).join(', ').ifEmpty('—')}\n'
            'Allergies: ${((prefs['allergies'] as List?) ?? []).join(', ').ifEmpty('—')}\n'
            'Arc: ${prefs['outcome_arc'] ?? '—'} · Retest: ${prefs['retest_ready'] == true}',
            style: const TextStyle(height: 1.45, fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Goals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          const _EmptyBlock('No goals configured.')
        else
          ...goals.map((g) {
            final m = Map<String, dynamic>.from(g as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${m['label'] ?? m['goal_type']}'),
                subtitle: Text(
                  'Priority ${m['priority'] ?? '—'} · ${m['status'] ?? 'active'}\n'
                  '${m['notes'] ?? m['description'] ?? ''}',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  )),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _QuickPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WeeklyRow extends StatelessWidget {
  final Map<String, dynamic> week;
  const _WeeklyRow({required this.week});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(week['label']?.toString() ?? '', style: const TextStyle(fontSize: 12.5)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'wt ${week['avg_weight_lbs'] ?? '—'} · '
              'BP ${week['avg_systolic_bp'] ?? '—'}/${week['avg_diastolic_bp'] ?? '—'} · '
              'glu ${week['avg_blood_glucose'] ?? '—'}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, this.color = const Color(0xFF344054)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final String message;
  const _EmptyBlock(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
