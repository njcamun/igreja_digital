import '../entities/prayer_request_entity.dart';

abstract class PrayerRepository {
  Stream<List<PrayerRequestEntity>> getPrayerRequests({
    String? userId,
    String? congregationId,
    String? filterCongregationId,
    bool isAdmin = false,
    bool canSeeCongregationPrivate = false,
    PrayerStatus? status,
    bool? isPublic,
    bool? isPrivate,
    bool? isAnonymous,
  });
  Stream<PrayerRequestEntity?> watchPrayerRequestById(String id);
  Future<void> addPrayerRequest(PrayerRequestEntity request);
  Future<void> updatePrayerRequest(PrayerRequestEntity request);
  Future<void> deletePrayerRequest(String id);
  Future<void> incrementPrayerCount(String id);
  Future<void> prayForRequest(String requestId, String userId);
  Future<PrayerRequestEntity?> getPrayerRequestById(String id);
}
