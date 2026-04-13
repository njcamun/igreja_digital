enum PrayerStatus { open, praying, answered, archived }

extension PrayerStatusLocalization on PrayerStatus {
  String get label {
    return switch (this) {
      PrayerStatus.open => 'Em aberto',
      PrayerStatus.praying => 'Alguém está orando',
      PrayerStatus.answered => 'Respondido',
      PrayerStatus.archived => 'Arquivado',
    };
  }
}

class PrayerRequestEntity {
  final String id;
  final String title;
  final String content;
  final String userId;
  final String userName;
  final String? congregationId;
  final bool isAnonymous;
  final bool isPrivate;
  final bool isPublic;
  final PrayerStatus status;
  final int prayerCount;
  final List<String> prayedByUserIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  PrayerRequestEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.userName,
    this.congregationId,
    required this.isAnonymous,
    required this.isPrivate,
    required this.isPublic,
    required this.status,
    this.prayerCount = 0,
    this.prayedByUserIds = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  PrayerRequestEntity copyWith({
    String? id,
    String? title,
    String? content,
    String? userId,
    String? userName,
    String? congregationId,
    bool? isAnonymous,
    bool? isPrivate,
    bool? isPublic,
    PrayerStatus? status,
    int? prayerCount,
    List<String>? prayedByUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return PrayerRequestEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      congregationId: congregationId ?? this.congregationId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPrivate: isPrivate ?? this.isPrivate,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      prayerCount: prayerCount ?? this.prayerCount,
      prayedByUserIds: prayedByUserIds ?? this.prayedByUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
