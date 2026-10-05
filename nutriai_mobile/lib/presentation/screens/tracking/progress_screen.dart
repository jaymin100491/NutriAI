import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tracking_model.dart';
import '../../providers/tracking_provider.dart';
import 'tracking_form_screen.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(trackingNotifierProvider.notifier).loadTrackingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingNotifierProvider);
    final progressAsync = ref.watch(progressDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(trackingNotifierProvider.notifier).loadTrackingData();
              ref.invalidate(progressDataProvider);
            },
          ),
        ],
      ),
      body: trackingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : trackingState.error != null
              ? Center(child: Text(trackingState.error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      progressAsync.when(
                        data: (progressData) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (progressData != null) _buildStoryCard(progressData),
                            const SizedBox(height: 16),
                            if (progressData != null) _buildSummaryCards(progressData),
                            const SizedBox(height: 16),
                            if (progressData != null) _buildHighlights(progressData),
                          ],
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      _buildWeightChart(trackingState.trackingData),
                      const SizedBox(height: 24),
                      _buildBloodPressureChart(trackingState.trackingData),
                      const SizedBox(height: 24),
                      _buildGlucoseChart(trackingState.trackingData),
                      const SizedBox(height: 24),
                      _buildMilestones(trackingState.trackingData),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrackingFormScreen()),
          ).then((_) {
            ref.read(trackingNotifierProvider.notifier).loadTrackingData();
            ref.invalidate(progressDataProvider);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Log Metrics'),
      ),
    );
  }

  Widget _buildStoryCard(ProgressData progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.15), Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your improvement journey',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            progress.story ??
                'Track weight, blood pressure, and glucose alongside your meal plans.',
            style: const TextStyle(height: 1.4, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(ProgressData progress) {
    if (progress.highlights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('With diet coaching', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...progress.highlights.map(
          (h) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.trending_down, color: Colors.green),
              title: Text(h, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(ProgressData progressData) {
    final weightLabel = progressData.weightChange == null
        ? 'N/A'
        : '${progressData.weightChange! >= 0 ? '+' : ''}${progressData.weightChange!.toStringAsFixed(1)} lbs';

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Weight Change',
            weightLabel,
            Icons.monitor_weight,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Mood',
            '${progressData.avgMood?.toStringAsFixed(1) ?? "N/A"}/10',
            Icons.mood,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart(List trackingData) {
    final weightData = trackingData.where((t) => t.weightLbs != null).toList();
    if (weightData.isEmpty) {
      return _buildEmptyChart('Weight Trend', 'No weight data available');
    }

    final spots = weightData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightLbs!);
    }).toList();

    return _buildChartCard(
      'Weight Trend (with meal plans)',
      LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodPressureChart(List trackingData) {
    final bpData = trackingData.where((t) => t.systolicBp != null && t.diastolicBp != null).toList();
    if (bpData.isEmpty) {
      return _buildEmptyChart('Blood Pressure', 'No blood pressure data available');
    }

    final systolicSpots = bpData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.systolicBp!.toDouble());
    }).toList();

    final diastolicSpots = bpData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.diastolicBp!.toDouble());
    }).toList();

    return _buildChartCard(
      'Blood Pressure Trend',
      LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: systolicSpots,
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: diastolicSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlucoseChart(List trackingData) {
    final glucoseData = trackingData.where((t) => t.bloodGlucose != null).toList();
    if (glucoseData.isEmpty) {
      return _buildEmptyChart('Blood Glucose', 'No glucose data available');
    }

    final spots = glucoseData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.bloodGlucose!.toDouble());
    }).toList();

    return _buildChartCard(
      'Glucose Trend',
      LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestones(List trackingData) {
    final milestones = trackingData
        .where((t) => t.milestone != null && t.milestone!.isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .toList();
    if (milestones.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plan & lab milestones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...milestones.map(
          (m) => Card(
            child: ListTile(
              leading: const Icon(Icons.flag, color: AppTheme.primaryColor),
              title: Text(m.milestone!),
              subtitle: Text(
                '${m.date} · ${m.weightLbs?.toStringAsFixed(0) ?? "--"} lbs · BP ${m.systolicBp}/${m.diastolicBp}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
