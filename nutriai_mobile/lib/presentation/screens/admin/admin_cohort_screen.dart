import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_user_detail_screen.dart';
import 'sample_lab_order_screen.dart';

/// Admin view of the illustrative 55-user demo cohort (not clinical research).
class AdminCohortScreen extends ConsumerStatefulWidget {
  const AdminCohortScreen({super.key});

  @override
  ConsumerState<AdminCohortScreen> createState() => _AdminCohortScreenState();
}

class _AdminCohortScreenState extends ConsumerState<AdminCohortScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String? _arcFilter;
  bool? _retestOnly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get(
        ApiConstants.adminCohort,
        queryParameters: {
          if (_arcFilter != null) 'arc': _arcFilter,
          if (_retestOnly == true) 'retest_ready': true,
        },
      );
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

  Future<void> _seed({bool force = false}) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(
        ApiConstants.adminCohortSeed,
        queryParameters: {'force': force},
      );
      await _load();
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

  @override
  Widget build(BuildContext context) {
    final users = (_data?['users'] as List?) ?? [];
    final byArc = Map<String, dynamic>.from((_data?['by_arc'] as Map?) ?? {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo cohort'),
        actions: [
          IconButton(
            tooltip: 'Seed if missing',
            onPressed: _loading ? null : () => _seed(force: false),
            icon: const Icon(Icons.cloud_download),
          ),
          IconButton(
            tooltip: 'Force refresh cohort',
            onPressed: _loading ? null : () => _seed(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        _data?['disclaimer']?.toString() ??
                            'Illustrative multi-persona demo — not clinical research.',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Users', '${_data?['total'] ?? 0}'),
                          _chip('Retest ready', '${_data?['retest_ready'] ?? 0}'),
                          _chip('Meal swaps', '${_data?['with_meal_swap'] ?? 0}'),
                          ...byArc.entries.map((e) => _chip(e.key, '${e.value}')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All arcs'),
                            selected: _arcFilter == null,
                            onSelected: (_) {
                              setState(() => _arcFilter = null);
                              _load();
                            },
                          ),
                          const SizedBox(width: 6),
                          ...['improved', 'mixed', 'flat', 'adjusted', 'early'].map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(a),
                                selected: _arcFilter == a,
                                onSelected: (_) {
                                  setState(() => _arcFilter = a);
                                  _load();
                                },
                              ),
                            ),
                          ),
                          FilterChip(
                            label: const Text('Retest only'),
                            selected: _retestOnly == true,
                            onSelected: (v) {
                              setState(() => _retestOnly = v ? true : null);
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        'Login any cohort user: {slug}@cohort.nutriai.app / ${_data?['password_hint'] ?? 'demo'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          final u = users[i] as Map;
                          final retest = u['retest_ready'] == true;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: retest
                                    ? Colors.orange.shade100
                                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                                child: Icon(
                                  retest ? Icons.science : Icons.person,
                                  color: retest ? Colors.orange.shade800 : AppTheme.primaryColor,
                                ),
                              ),
                              title: Text('${u['name']}'),
                              subtitle: Text(
                                '${u['email']}\n'
                                'arc=${u['arc']} · months=${u['months']} · '
                                'goals=${(u['goals'] as List?)?.join(', ') ?? ''}'
                                '${u['meal_swap'] == true ? ' · meal swap' : ''}'
                                '${retest ? ' · RETEST READY' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    child: const Text('Plans'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminUserDetailScreen(
                                            userId: u['id'] as int,
                                            titleHint: '${u['name']}',
                                          ),
                                        ),
                                      );
                                    },
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
                                              userName: '${u['name']}',
                                              adminView: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminUserDetailScreen(
                                      userId: u['id'] as int,
                                      titleHint: '${u['name']}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.teal.shade50,
    );
  }
}
