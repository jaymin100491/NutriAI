import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String? gender;
  final double? heightInches;
  final double? currentWeightLbs;
  final String subscriptionTier;
  final String dietaryPreference;
  final List<String> allergies;
  final List<String> medicalConditions;
  final String createdAt;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.gender,
    this.heightInches,
    this.currentWeightLbs,
    required this.subscriptionTier,
    required this.dietaryPreference,
    this.allergies = const [],
    this.medicalConditions = const [],
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      heightInches: (json['height_inches'] as num?)?.toDouble(),
      currentWeightLbs: (json['current_weight_lbs'] as num?)?.toDouble(),
      subscriptionTier: json['subscription_tier'] as String,
      dietaryPreference: json['dietary_preference'] as String? ?? 'omnivore',
      allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      medicalConditions: (json['medical_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'height_inches': heightInches,
      'current_weight_lbs': currentWeightLbs,
      'subscription_tier': subscriptionTier,
      'dietary_preference': dietaryPreference,
      'allergies': allergies,
      'medical_conditions': medicalConditions,
      'created_at': createdAt,
    };
  }

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, email, firstName, lastName, subscriptionTier];
}
