import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _cacheKey({String? congregationId, bool? isGlobal}) {
    return 'events_cache_${congregationId ?? 'all'}_${isGlobal?.toString() ?? 'null'}';
  }

  Future<void> _saveCache(
    List<EventEntity> events, {
    String? congregationId,
    bool? isGlobal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = events
        .map(
          (e) => {
            'id': e.id,
            'title': e.title,
            'description': e.description,
            'type': e.type.name,
            'congregationId': e.congregationId,
            'isGlobal': e.isGlobal,
            'startDateTime': e.startDateTime.toIso8601String(),
            'endDateTime': e.endDateTime.toIso8601String(),
            'location': e.location,
            'createdBy': e.createdBy,
            'createdAt': e.createdAt.toIso8601String(),
            'updatedAt': e.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await prefs.setString(
      _cacheKey(congregationId: congregationId, isGlobal: isGlobal),
      jsonEncode(payload),
    );
  }

  @override
  Stream<List<EventEntity>> getEvents({String? congregationId, bool? isGlobal}) {
    Query query = _firestore.collection('events');

    // Se congregationId for fornecido, filtramos por ele ou por eventos globais
    if (congregationId != null) {
      query = query.where(Filter.or(
        Filter('congregationId', isEqualTo: congregationId),
        Filter('isGlobal', isEqualTo: true),
      ));
    } else if (isGlobal != null) {
      query = query.where('isGlobal', isEqualTo: isGlobal);
    }

    return query
        .orderBy('startDateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            return EventModel.fromMap(data, doc.id);
          })
          .toList();

      _saveCache(events, congregationId: congregationId, isGlobal: isGlobal);
      return events;
    });
  }

  @override
  Future<List<EventEntity>> getCachedEvents({String? congregationId, bool? isGlobal}) async {
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
          (e) => EventEntity(
            id: e['id'] as String? ?? '',
            title: e['title'] as String? ?? '',
            description: e['description'] as String? ?? '',
            type: EventType.values.firstWhere(
              (t) => t.name == (e['type'] as String? ?? ''),
              orElse: () => EventType.outro,
            ),
            congregationId: e['congregationId'] as String? ?? '',
            isGlobal: e['isGlobal'] as bool? ?? false,
            startDateTime: DateTime.tryParse(e['startDateTime'] as String? ?? '') ??
                DateTime.now(),
            endDateTime: DateTime.tryParse(e['endDateTime'] as String? ?? '') ??
                DateTime.now(),
            location: e['location'] as String? ?? '',
            createdBy: e['createdBy'] as String? ?? '',
            createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ??
                DateTime.now(),
            updatedAt: DateTime.tryParse(e['updatedAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  @override
  Future<void> addEvent(EventEntity event) async {
    final model = EventModel.fromEntity(event);
    await _firestore.collection('events').add(model.toMap());
  }

  @override
  Future<void> updateEvent(EventEntity event) async {
    final model = EventModel.fromEntity(event);
    await _firestore.collection('events').doc(event.id).update(model.toMap());
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _firestore.collection('events').doc(id).delete();
  }

  @override
  Future<EventEntity?> getEventById(String id) async {
    final doc = await _firestore.collection('events').doc(id).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return EventModel.fromMap(data, doc.id);
  }
}
