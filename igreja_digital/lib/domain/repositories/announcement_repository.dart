import '../entities/announcement_entity.dart';

abstract class AnnouncementRepository {
  Stream<List<AnnouncementEntity>> getAnnouncements({String? congregationId, bool? isGlobal});
  Future<List<AnnouncementEntity>> getCachedAnnouncements({String? congregationId, bool? isGlobal});
  Future<void> addAnnouncement(AnnouncementEntity announcement);
  Future<void> updateAnnouncement(AnnouncementEntity announcement);
  Future<void> deleteAnnouncement(String id);
  Future<AnnouncementEntity?> getAnnouncementById(String id);
}
