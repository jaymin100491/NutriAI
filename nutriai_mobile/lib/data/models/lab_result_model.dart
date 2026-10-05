import 'package:equatable/equatable.dart';

class LabResult extends Equatable {
  final int id;
  final int userId;
  final String testDate;
  final String? panelTitle;
  final String source;
  final List<LabMarker> markers;
  final String? aiInterpretation;
  final List<String>? concerns;
  final List<String>? recommendations;
  final LabcorpMetadata? labcorp;
  final int? abnormalCount;

  const LabResult({
    required this.id,
    required this.userId,
    required this.testDate,
    this.panelTitle,
    this.source = 'labcorp',
    required this.markers,
    this.aiInterpretation,
    this.concerns,
    this.recommendations,
    this.labcorp,
    this.abnormalCount,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) {
    final markers = <LabMarker>[];
    final tests = json['results']?['tests'] as List<dynamic>? ?? [];

    for (final test in tests) {
      markers.add(LabMarker.fromBackendTest(test as Map<String, dynamic>));
    }

    final interpretation = json['interpretation'] as Map<String, dynamic>?;
    final labcorpJson = json['labcorp'] as Map<String, dynamic>?;

    return LabResult(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      testDate: json['test_date'] as String,
      panelTitle: json['panel_title'] as String?,
      source: json['source'] as String? ?? 'labcorp',
      markers: markers,
      aiInterpretation: interpretation?['summary'] as String?,
      concerns: interpretation?['concerns'] != null
          ? (interpretation!['concerns'] as List<dynamic>).map((e) => e.toString()).toList()
          : null,
      recommendations: interpretation?['recommendations'] != null
          ? (interpretation!['recommendations'] as List<dynamic>).map((e) => e.toString()).toList()
          : null,
      abnormalCount: interpretation?['abnormal_count'] as int?,
      labcorp: labcorpJson != null ? LabcorpMetadata.fromJson(labcorpJson) : null,
    );
  }

  String get testType => panelTitle ?? (markers.isNotEmpty ? markers.first.category : 'Lab Panel');

  bool get hasAbnormalMarkers => markers.any((m) => !m.isNormal);

  bool get isNew => labcorp?.dashboardCategory == 'new';

  @override
  List<Object?> get props => [id, userId, testDate, markers];
}

class LabcorpMetadata extends Equatable {
  final int pid;
  final String patientName;
  final String accountName;
  final String orderingProvider;
  final String dashboardCategory;
  final String reportDate;

  const LabcorpMetadata({
    required this.pid,
    required this.patientName,
    required this.accountName,
    required this.orderingProvider,
    required this.dashboardCategory,
    required this.reportDate,
  });

  factory LabcorpMetadata.fromJson(Map<String, dynamic> json) {
    return LabcorpMetadata(
      pid: json['pid'] as int,
      patientName: json['patient_name'] as String,
      accountName: json['account_name'] as String,
      orderingProvider: json['ordering_provider'] as String,
      dashboardCategory: json['dashboard_category'] as String,
      reportDate: json['report_date'] as String,
    );
  }

  @override
  List<Object?> get props => [pid, dashboardCategory];
}

class LabMarker extends Equatable {
  final String name;
  final dynamic value;
  final String unit;
  final String referenceRange;
  final String status;
  final String category;
  final String? testCode;
  final bool nutritionRelevant;

  const LabMarker({
    required this.name,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.status,
    required this.category,
    this.testCode,
    this.nutritionRelevant = true,
  });

  factory LabMarker.fromBackendTest(Map<String, dynamic> json) {
    return LabMarker(
      name: json['name'] as String,
      value: json['value'],
      unit: json['unit'] as String? ?? '',
      referenceRange: json['reference_range'] as String? ?? '',
      status: json['status'] as String? ?? 'normal',
      category: json['category'] as String? ?? 'General',
      testCode: json['test_code'] as String?,
      nutritionRelevant: json['nutrition_relevant'] as bool? ?? true,
    );
  }

  String get displayValue {
    if (value is num) return (value as num).toString();
    return value?.toString() ?? '';
  }

  bool get isNormal => status == 'normal';
  bool get isHigh => status == 'high';
  bool get isLow => status == 'low';
  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [name, value, unit, status];
}
