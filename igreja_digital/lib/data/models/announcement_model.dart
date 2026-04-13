import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/announcement_entity.dart';

class AnnouncementModel extends AnnouncementEntity {
  AnnouncementModel({
    required super.id,
    required super.title,
    required super.content,
    required super.priority,
    required super.congregationId,
    required super.isGlobal,
    required super.publishedBy,
    required super.createdAt,
    required super.updatedAt,
    super.expiresAt,
    required super.isActive,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map, String id) {
    return AnnouncementModel(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      priority: AnnouncementPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => AnnouncementPriority.normal,
      ),
      congregationId: map['congregationId'] ?? '',
      isGlobal: map['isGlobal'] ?? false,
      publishedBy: map['publishedBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      expiresAt: map['expiresAt'] != null ? (map['expiresAt'] as Timestamp).toDate() : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'priority': priority.name,
      'congregationId': congregationId,
      'isGlobal': isGlobal,
      'publishedBy': publishedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
    };
  }

  factory AnnouncementModel.fromEntity(AnnouncementEntity entity) {
    return AnnouncementModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      priority: entity.priority,
      congregationId: entity.congregationId,
      isGlobal: entity.isGlobal,
      publishedBy: entity.publishedBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      expiresAt: entity.expiresAt,
      isActive: entity.isActive,
    );
  }
}
