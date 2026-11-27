import 'package:equatable/equatable.dart';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v == null) return fallback;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}

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
    final results = _asMap(json['results']);
    final tests = results['tests'];
    if (tests is List) {
      for (final test in tests) {
        try {
          markers.add(LabMarker.fromBackendTest(_asMap(test)));
        } catch (_) {
          // Skip malformed marker rows.
        }
      }
    }

    final interpretation = _asMap(json['interpretation']);
    final labcorpJson = json['labcorp'];

    return LabResult(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      testDate: _asString(json['test_date']),
      panelTitle: json['panel_title']?.toString(),
      source: _asString(json['source'], 'labcorp'),
      markers: markers,
      aiInterpretation: interpretation['summary']?.toString(),
      concerns: interpretation['concerns'] != null
          ? _asStringList(interpretation['concerns'])
          : null,
      recommendations: interpretation['recommendations'] != null
          ? _asStringList(interpretation['recommendations'])
          : null,
      abnormalCount: interpretation['abnormal_count'] == null
          ? null
          : _asInt(interpretation['abnormal_count']),
      labcorp: labcorpJson is Map ? LabcorpMetadata.fromJson(_asMap(labcorpJson)) : null,
    );
  }

  String get testType =>
      panelTitle ?? (markers.isNotEmpty ? markers.first.category : 'Lab Panel');

  bool get hasAbnormalMarkers => markers.any((m) => !m.isNormal);

  bool get isNew => labcorp?.dashboardCategory == 'new';

  @override
  List<Object?> get props => [id, userId, testDate, markers];
}

class LabcorpMetadata extends Equatable {
  final int? pid;
  final String patientName;
  final String accountName;
  final String orderingProvider;
  final String dashboardCategory;
  final String reportDate;

  const LabcorpMetadata({
    this.pid,
    required this.patientName,
    required this.accountName,
    required this.orderingProvider,
    required this.dashboardCategory,
    required this.reportDate,
  });

  factory LabcorpMetadata.fromJson(Map<String, dynamic> json) {
    return LabcorpMetadata(
      pid: json['pid'] == null ? null : _asInt(json['pid']),
      patientName: _asString(json['patient_name'], 'Patient'),
      accountName: _asString(json['account_name'], 'Imported'),
      orderingProvider: _asString(json['ordering_provider'], 'Provider'),
      dashboardCategory: _asString(json['dashboard_category'], 'recently_viewed'),
      reportDate: _asString(json['report_date']),
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
      name: _asString(json['name'], 'Marker'),
      value: json['value'],
      unit: _asString(json['unit']),
      referenceRange: _asString(json['reference_range']),
      status: _asString(json['status'], 'normal'),
      category: _asString(json['category'], 'General'),
      testCode: json['test_code']?.toString(),
      nutritionRelevant: _asBool(json['nutrition_relevant'], true),
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
