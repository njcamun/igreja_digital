import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';

class UserAdminService {
  UserAdminService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<UserEntity>> watchUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<int> watchMemberCount() {
    // Conta utilizadores com role membro, lider ou admin (excluindo visitantes).
    return _firestore
        .collection('users')
        .where('role', whereIn: [
          UserRole.membro.name,
          UserRole.lider.name,
          UserRole.admin.name,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<UserEntity>> watchUsersManagedBy(UserEntity manager) {
    if (manager.role == UserRole.admin) {
      return watchUsers();
    }

    if (manager.role != UserRole.lider ||
        manager.congregationId == null ||
        manager.congregationId!.isEmpty ||
        manager.congregationId == visitorCongregationId) {
      return Stream.value(const <UserEntity>[]);
    }

    final leaderCongregationId = manager.congregationId!;
    final controller = StreamController<List<UserEntity>>();

    List<UserEntity> members = const <UserEntity>[];
    List<UserEntity> visitorsInCongregation = const <UserEntity>[];
    List<UserEntity> visitorsNoCongregation = const <UserEntity>[];
    List<UserEntity> visitorsEmptyCongregation = const <UserEntity>[];

    void emitMerged() {
      final mergedByUid = <String, UserEntity>{};
      for (final user in [
        ...members,
        ...visitorsInCongregation,
        ...visitorsNoCongregation,
        ...visitorsEmptyCongregation,
      ]) {
        mergedByUid[user.uid] = user;
      }

      final merged = mergedByUid.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    StreamSubscription<List<UserEntity>>? membersSub;
    StreamSubscription<List<UserEntity>>? visitorsCongSub;
    StreamSubscription<List<UserEntity>>? visitorsNullSub;
    StreamSubscription<List<UserEntity>>? visitorsEmptySub;

    membersSub = _watchUsersFromQuery(
      _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.membro.name)
          .where('congregationId', isEqualTo: leaderCongregationId),
    ).listen((value) {
      members = value;
      emitMerged();
    }, onError: controller.addError);

    visitorsCongSub = _watchUsersFromQuery(
      _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.visitante.name)
          .where('congregationId', isEqualTo: leaderCongregationId),
    ).listen((value) {
      visitorsInCongregation = value;
      emitMerged();
    }, onError: controller.addError);

    visitorsNullSub = _watchUsersFromQuery(
      _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.visitante.name)
          .where('congregationId', isNull: true),
    ).listen((value) {
      visitorsNoCongregation = value;
      emitMerged();
    }, onError: controller.addError);

    visitorsEmptySub = _watchUsersFromQuery(
      _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.visitante.name)
          .where('congregationId', whereIn: ['', visitorCongregationId]),
    ).listen((value) {
      visitorsEmptyCongregation = value;
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await membersSub?.cancel();
      await visitorsCongSub?.cancel();
      await visitorsNullSub?.cancel();
      await visitorsEmptySub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<UserEntity>> _watchUsersFromQuery(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    required UserRole role,
    required bool isActive,
    String? congregationId,
    String? fullName,
  }) async {
    final normalizedCongregationId = congregationId?.trim();
    final requiresCongregation =
      role == UserRole.membro || role == UserRole.lider;

    if (requiresCongregation &&
        (normalizedCongregationId == null ||
            normalizedCongregationId.isEmpty ||
            normalizedCongregationId == visitorCongregationId)) {
      throw Exception('Membro e líder devem ter uma congregação válida.');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final existing = await userRef.get();
    final existingData = existing.data();
    final hasMembershipDate = existingData != null && existingData['membershipDate'] != null;

    final payload = <String, dynamic>{
      'role': role.name,
      'isActive': isActive,
      'congregationId': normalizedCongregationId,
      ...?(fullName == null ? null : {'fullName': fullName}),
    };

    if (requiresCongregation && !hasMembershipDate) {
      payload['membershipDate'] = Timestamp.now();
    }

    await userRef.update(payload);
  }

  Future<void> updateUserCongregationChoice({
    required UserEntity user,
    required String congregationId,
  }) async {
    if ((user.role == UserRole.membro || user.role == UserRole.lider) &&
        (congregationId.trim().isEmpty || congregationId == visitorCongregationId)) {
      throw Exception('Membro e líder devem manter uma congregação válida.');
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final existingSnapshot = await userDocRef.get();

    if (!existingSnapshot.exists) {
      await userDocRef.set(UserModel.fromEntity(user).toMap());
    }

    await userDocRef.update({
      'congregationId': congregationId,
    });
  }

  Future<void> updateOwnVisitorProfile({
    required String userId,
    required String fullName,
    DateTime? birthDate,
    String? maritalStatus,
    String? contact,
    String? shortBio,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'fullName': fullName,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate) : null,
      'maritalStatus': maritalStatus,
      'contact': contact,
      'shortBio': shortBio,
    });
  }

  Future<void> promoteUserToAdmin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': UserRole.admin.name,
    });
  }
}

final userAdminServiceProvider = Provider<UserAdminService>((ref) {
  return UserAdminService(FirebaseFirestore.instance);
});

final usersStreamProvider = StreamProvider<List<UserEntity>>((ref) {
  return ref.watch(userAdminServiceProvider).watchUsers();
});

final managedUsersStreamProvider =
    StreamProvider.family<List<UserEntity>, UserEntity>((ref, manager) {
  return ref.watch(userAdminServiceProvider).watchUsersManagedBy(manager);
});

/// Conta utilizadores com perfil membro, lider ou admin (como "membros" da igreja).
final memberCountStreamProvider = StreamProvider<int>((ref) {
  return ref.watch(userAdminServiceProvider).watchMemberCount();
});
