import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.uid,
    required super.fullName,
    required super.email,
    super.birthDate,
    super.maritalStatus,
    super.contact,
    super.shortBio,
    super.membershipDate,
    required super.role,
    super.congregationId,
    required super.isActive,
    required super.createdAt,
    super.fcmToken,
    super.fcmTokens,
    super.notificationPreferences,
    super.lastTokenUpdateAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
        birthDate: map['birthDate'] != null
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
        maritalStatus: map['maritalStatus'],
        contact: map['contact'],
        shortBio: map['shortBio'],
      membershipDate: map['membershipDate'] != null
          ? (map['membershipDate'] as Timestamp).toDate()
          : null,
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.visitante,
      ),
      congregationId: map['congregationId'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      fcmToken: map['fcmToken'],
      fcmTokens: map['fcmTokens'] != null ? List<String>.from(map['fcmTokens']) : null,
      notificationPreferences: map['notificationPreferences'] != null
          ? Map<String, bool>.from(map['notificationPreferences'])
          : null,
      lastTokenUpdateAt: map['lastTokenUpdateAt'] != null
          ? (map['lastTokenUpdateAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'maritalStatus': maritalStatus,
      'contact': contact,
      'shortBio': shortBio,
        'membershipDate': membershipDate != null
          ? Timestamp.fromDate(membershipDate!)
          : null,
      'role': role.name,
      'congregationId': congregationId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
      'fcmTokens': fcmTokens,
      'notificationPreferences': notificationPreferences,
      'lastTokenUpdateAt': lastTokenUpdateAt != null ? Timestamp.fromDate(lastTokenUpdateAt!) : null,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      fullName: entity.fullName,
      email: entity.email,
      birthDate: entity.birthDate,
      maritalStatus: entity.maritalStatus,
      contact: entity.contact,
      shortBio: entity.shortBio,
      membershipDate: entity.membershipDate,
      role: entity.role,
      congregationId: entity.congregationId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      fcmToken: entity.fcmToken,
      fcmTokens: entity.fcmTokens,
      notificationPreferences: entity.notificationPreferences,
      lastTokenUpdateAt: entity.lastTokenUpdateAt,
    );
  }
}
