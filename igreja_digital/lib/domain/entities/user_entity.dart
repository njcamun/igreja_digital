const visitorCongregationId = 'visitor';

enum UserRole { visitante, membro, lider, admin }

class UserEntity {
  final String uid;
  final String fullName;
  final String email;
  final DateTime? birthDate;
  final String? maritalStatus;
  final String? contact;
  final String? shortBio;
  final DateTime? membershipDate;
  final UserRole role;
  final String? congregationId;
  final bool isActive;
  final DateTime createdAt;
  final String? fcmToken;
  final List<String>? fcmTokens;
  final Map<String, bool>? notificationPreferences;
  final DateTime? lastTokenUpdateAt;

  UserEntity({
    required this.uid,
    required this.fullName,
    required this.email,
    this.birthDate,
    this.maritalStatus,
    this.contact,
    this.shortBio,
    this.membershipDate,
    required this.role,
    this.congregationId,
    required this.isActive,
    required this.createdAt,
    this.fcmToken,
    this.fcmTokens,
    this.notificationPreferences,
    this.lastTokenUpdateAt,
  });
}

extension UserEntitySelectionX on UserEntity {
  bool get hasCongregationSelection =>
      congregationId != null && congregationId!.trim().isNotEmpty;

  bool get isVisitorSelection => congregationId == visitorCongregationId;
}
