import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

/// Display model for Nexconn user profiles in ChatUI.
///
/// It carries only the profile fields that the UI renders or caches.
class NexconnUserProfile {
  final String? userId;
  final String? name;
  final String? avatarUrl;
  final String? uniqueId;
  final String? email;
  final String? birthday;
  final UserGender? gender;
  final String? location;
  final int? role;
  final int? level;
  final Map? extProfile;

  const NexconnUserProfile({
    this.userId,
    this.name,
    this.avatarUrl,
    this.uniqueId,
    this.email,
    this.birthday,
    this.gender,
    this.location,
    this.role,
    this.level,
    this.extProfile,
  });

  /// Creates an instance from the Nexconn SDK user profile object.
  factory NexconnUserProfile.fromSdk(UserProfile profile) {
    return NexconnUserProfile(
      userId: profile.userId,
      name: profile.name,
      avatarUrl: profile.avatarUrl,
      uniqueId: profile.uniqueId,
      email: profile.email,
      birthday: profile.birthday,
      gender: profile.gender,
      location: profile.location,
      role: profile.role,
      level: profile.level,
      extProfile: profile.extProfile,
    );
  }

  /// Restores an instance from JSON-style data for tests and caching.
  factory NexconnUserProfile.fromJson(Map<String, dynamic> json) {
    return NexconnUserProfile(
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      uniqueId: json['uniqueId'] as String?,
      email: json['email'] as String?,
      birthday: json['birthday'] as String?,
      gender: _genderFromJson(json['gender']),
      location: json['location'] as String?,
      role: _intFromJson(json['role']),
      level: _intFromJson(json['level']),
      extProfile: json['extProfile'] as Map?,
    );
  }

  /// Best display name for lists and titles.
  String get displayName {
    for (final value in [name, uniqueId, userId]) {
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return 'Unnamed user';
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'uniqueId': uniqueId,
      'email': email,
      'birthday': birthday,
      'gender': gender?.index,
      'location': location,
      'role': role,
      'level': level,
      'extProfile': extProfile,
    };
  }

  UserProfile toSdkProfile() {
    return UserProfile(
      name: name,
      avatarUrl: avatarUrl,
      email: email,
      birthday: birthday,
      gender: gender,
      location: location,
      role: role,
      level: level,
      extProfile: extProfile,
    );
  }

  static UserGender? _genderFromJson(Object? value) {
    if (value is int && value >= 0 && value < UserGender.values.length) {
      return UserGender.values[value];
    }
    if (value is String) {
      for (final gender in UserGender.values) {
        if (gender.name == value) {
          return gender;
        }
      }
    }
    return null;
  }

  static int? _intFromJson(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
