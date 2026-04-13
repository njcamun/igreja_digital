enum EventType { culto, vigilia, ensaio, reuniao, evangelismo, conferencia, outro }

class EventEntity {
  final String id;
  final String title;
  final String description;
  final EventType type;
  final String congregationId;
  final bool isGlobal;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String location;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.congregationId,
    required this.isGlobal,
    required this.startDateTime,
    required this.endDateTime,
    required this.location,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFuture => startDateTime.isAfter(DateTime.now());
}
