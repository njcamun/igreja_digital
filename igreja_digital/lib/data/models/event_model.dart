import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event_entity.dart';

class EventModel extends EventEntity {
  EventModel({
    required super.id,
    required super.title,
    required super.description,
    required super.type,
    required super.congregationId,
    required super.isGlobal,
    required super.startDateTime,
    required super.endDateTime,
    required super.location,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    return EventModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: EventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EventType.outro,
      ),
      congregationId: map['congregationId'] ?? '',
      isGlobal: map['isGlobal'] ?? false,
      startDateTime: (map['startDateTime'] as Timestamp).toDate(),
      endDateTime: (map['endDateTime'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'congregationId': congregationId,
      'isGlobal': isGlobal,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'location': location,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventModel.fromEntity(EventEntity entity) {
    return EventModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      type: entity.type,
      congregationId: entity.congregationId,
      isGlobal: entity.isGlobal,
      startDateTime: entity.startDateTime,
      endDateTime: entity.endDateTime,
      location: entity.location,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
