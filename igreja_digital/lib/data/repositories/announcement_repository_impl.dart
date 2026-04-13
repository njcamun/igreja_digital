import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../models/announcement_model.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _cacheKey({String? congregationId, bool? isGlobal}) {
    return 'announcements_cache_${congregationId ?? 'all'}_${isGlobal?.toString() ?? 'null'}';
  }

  Future<void> _saveCache(
    List<AnnouncementEntity> announcements, {
    String? congregationId,
    bool? isGlobal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = announcements
        .map(
          (a) => {
            'id': a.id,
            'title': a.title,
            'content': a.content,
            'priority': a.priority.name,
            'congregationId': a.congregationId,
            'isGlobal': a.isGlobal,
            'publishedBy': a.publishedBy,
            'createdAt': a.createdAt.toIso8601String(),
            'updatedAt': a.updatedAt.toIso8601String(),
            'expiresAt': a.expiresAt?.toIso8601String(),
            'isActive': a.isActive,
          },
        )
        .toList();

    await prefs.setString(
      _cacheKey(congregationId: congregationId, isGlobal: isGlobal),
      jsonEncode(payload),
    );
  }

  @override
  Stream<List<AnnouncementEntity>> getAnnouncements({String? congregationId, bool? isGlobal}) {
    Query query = _firestore.collection('announcements').where('isActive', isEqualTo: true);

    if (congregationId != null) {
      query = query.where(Filter.or(
        Filter('congregationId', isEqualTo: congregationId),
        Filter('isGlobal', isEqualTo: true),
      ));
    } else if (isGlobal != null) {
      query = query.where('isGlobal', isEqualTo: isGlobal);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final announcements = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            return AnnouncementModel.fromMap(data, doc.id);
          })
          .toList();

      _saveCache(
        announcements,
        congregationId: congregationId,
        isGlobal: isGlobal,
      );
      return announcements;
    });
  }

  @override
  Future<List<AnnouncementEntity>> getCachedAnnouncements({String? congregationId, bool? isGlobal}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _cacheKey(congregationId: congregationId, isGlobal: isGlobal),
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();

    return decoded
        .map(
          (a) => AnnouncementEntity(
            id: a['id'] as String? ?? '',
            title: a['title'] as String? ?? '',
            content: a['content'] as String? ?? '',
            priority: AnnouncementPriority.values.firstWhere(
              (p) => p.name == (a['priority'] as String? ?? ''),
              orElse: () => AnnouncementPriority.normal,
            ),
            congregationId: a['congregationId'] as String? ?? '',
            isGlobal: a['isGlobal'] as bool? ?? false,
            publishedBy: a['publishedBy'] as String? ?? '',
            createdAt: DateTime.tryParse(a['createdAt'] as String? ?? '') ??
                DateTime.now(),
            updatedAt: DateTime.tryParse(a['updatedAt'] as String? ?? '') ??
                DateTime.now(),
            expiresAt: (a['expiresAt'] as String?) == null
                ? null
                : DateTime.tryParse(a['expiresAt'] as String),
            isActive: a['isActive'] as bool? ?? true,
          ),
        )
        .toList();
  }

  @override
  Future<void> addAnnouncement(AnnouncementEntity announcement) async {
    final model = AnnouncementModel.fromEntity(announcement);
    await _firestore.collection('announcements').add(model.toMap());
  }

  @override
  Future<void> updateAnnouncement(AnnouncementEntity announcement) async {
    final model = AnnouncementModel.fromEntity(announcement);
    await _firestore.collection('announcements').doc(announcement.id).update(model.toMap());
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('announcements').doc(id).delete();
  }

  @override
  Future<AnnouncementEntity?> getAnnouncementById(String id) async {
    final doc = await _firestore.collection('announcements').doc(id).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return AnnouncementModel.fromMap(data, doc.id);
  }
}
