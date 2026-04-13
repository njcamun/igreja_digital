import 'dart:io';
import '../entities/sermon_entity.dart';

abstract class SermonRepository {
  Stream<List<SermonEntity>> getSermons({String? congregationId, bool? isPublished});
  Future<SermonEntity?> getSermonById(String id);
  Future<void> addSermon(SermonEntity sermon);
  Future<void> updateSermon(SermonEntity sermon);
  Future<void> deleteSermon(String id, String audioUrl);
  Future<String> uploadAudio(File file, String fileName, String congregationId);
}
