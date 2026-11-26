import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

/// chronolab-rag style multi-visit lab trends tab.
class LabTrendsScreen extends ConsumerStatefulWidget {
  const LabTrendsScreen({super.key});

  @override
  ConsumerState<LabTrendsScreen> createState() => _LabTrendsScreenState();
}

class _LabTrendsScreenState extends ConsumerState<LabTrendsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get(ApiConstants.labResultsTrends);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab trends'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data ?? {};
    final trends = (data['trends'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final summary = data['summary_text']?.toString() ?? '';
    final disclaimer = data['disclaimer']?.toString() ?? '';

    if (trends.isEmpty) {
      return const Center(
        child: Text('Upload lab panels to see trends across visits.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trend engine',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.indigo.shade900),
              ),
              if (disclaimer.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  disclaimer,
                  style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${data['panel_count'] ?? 0} panels · ${data['trend_count'] ?? trends.length} markers',
          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        ...trends.map(_trendCard),
      ],
    );
  }

  Widget _trendCard(Map<String, dynamic> t) {
    final points = (t['points'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final unit = t['unit']?.toString() ?? '';
    final transition = t['status_transition']?.toString() ?? '';
    final delta = t['delta'];
    final pct = t['percent_change'];
    final name = t['test_name']?.toString() ?? 'Marker';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              '${t['baseline_value']} → ${t['latest_value']}$unit  ·  Δ $delta ($pct%)  ·  $transition',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
            ),
            if (points.length >= 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(
                              i.toDouble(),
                              (points[i]['value'] as num).toDouble(),
                            ),
                        ],
                        isCurved: true,
                        color: AppTheme.primaryColor,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryColor.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t['baseline_date']}  →  ${t['latest_date']}  (${t['observation_count']} visits)',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
