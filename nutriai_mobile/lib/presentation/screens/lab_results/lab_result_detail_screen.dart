import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class LabResultDetailScreen extends StatelessWidget {
  final dynamic labResult;

  const LabResultDetailScreen({super.key, required this.labResult});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(labResult.testDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(labResult.testType),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(date),
            const SizedBox(height: 24),
            if (labResult.aiInterpretation != null) _buildAiInterpretation(),
            const SizedBox(height: 24),
            _buildMarkers(),
            const SizedBox(height: 24),
            if (labResult.recommendations != null) _buildRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime date) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Test Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  DateFormat('MMMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInterpretation() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'AI Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              labResult.aiInterpretation!,
              style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkers() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lab Markers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...labResult.markers.map((marker) => _buildMarkerRow(marker)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerRow(dynamic marker) {
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    if (marker.isHigh) {
      statusColor = Colors.red;
      statusIcon = Icons.arrow_upward;
    } else if (marker.isLow) {
      statusColor = Colors.blue;
      statusIcon = Icons.arrow_downward;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  marker.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${marker.displayValue} ${marker.unit}'.trim(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  marker.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Normal range: ${marker.referenceRange} ${marker.unit}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...labResult.recommendations!.map<Widget>((rec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec,
                        style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
