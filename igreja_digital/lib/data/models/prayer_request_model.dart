import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/prayer_request_entity.dart';

class PrayerRequestModel extends PrayerRequestEntity {
  PrayerRequestModel({
    required super.id,
    required super.title,
    required super.content,
    required super.userId,
    required super.userName,
    super.congregationId,
    required super.isAnonymous,
    required super.isPrivate,
    required super.isPublic,
    required super.status,
    super.prayerCount,
    super.prayedByUserIds,
    required super.createdAt,
    required super.updatedAt,
    required super.isActive,
  });

  factory PrayerRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return PrayerRequestModel(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      congregationId: map['congregationId'],
      isAnonymous: map['isAnonymous'] ?? false,
      isPrivate: map['isPrivate'] ?? false,
      isPublic: map['isPublic'] ?? true,
      status: PrayerStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PrayerStatus.open,
      ),
      prayerCount: map['prayerCount'] ?? 0,
      prayedByUserIds: List<String>.from(map['prayedByUserIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'userId': userId,
      'userName': userName,
      'congregationId': congregationId,
      'isAnonymous': isAnonymous,
      'isPrivate': isPrivate,
      'isPublic': isPublic,
      'status': status.name,
      'prayerCount': prayerCount,
      'prayedByUserIds': prayedByUserIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory PrayerRequestModel.fromEntity(PrayerRequestEntity entity) {
    return PrayerRequestModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      userId: entity.userId,
      userName: entity.userName,
      congregationId: entity.congregationId,
      isAnonymous: entity.isAnonymous,
      isPrivate: entity.isPrivate,
      isPublic: entity.isPublic,
      status: entity.status,
      prayerCount: entity.prayerCount,
      prayedByUserIds: entity.prayedByUserIds,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isActive: entity.isActive,
    );
  }
}
