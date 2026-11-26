import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

/// Production lab timeline — chronolab-rag math, coaching-grade UX.
class LabTrendsScreen extends ConsumerStatefulWidget {
  const LabTrendsScreen({super.key});

  @override
  ConsumerState<LabTrendsScreen> createState() => _LabTrendsScreenState();
}

class _LabTrendsScreenState extends ConsumerState<LabTrendsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _filter = 'all';

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
      final res = await ref.read(dioClientProvider).dio.get(ApiConstants.labResultsTrends);
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : _buildBody(),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppTheme.textSecondaryColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data ?? {};
    final trends = (data['trends'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final insights = (data['insights'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final cards = (data['summary_cards'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final audit = data['safety_audit'] is Map
        ? Map<String, dynamic>.from(data['safety_audit'] as Map)
        : <String, dynamic>{};
    final filtered = _filter == 'all'
        ? trends
        : trends.where((t) => t['group']?.toString() == _filter).toList();

    if (trends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Add at least two lab visits to unlock your timeline.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor, height: 1.4),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _heroHeader(data, audit)),
        if (cards.isNotEmpty)
          SliverToBoxAdapter(child: _snapshotStrip(cards)),
        if (insights.isNotEmpty)
          SliverToBoxAdapter(child: _insightsSection(insights)),
        SliverToBoxAdapter(child: _filterRow()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _TrendCard(trend: filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _heroHeader(Map<String, dynamic> data, Map<String, dynamic> audit) {
    final passed = audit['safety_audit_passed'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your lab story',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${data['panel_count'] ?? 0} visits · ${data['trend_count'] ?? 0} markers tracked',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: passed ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: passed ? AppTheme.successColor : AppTheme.warningColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    passed
                        ? 'Verified explanation — numbers come only from your panels'
                        : 'Review flagged — still coaching-safe teaching ranges',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _snapshotStrip(List<Map<String, dynamic>> cards) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cards[i];
          final tone = c['tone']?.toString() ?? 'neutral';
          final bg = tone == 'attention'
              ? const Color(0xFFFFF1E8)
              : tone == 'positive'
                  ? const Color(0xFFE9F7EF)
                  : Colors.white;
          final accent = tone == 'attention'
              ? AppTheme.accentColor
              : tone == 'positive'
                  ? AppTheme.successColor
                  : AppTheme.primaryColor;
          return Container(
            width: 156,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  c['value']?.toString() ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c['subtitle']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    height: 1.25,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _insightsSection(List<Map<String, dynamic>> insights) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What changed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...insights.map((insight) {
            final tone = insight['tone']?.toString() ?? 'neutral';
            final bar = tone == 'attention'
                ? AppTheme.accentColor
                : tone == 'positive'
                    ? AppTheme.successColor
                    : AppTheme.primaryColor;
            final cites = (insight['citations'] as List? ?? []).map((e) => e.toString()).toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight['title']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight['text']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.45,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        if (cites.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: cites
                                .map(
                                  (c) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.chipBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      c,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          Text(
            dataDisclaimer(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              height: 1.35,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String dataDisclaimer() {
    return (_data?['disclaimer'] ?? '').toString();
  }

  Widget _filterRow() {
    const filters = [
      ('all', 'All'),
      ('lipids', 'Lipids'),
      ('glucose', 'Sugar'),
      ('kidney', 'Kidney'),
      ('body', 'Body'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _filter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f.$1),
                selectedColor: AppTheme.primaryColor,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : AppTheme.ink,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: selected ? AppTheme.primaryColor : AppTheme.borderSubtle),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<String, dynamic> trend;

  const _TrendCard({required this.trend});

  Color _statusColor(String status) {
    switch (status) {
      case 'High':
        return AppTheme.accentColor;
      case 'Low':
        return const Color(0xFF1565C0);
      case 'In range':
        return AppTheme.successColor;
      case 'Tracked':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = (trend['points'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final unit = trend['unit']?.toString() ?? '';
    final latestStatus = trend['latest_status']?.toString() ?? '';
    final showStatus = trend['show_status'] != false && latestStatus.isNotEmpty && latestStatus != 'Tracked';
    final direction = trend['direction']?.toString() ?? 'flat';
    final contextText = trend['clinical_context']?.toString() ?? '';
    final transition = trend['status_transition']?.toString() ?? '';
    final dirIcon = direction == 'up'
        ? Icons.trending_up_rounded
        : direction == 'down'
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend['test_name']?.toString() ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trend['baseline_date']} → ${trend['latest_date']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (showStatus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(latestStatus).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    latestStatus,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(latestStatus),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${trend['latest_value']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  unit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(dirIcon, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 4),
              Text(
                '${trend['percent_change']}%',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Was ${trend['baseline_value']} $unit · $transition',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          if (points.length >= 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 132,
              child: LineChart(
                LineChartData(
                  minY: _minY(points),
                  maxY: _maxY(points),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (_maxY(points) - _minY(points)) / 3,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: AppTheme.borderSubtle.withValues(alpha: 0.8),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              '${points[s.x.toInt()]['value']} $unit\n${points[s.x.toInt()]['date']}',
                              GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), (points[i]['value'] as num).toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.28,
                      color: AppTheme.primaryColor,
                      barWidth: 3.2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                          radius: 4.2,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: AppTheme.primaryColor,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.22),
                            AppTheme.primaryColor.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (contextText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.chipBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contextText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.ink.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _minY(List<Map<String, dynamic>> points) {
    final vals = points.map((p) => (p['value'] as num).toDouble()).toList();
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() < 1 ? 1.0 : (maxV - minV) * 0.2);
    return minV - pad;
  }

  double _maxY(List<Map<String, dynamic>> points) {
    final vals = points.map((p) => (p['value'] as num).toDouble()).toList();
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() < 1 ? 1.0 : (maxV - minV) * 0.2);
    return maxV + pad;
  }
}
