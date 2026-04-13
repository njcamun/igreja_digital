import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../domain/entities/congregation_entity.dart';
import '../../domain/repositories/congregation_repository.dart';
import '../models/congregation_model.dart';

class CongregationRepositoryImpl implements CongregationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Stream<List<CongregationEntity>> getCongregations({bool onlyActive = true}) {
    Query query = _firestore.collection('congregations');
    
    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CongregationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  @override
  Future<void> addCongregation(CongregationEntity congregation) async {
    final model = CongregationModel.fromEntity(congregation);
    await _firestore.collection('congregations').doc(congregation.id).set(model.toMap());
  }

  @override
  Future<void> updateCongregation(CongregationEntity congregation) async {
    final model = CongregationModel.fromEntity(congregation);
    await _firestore.collection('congregations').doc(congregation.id).update(model.toMap());
  }

  @override
  Future<void> deleteCongregation(String id) async {
    // Implementação de desativação lógica ou remoção física
    await _firestore.collection('congregations').doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reactivateCongregation(String id) async {
    await _firestore.collection('congregations').doc(id).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<CongregationEntity?> getCongregationById(String id) async {
    final doc = await _firestore.collection('congregations').doc(id).get();
    if (doc.exists) {
      return CongregationModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  @override
  Future<String> uploadCongregationImage(File file, String congregationId, String fileName) async {
    final ref = _storage.ref().child('congregations/$congregationId/$fileName');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
