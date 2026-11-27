import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

/// Sample Labcorp-style wellness lab order (DEMO ONLY).
class SampleLabOrderScreen extends ConsumerStatefulWidget {
  final int? userId;
  final String userName;
  /// When true (admin viewing another user), call admin lab-order API.
  final bool adminView;

  const SampleLabOrderScreen({
    super.key,
    this.userId,
    required this.userName,
    this.adminView = false,
  });

  @override
  ConsumerState<SampleLabOrderScreen> createState() => _SampleLabOrderScreenState();
}

class _SampleLabOrderScreenState extends ConsumerState<SampleLabOrderScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;

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
      final path = widget.adminView && widget.userId != null
          ? '${ApiConstants.adminUsers}/${widget.userId}/lab-order'
          : ApiConstants.sampleLabOrder;
      final res = await dio.get(path);
      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(res.data as Map);
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
    final o = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sample lab order · ${widget.userName}'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : o == null
                  ? const Center(child: Text('No order'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          color: Colors.red.shade700,
                          child: Text(
                            o['banner']?.toString() ?? 'DEMO ONLY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          o['form_title']?.toString() ?? 'Laboratory Request (SAMPLE)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (o['lab_header'] as Map?)?['organization']?.toString() ?? '',
                          style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                        ),
                        Text((o['lab_header'] as Map?)?['address']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        _box(
                          'Patient',
                          [
                            'Name: ${(o['patient'] as Map?)?['name']}',
                            'Email: ${(o['patient'] as Map?)?['email']}',
                            'Sex/Age: ${(o['patient'] as Map?)?['sex']} / ${(o['patient'] as Map?)?['age']}',
                            '${(o['patient'] as Map?)?['address_line']}',
                          ],
                        ),
                        _box(
                          'Physician (demo)',
                          [
                            '${(o['physician'] as Map?)?['name']}',
                            'NPI: ${(o['physician'] as Map?)?['npi']}',
                            '${(o['physician'] as Map?)?['note']}',
                          ],
                        ),
                        _box(
                          'Billing (demo layout)',
                          [
                            '${(o['billing'] as Map?)?['type']}',
                            '${(o['billing'] as Map?)?['note']}',
                          ],
                        ),
                        _box(
                          'Tests requested',
                          [
                            for (final t in (o['tests'] as List? ?? []))
                              '${(t as Map)['code']} — ${t['name']} (${t['note']})',
                          ],
                        ),
                        _box(
                          'Diagnosis hints (demo labels)',
                          [
                            for (final d in (o['diagnosis_hints'] as List? ?? [])) '$d',
                          ],
                        ),
                        _box(
                          'Clinical reason',
                          [
                            for (final r in (o['clinical_reason'] as List? ?? [])) '• $r',
                            if ((o['narrative'] as String?)?.isNotEmpty == true) o['narrative'].toString(),
                          ],
                        ),
                        _box(
                          'Effective blood draw dates',
                          [
                            (o['effective_blood_draw_dates'] as Map?)?['label']?.toString() ?? '',
                            'Last lab on file: ${o['last_lab_date'] ?? '—'}',
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          o['talking_point']?.toString() ?? '',
                          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          o['copy_edge']?.toString() ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ],
                    ),
    );
  }

  Widget _box(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          const SizedBox(height: 6),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(l, style: const TextStyle(fontSize: 13, height: 1.3)),
              )),
        ],
      ),
    );
  }
}
