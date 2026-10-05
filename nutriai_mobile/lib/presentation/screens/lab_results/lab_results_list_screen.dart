import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lab_result_model.dart';
import '../../providers/lab_result_provider.dart';
import '../retest/retest_screen.dart';
import 'lab_result_detail_screen.dart';

class LabResultsListScreen extends ConsumerWidget {
  const LabResultsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labResultsAsync = ref.watch(allLabResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lab Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Imported from your health records', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Refresh labs',
            onPressed: () => ref.read(allLabResultsProvider.notifier).sync(),
          ),
        ],
      ),
      body: labResultsAsync.when(
        data: (labResults) {
          if (labResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No lab results yet', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Connect MyChart or import results to unlock your personalized nutrition plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(allLabResultsProvider.notifier).sync(),
                    icon: const Icon(Icons.download),
                    label: const Text('Load Demo Labs'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildSourceBanner(labResults.first),
              _buildRetestBanner(context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: labResults.length,
                  itemBuilder: (context, index) => _buildLabResultCard(context, labResults[index]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(allLabResultsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceBanner(LabResult sample) {
    final meta = sample.labcorp;
    final sourceLabel = sample.source == 'mychart' ? 'MyChart' : 'Health records';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primaryColor.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.folder_shared_outlined, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meta != null ? '${meta.patientName} · $sourceLabel' : sourceLabel,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sourceLabel,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetestBanner(BuildContext context) {
    return Material(
      color: const Color(0xFF0B3D5C),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RetestScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.event_available, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ready to recheck progress? Schedule follow-up labs',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabResultCard(BuildContext context, LabResult labResult) {
    final date = DateTime.parse(labResult.testDate);
    final abnormalCount = labResult.markers.where((m) => !m.isNormal && !m.isPending).length;
    final meta = labResult.labcorp;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: labResult.isNew ? 3 : 1,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LabResultDetailScreen(labResult: labResult)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science, color: abnormalCount > 0 ? Colors.orange : Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                labResult.panelTitle ?? labResult.testType,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (labResult.isNew) _badge('NEW', Colors.green),
                          ],
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(date),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (meta != null)
                          Text(
                            '${meta.orderingProvider} · ${meta.accountName}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
              if (abnormalCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$abnormalCount marker(s) need dietary attention',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
