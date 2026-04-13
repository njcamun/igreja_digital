enum AnnouncementPriority { normal, importante, urgente }

class AnnouncementEntity {
  final String id;
  final String title;
  final String content;
  final AnnouncementPriority priority;
  final String congregationId;
  final bool isGlobal;
  final String publishedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final bool isActive;

  AnnouncementEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.priority,
    required this.congregationId,
    required this.isGlobal,
    required this.publishedBy,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    required this.isActive,
  });
}
