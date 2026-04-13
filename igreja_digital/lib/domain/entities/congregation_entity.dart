class CongregationEntity {
  final String id;
  final String name;
  final String description;
  final String address;
  final String city;
  final String province;
  final String country;
  final double latitude;
  final double longitude;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String leaderName;
  final String? leaderId;
  final List<String> serviceTimes;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  CongregationEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.province,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.whatsappNumber,
    required this.email,
    required this.leaderName,
    this.leaderId,
    required this.serviceTimes,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });
}
