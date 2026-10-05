import 'package:equatable/equatable.dart';

class DailyTracking extends Equatable {
  final int id;
  final int userId;
  final String date;
  final double? weightLbs;
  final int? systolicBp;
  final int? diastolicBp;
  final int? bloodGlucose;
  final int? mood;
  final String? notes;
  final String? milestone;
  final String? source;

  const DailyTracking({
    required this.id,
    required this.userId,
    required this.date,
    this.weightLbs,
    this.systolicBp,
    this.diastolicBp,
    this.bloodGlucose,
    this.mood,
    this.notes,
    this.milestone,
    this.source,
  });

  factory DailyTracking.fromJson(Map<String, dynamic> json) {
    return DailyTracking(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      date: json['date'] as String,
      weightLbs: json['weight_lbs'] != null ? (json['weight_lbs'] as num).toDouble() : null,
      systolicBp: json['systolic_bp'] as int?,
      diastolicBp: json['diastolic_bp'] as int?,
      bloodGlucose: json['blood_glucose'] as int?,
      mood: json['mood'] is int ? json['mood'] as int : int.tryParse('${json['mood'] ?? ''}'),
      notes: json['notes'] as String?,
      milestone: json['milestone'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'weight_lbs': weightLbs,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'blood_glucose': bloodGlucose,
      'mood': mood,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [id, userId, date, weightLbs, systolicBp, diastolicBp, bloodGlucose, mood];
}

class ProgressData extends Equatable {
  final List<DailyTracking> trackingData;
  final double? weightChange;
  final double? avgBloodGlucose;
  final double? avgMood;
  final double? bpChange;
  final double? glucoseChange;
  final List<String> highlights;
  final String? story;
  final Map<String, dynamic> labMarkers;

  const ProgressData({
    required this.trackingData,
    this.weightChange,
    this.avgBloodGlucose,
    this.avgMood,
    this.bpChange,
    this.glucoseChange,
    this.highlights = const [],
    this.story,
    this.labMarkers = const {},
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      trackingData: (json['tracking_data'] as List<dynamic>)
          .map((e) => DailyTracking.fromJson(e as Map<String, dynamic>))
          .toList(),
      weightChange: json['weight_change'] != null ? (json['weight_change'] as num).toDouble() : null,
      avgBloodGlucose: json['avg_blood_glucose'] != null ? (json['avg_blood_glucose'] as num).toDouble() : null,
      avgMood: json['avg_mood'] != null ? (json['avg_mood'] as num).toDouble() : null,
      bpChange: json['bp_change'] != null ? (json['bp_change'] as num).toDouble() : null,
      glucoseChange: json['glucose_change'] != null ? (json['glucose_change'] as num).toDouble() : null,
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      story: json['story'] as String?,
      labMarkers: Map<String, dynamic>.from(json['lab_markers'] as Map? ?? const {}),
    );
  }

  @override
  List<Object?> get props => [trackingData, weightChange, avgBloodGlucose, avgMood, highlights];
}
