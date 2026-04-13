import '../entities/congregation_entity.dart';
import 'dart:io';

abstract class CongregationRepository {
  Stream<List<CongregationEntity>> getCongregations({bool onlyActive = true});
  Future<void> addCongregation(CongregationEntity congregation);
  Future<void> updateCongregation(CongregationEntity congregation);
  Future<void> deleteCongregation(String id);
  Future<void> reactivateCongregation(String id);
  Future<CongregationEntity?> getCongregationById(String id);
  Future<String> uploadCongregationImage(File file, String congregationId, String fileName);
}
