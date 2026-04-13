import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final bool isAnonymous;
  final String? userId;
  final String? userName;
  final int prayerCount;
  final bool isActive;
  final DateTime createdAt;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.isAnonymous,
    this.userId,
    this.userName,
    required this.prayerCount,
    required this.isActive,
    required this.createdAt,
  });

  factory PrayerRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrayerRequest(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      userId: data['userId'],
      userName: data['userName'],
      prayerCount: data['prayerCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isAnonymous': isAnonymous,
      'userId': userId,
      'userName': userName,
      'prayerCount': prayerCount,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}