import '../entities/event_entity.dart';

abstract class EventRepository {
  Stream<List<EventEntity>> getEvents({String? congregationId, bool? isGlobal});
  Future<List<EventEntity>> getCachedEvents({String? congregationId, bool? isGlobal});
  Future<void> addEvent(EventEntity event);
  Future<void> updateEvent(EventEntity event);
  Future<void> deleteEvent(String id);
  Future<EventEntity?> getEventById(String id);
}
