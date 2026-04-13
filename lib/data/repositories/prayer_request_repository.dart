import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:igreja_digital/domain/models/prayer_request.dart';

class PrayerRequestRepository {
  final FirebaseFirestore _firestore;

  PrayerRequestRepository(this._firestore);

  Future<List<PrayerRequest>> getActivePrayerRequests() async {
    final querySnapshot = await _firestore
        .collection('prayer_requests')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => PrayerRequest.fromFirestore(doc))
        .toList();
  }

  Future<void> addPrayerRequest(String title, String description, bool isAnonymous) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final requestData = {
      'title': title,
      'description': description,
      'isAnonymous': isAnonymous,
      'userId': user.uid,
      'userName': isAnonymous ? null : user.displayName ?? 'Usuário Anônimo',
      'prayerCount': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('prayer_requests').add(requestData);
  }

  Future<void> incrementPrayerCount(String requestId) async {
    final docRef = _firestore.collection('prayer_requests').doc(requestId);
    await docRef.update({
      'prayerCount': FieldValue.increment(1),
    });
  }
}