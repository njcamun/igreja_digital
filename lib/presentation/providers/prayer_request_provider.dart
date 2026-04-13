import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:igreja_digital/domain/models/prayer_request.dart';
import 'package:igreja_digital/data/repositories/prayer_request_repository.dart';

final prayerRequestRepositoryProvider = Provider<PrayerRequestRepository>((ref) {
  return PrayerRequestRepository(FirebaseFirestore.instance);
});

final prayerRequestsProvider = StateNotifierProvider<PrayerRequestNotifier, AsyncValue<List<PrayerRequest>>>((ref) {
  final repository = ref.watch(prayerRequestRepositoryProvider);
  return PrayerRequestNotifier(repository);
});

class PrayerRequestNotifier extends StateNotifier<AsyncValue<List<PrayerRequest>>> {
  final PrayerRequestRepository _repository;

  PrayerRequestNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadPrayerRequests();
  }

  Future<void> loadPrayerRequests() async {
    state = const AsyncValue.loading();
    try {
      final requests = await _repository.getActivePrayerRequests();
      state = AsyncValue.data(requests);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addPrayerRequest(String title, String description, bool isAnonymous) async {
    try {
      await _repository.addPrayerRequest(title, description, isAnonymous);
      await loadPrayerRequests(); // Reload after adding
    } catch (e) {
      // Handle error - could add error state
      rethrow;
    }
  }

  Future<void> incrementPrayerCount(String requestId) async {
    try {
      await _repository.incrementPrayerCount(requestId);
      await loadPrayerRequests(); // Reload to update counts
    } catch (e) {
      // Handle error
      rethrow;
    }
  }
}