import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(stats.data as Map);
        _users = (users.data as Map)['users'] as List<dynamic>? ?? [];
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

  Future<void> _openUser(int userId) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('${ApiConstants.adminUsers}/$userId');
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (context, controller) {
            final user = data['user'] as Map? ?? {};
            final plans = data['diet_plans'] as List? ?? [];
            final labs = data['lab_results'] as List? ?? [];
            final tracking = data['tracking'] as List? ?? [];
            final goals = data['goals'] as List? ?? [];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('${user['email']} · role=${user['role']} · active=${user['is_active']}'),
                const SizedBox(height: 12),
                Text('Goals: ${goals.length} · Labs: ${labs.length} · Plans: ${plans.length} · Tracking: ${tracking.length}'),
                const Divider(),
                const Text('Recent plans', style: TextStyle(fontWeight: FontWeight.bold)),
                ...plans.take(5).map((p) {
                  final payload = (p as Map)['payload'] as Map? ?? {};
                  return ListTile(
                    dense: true,
                    title: Text('${payload['title'] ?? 'Plan'}'),
                    subtitle: Text(
                      '${payload['week_start'] ?? ''} → ${payload['week_end'] ?? ''} · '
                      '${payload['target_calories'] ?? ''} kcal · current=${p['is_current']}',
                    ),
                  );
                }),
                const Divider(),
                const Text('Goals', style: TextStyle(fontWeight: FontWeight.bold)),
                ...goals.take(8).map((g) {
                  final m = g as Map;
                  return ListTile(
                    dense: true,
                    title: Text('${m['label'] ?? m['goal_type']}'),
                    subtitle: Text('priority ${m['priority']} · ${m['source']}'),
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await dio.post(
                      '${ApiConstants.adminUsers}/$userId/generate-week',
                      queryParameters: {'next_week': false},
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Weekly plan regenerated for user')),
                    );
                    _load();
                  },
                  child: const Text('Generate this week plan'),
                ),
                TextButton(
                  onPressed: () async {
                    await dio.patch(
                      '${ApiConstants.adminUsers}/$userId',
                      data: {'is_active': !(user['is_active'] as bool? ?? true)},
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _load();
                    }
                  },
                  child: Text((user['is_active'] as bool? ?? true) ? 'Deactivate user' : 'Activate user'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · Users'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_stats != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _chip('Users', '${_stats!['users']}'),
                            _chip('Active', '${_stats!['active_users']}'),
                            _chip('Labs', '${_stats!['lab_results']}'),
                            _chip('Plans', '${_stats!['diet_plans']}'),
                            _chip('Tracking', '${_stats!['tracking_entries']}'),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Search email or name',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _load,
                          ),
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u = _users[i] as Map;
                          final stats = u['stats'] as Map? ?? {};
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Text('${u['id']}'),
                            ),
                            title: Text('${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim().isEmpty
                                ? '${u['email']}'
                                : '${u['first_name']} ${u['last_name']}'),
                            subtitle: Text(
                              '${u['email']}\n'
                              'role=${u['role']} · labs=${stats['lab_results']} · '
                              'plans=${stats['diet_plans']} · track=${stats['tracking_entries']}',
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              (u['is_active'] as bool? ?? true) ? Icons.check_circle : Icons.block,
                              color: (u['is_active'] as bool? ?? true) ? Colors.green : Colors.red,
                            ),
                            onTap: () => _openUser(u['id'] as int),
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
