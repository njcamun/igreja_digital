import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../domain/entities/sermon_entity.dart';
import '../../domain/repositories/sermon_repository.dart';
import '../models/sermon_model.dart';

class SermonRepositoryImpl implements SermonRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _deleteStorageFileByUrl(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Cleanup is best effort. Ignore invalid or already deleted files.
    }
  }

  @override
  Stream<List<SermonEntity>> getSermons({String? congregationId, bool? isPublished}) {
    Query query = _firestore.collection('sermons');

    if (congregationId != null) {
      query = query.where('congregationId', isEqualTo: congregationId);
    }
    if (isPublished != null) {
      query = query.where('isPublished', isEqualTo: isPublished);
    }

    return query.orderBy('sermonDate', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SermonModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  @override
  Future<SermonEntity?> getSermonById(String id) async {
    final doc = await _firestore.collection('sermons').doc(id).get();
    if (doc.exists) {
      return SermonModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  @override
  Future<void> addSermon(SermonEntity sermon) async {
    final model = SermonModel.fromEntity(sermon);
    await _firestore.collection('sermons').doc(sermon.id).set(model.toMap());
  }

  @override
  Future<void> updateSermon(SermonEntity sermon) async {
    final currentDoc = await _firestore.collection('sermons').doc(sermon.id).get();
    final previousAudioUrl = currentDoc.data()?['audioUrl'] as String? ?? '';

    final model = SermonModel.fromEntity(sermon);
    await _firestore.collection('sermons').doc(sermon.id).update(model.toMap());

    if (previousAudioUrl.isNotEmpty && previousAudioUrl != sermon.audioUrl) {
      await _deleteStorageFileByUrl(previousAudioUrl);
    }
  }

  @override
  Future<void> deleteSermon(String id, String audioUrl) async {
    await _firestore.collection('sermons').doc(id).delete();
    await _deleteStorageFileByUrl(audioUrl);
  }

  @override
  Future<String> uploadAudio(File file, String fileName, String congregationId) async {
    final ref = _storage.ref().child('sermons/$congregationId/$fileName');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
