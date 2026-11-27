import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/craft/craft.dart';
import '../lab_results/lab_results_list_screen.dart';

/// Chronolab-grade lab timeline — storytelling charts, provenance, motion.
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
  int? _expandedIndex;

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
            ? const _TrendsSkeleton()
            : _error != null
                ? CraftErrorState(message: _error!, onRetry: _load)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data ?? {};
    final trends = (data['trends'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        // Hide low-signal BMI (often corrupted by height typos)
        .where((t) {
          final name = (t['test_name'] ?? t['name'] ?? '').toString().toLowerCase();
          return !name.contains('bmi') && !name.contains('body mass');
        })
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
      return CraftEmptyState(
        icon: Icons.timeline_outlined,
        title: 'Your timeline starts with two visits',
        body: 'Upload another lab panel to unlock marker trends, clinical context, and verified explanations.',
        ctaLabel: 'Add lab results',
        onCta: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LabResultsListScreen()),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero(data, audit).craftIn()),
          if (cards.isNotEmpty)
            SliverToBoxAdapter(child: _snapshotStrip(cards).craftIn(delayMs: 60)),
          if (insights.isNotEmpty)
            SliverToBoxAdapter(child: _insights(insights, data).craftIn(delayMs: 110)),
          SliverToBoxAdapter(child: _filters().craftIn(delayMs: 150)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final globalIndex = trends.indexOf(filtered[i]);
                return _MarkerStoryCard(
                  trend: filtered[i],
                  expanded: _expandedIndex == globalIndex,
                  onToggle: () => setState(() {
                    _expandedIndex = _expandedIndex == globalIndex ? null : globalIndex;
                  }),
                ).craftIn(delayMs: 160 + (i * 40).clamp(0, 280));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Map<String, dynamic> data, Map<String, dynamic> audit) {
    final passed = audit['safety_audit_passed'] == true;
    final method = audit['method']?.toString() ?? 'deterministic_metrics_only';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your lab story',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppTheme.ink,
                    height: 1.1,
                  ),
                ),
              ),
              _IconBtn(icon: Icons.refresh_rounded, onTap: _load),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${data['panel_count'] ?? 0} visits · ${data['trend_count'] ?? 0} markers · chronolab math',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          TrustBanner(
            verified: passed,
            title: passed ? 'Hallucination-checked explanation' : 'Review flagged — still coaching-safe',
            subtitle: passed
                ? 'Every number below comes only from your stored panels. No invented values.'
                : 'Teaching ranges still apply. Ask your clinician for medical decisions.',
            sources: [
              'engine: chronolab-rag',
              method.replaceAll('_', ' '),
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotStrip(List<Map<String, dynamic>> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: CraftSectionHeader(
            title: 'At a glance',
            subtitle: 'Highest-signal markers right now',
          ),
        ),
        SizedBox(
          height: 136,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = cards[i];
              final tone = c['tone']?.toString() ?? 'neutral';
              final colors = _toneColors(tone);
              return Container(
                width: 158,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.$1.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      c['value']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.$1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['subtitle']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.$1.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _insights(List<Map<String, dynamic>> insights, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CraftSectionHeader(
            title: 'What changed',
            subtitle: 'Multi-analyte reasoning from your panels',
          ),
          const SizedBox(height: 12),
          ...insights.asMap().entries.map((entry) {
            final insight = entry.value;
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
                    height: 56,
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
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: cites.map((c) => ProvenanceChip(label: c)).toList(),
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
            data['disclaimer']?.toString() ?? '',
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

  /// accent, background — status-driven palette so glance cards aren't all the same.
  (Color, Color) _toneColors(String tone) {
    switch (tone) {
      case 'high':
      case 'attention':
        return (AppTheme.accentColor, const Color(0xFFFFF1E8));
      case 'low':
        return (const Color(0xFF1565C0), const Color(0xFFE8F1FB));
      case 'positive':
        return (AppTheme.successColor, const Color(0xFFE9F7EF));
      case 'watch':
        return (AppTheme.warningColor, const Color(0xFFFFF6E8));
      default:
        return (AppTheme.primaryColor, Colors.white);
    }
  }

  Widget _filters() {
    const filters = [
      ('all', 'All'),
      ('lipids', 'Lipids'),
      ('glucose', 'Sugar'),
      ('kidney', 'Kidney'),
      ('body', 'Body'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CraftSectionHeader(
            title: 'Marker timeline',
            subtitle: 'Tap a card for clinical context',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
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
                    side: BorderSide(
                      color: selected ? AppTheme.primaryColor : AppTheme.borderSubtle,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.borderSubtle)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
        ),
      ),
    );
  }
}

class _TrendsSkeleton extends StatelessWidget {
  const _TrendsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const CraftShimmer(height: 36, width: 220),
        const SizedBox(height: 10),
        const CraftShimmer(height: 16, width: 180),
        const SizedBox(height: 16),
        const CraftShimmer(height: 72),
        const SizedBox(height: 18),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => const CraftShimmer(height: 118, width: 160),
          ),
        ),
        const SizedBox(height: 18),
        const CraftShimmer(height: 110),
        const SizedBox(height: 12),
        const CraftShimmer(height: 110),
        const SizedBox(height: 18),
        const CraftShimmer(height: 220),
        const SizedBox(height: 12),
        const CraftShimmer(height: 220),
      ],
    );
  }
}

class _MarkerStoryCard extends StatefulWidget {
  final Map<String, dynamic> trend;
  final bool expanded;
  final VoidCallback onToggle;

  const _MarkerStoryCard({
    required this.trend,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_MarkerStoryCard> createState() => _MarkerStoryCardState();
}

class _MarkerStoryCardState extends State<_MarkerStoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _draw.forward();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'High':
        return AppTheme.accentColor;
      case 'Low':
        return const Color(0xFF1565C0);
      case 'In range':
        return AppTheme.successColor;
      case 'Watch':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
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
    final sourceId = trend['source_id']?.toString() ?? trend['citation']?.toString() ?? '';
    final boundSource = trend['bound_source']?.toString() ?? '';
    final provenance = trend['provenance']?.toString() ??
        (trend['panel_date'] != null
            ? 'Labcorp panel · ${trend['panel_date']}'
            : '');
    final refLow = trend['reference_low'];
    final refHigh = trend['reference_high'];
    final dirIcon = direction == 'up'
        ? Icons.trending_up_rounded
        : direction == 'down'
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final delta = trend['delta'];
    final pct = trend['percent_change'];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 20,
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
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${trend['baseline_date']} → ${trend['latest_date']} · ${trend['observation_count'] ?? points.length} points',
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${trend['latest_value']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(dirIcon, color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${delta != null && (delta as num) > 0 ? '+' : ''}$delta · $pct%',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Was ${trend['baseline_value']} $unit · $transition',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              if (provenance.isNotEmpty) ...[
                const SizedBox(height: 8),
                ProvenanceChip(
                  label: provenance.startsWith('from ')
                      ? provenance
                      : 'from $provenance',
                  icon: Icons.biotech_outlined,
                ),
              ],
              if (points.length >= 2) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 148,
                  child: AnimatedBuilder(
                    animation: _draw,
                    builder: (context, _) => _StoryChart(
                      points: points,
                      unit: unit,
                      progress: Curves.easeOutCubic.transform(_draw.value),
                      refLow: refLow is num ? refLow.toDouble() : null,
                      refHigh: refHigh is num ? refHigh.toDouble() : null,
                    ),
                  ),
                ),
                if (refLow != null || refHigh != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Teaching range ${_fmtBound(refLow)}–${_fmtBound(refHigh)}'
                          '${boundSource.isNotEmpty ? ' · $boundSource' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Text(
                        'Why this matters',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.primaryColor),
                      const Spacer(),
                      if (sourceId.isNotEmpty) ProvenanceChip(label: sourceId),
                    ],
                  ),
                ),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Clinical context',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (sourceId.isNotEmpty) ProvenanceChip(label: sourceId),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contextText.isNotEmpty
                              ? contextText
                              : 'Teaching range context for coaching. Not a diagnosis.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.45,
                            color: AppTheme.ink.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap again to collapse',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                crossFadeState:
                    widget.expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: 240.ms,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtBound(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    }
    return v.toString();
  }
}

class _StoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String unit;
  final double progress;
  final double? refLow;
  final double? refHigh;

  const _StoryChart({
    required this.points,
    required this.unit,
    required this.progress,
    this.refLow,
    this.refHigh,
  });

  @override
  Widget build(BuildContext context) {
    final vals = points.map((p) => (p['value'] as num).toDouble()).toList();
    var minV = vals.reduce(math.min);
    var maxV = vals.reduce(math.max);
    if (refLow != null) minV = math.min(minV, refLow!);
    if (refHigh != null) maxV = math.max(maxV, refHigh!);
    final pad = ((maxV - minV).abs() < 1 ? 1.0 : (maxV - minV) * 0.22);
    final yMin = minV - pad;
    final yMax = maxV + pad;

    final visibleCount = math.max(2, (points.length * progress).ceil());
    final spots = <FlSpot>[
      for (var i = 0; i < visibleCount; i++)
        FlSpot(i.toDouble(), vals[i.clamp(0, vals.length - 1)]),
    ];
    // Interpolate last segment for smoother draw
    if (progress < 1 && visibleCount < points.length) {
      final prev = visibleCount - 1;
      final next = visibleCount;
      final t = (points.length * progress) - prev;
      final y = vals[prev] + (vals[next] - vals[prev]) * t.clamp(0.0, 1.0);
      spots[spots.length - 1] = FlSpot(prev + t, y);
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: yMin,
        maxY: yMax,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (yMax - yMin) / 3,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppTheme.borderSubtle.withValues(alpha: 0.9),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                if (i != 0 && i != points.length - 1 && points.length > 3) {
                  return const SizedBox.shrink();
                }
                final d = points[i]['date']?.toString() ?? '';
                final short = d.length >= 10 ? d.substring(5) : d;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        rangeAnnotations: (refLow != null || refHigh != null)
            ? RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                    y1: refLow ?? yMin,
                    y2: refHigh ?? yMax,
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  ),
                ],
              )
            : null,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.round().clamp(0, points.length - 1);
              return LineTooltipItem(
                '${points[i]['value']} $unit\n${points[i]['date']}',
                GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            color: AppTheme.primaryColor,
            barWidth: 3.2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) {
                final isLast = i == spots.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 5.2 : 3.6,
                  color: Colors.white,
                  strokeWidth: isLast ? 3 : 2.2,
                  strokeColor: isLast ? AppTheme.accentColor : AppTheme.primaryColor,
                );
              },
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
    );
  }
}
