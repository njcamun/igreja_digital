class ProjectEntity {
  final String id;
  final String name;
  final String description;
  final List<String> objectives;
  final String leaderId;
  final String leaderName;
  final double progress; // 0.0 to 1.0
  final List<String> imageUrls;
  final String contact;
  final String congregationId;
  final DateTime startDate;

  ProjectEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.objectives,
    required this.leaderId,
    required this.leaderName,
    required this.progress,
    required this.imageUrls,
    required this.contact,
    required this.congregationId,
    required this.startDate,
  });
}
