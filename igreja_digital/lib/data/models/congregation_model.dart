import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/congregation_entity.dart';

class CongregationModel extends CongregationEntity {
  CongregationModel({
    required super.id,
    required super.name,
    required super.description,
    required super.address,
    required super.city,
    required super.province,
    required super.country,
    required super.latitude,
    required super.longitude,
    required super.phone,
    required super.whatsappNumber,
    required super.email,
    required super.leaderName,
    super.leaderId,
    required super.serviceTimes,
    super.imageUrl,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
  });

  factory CongregationModel.fromMap(Map<String, dynamic> map, String id) {
    return CongregationModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      province: map['province'] ?? '',
      country: map['country'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      phone: map['phone'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      email: map['email'] ?? '',
      leaderName: map['leaderName'] ?? '',
      leaderId: map['leaderId'],
      serviceTimes: List<String>.from(map['serviceTimes'] ?? []),
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'province': province,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'leaderName': leaderName,
      'leaderId': leaderId,
      'serviceTimes': serviceTimes,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  factory CongregationModel.fromEntity(CongregationEntity entity) {
    return CongregationModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      address: entity.address,
      city: entity.city,
      province: entity.province,
      country: entity.country,
      latitude: entity.latitude,
      longitude: entity.longitude,
      phone: entity.phone,
      whatsappNumber: entity.whatsappNumber,
      email: entity.email,
      leaderName: entity.leaderName,
      leaderId: entity.leaderId,
      serviceTimes: entity.serviceTimes,
      imageUrl: entity.imageUrl,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
    );
  }
}
