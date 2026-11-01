import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_user_detail_screen.dart';

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

  void _openUser(int userId, {String? nameHint}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(
          userId: userId,
          titleHint: nameHint,
        ),
      ),
    );
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
                            onTap: () => _openUser(
                              u['id'] as int,
                              nameHint:
                                  '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim(),
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
