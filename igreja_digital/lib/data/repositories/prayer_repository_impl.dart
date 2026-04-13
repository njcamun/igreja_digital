import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/prayer_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/prayer_repository.dart';
import '../models/prayer_request_model.dart';

class PrayerRepositoryImpl implements PrayerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query _buildBaseQuery({
    String? filterCongregationId,
    PrayerStatus? status,
  }) {
    Query query = _firestore.collection('prayer_requests');

    // Pedidos arquivados legados podem estar com isActive=false.
    if (status != PrayerStatus.archived) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (filterCongregationId != null && filterCongregationId.isNotEmpty) {
      query = query.where('congregationId', isEqualTo: filterCongregationId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query;
  }

  Stream<List<PrayerRequestEntity>> _runQuery(Query query) {
    return query.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return PrayerRequestModel.fromMap(data, doc.id);
      }).toList();
    });
  }

  Stream<List<PrayerRequestEntity>> _mergePrayerStreams(
    List<Stream<List<PrayerRequestEntity>>> streams,
  ) {
    if (streams.isEmpty) {
      return Stream.value(const <PrayerRequestEntity>[]);
    }
    if (streams.length == 1) {
      return streams.first;
    }

    final controller = StreamController<List<PrayerRequestEntity>>.broadcast();
    final latest = List<List<PrayerRequestEntity>?>.filled(
      streams.length,
      null,
    );
    final subscriptions = <StreamSubscription<List<PrayerRequestEntity>>>[];

    void emitMergedIfReady() {
      if (latest.any((value) => value == null)) {
        return;
      }

      final byId = <String, PrayerRequestEntity>{};
      for (final chunk in latest.whereType<List<PrayerRequestEntity>>()) {
        for (final prayer in chunk) {
          byId[prayer.id] = prayer;
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }

    for (var i = 0; i < streams.length; i++) {
      final stream = streams[i];
      subscriptions.add(
        stream.listen(
          (data) {
            latest[i] = data;
            emitMergedIfReady();
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Stream<List<PrayerRequestEntity>> _applyStatusFilter(
    Stream<List<PrayerRequestEntity>> source,
    PrayerStatus? status,
  ) {
    if (status == null) {
      return source;
    }

    return source.map(
      (items) => items.where((item) => item.status == status).toList(),
    );
  }

  @override
  Stream<List<PrayerRequestEntity>> getPrayerRequests({
    String? userId,
    String? congregationId,
    String? filterCongregationId,
    bool isAdmin = false,
    bool canSeeCongregationPrivate = false,
    PrayerStatus? status,
    bool? isPublic,
    bool? isPrivate,
    bool? isAnonymous,
  }) {
    Query query = _buildBaseQuery(
      filterCongregationId: filterCongregationId,
      status: status,
    );

    // Para admins, aplicar filtros de visibilidade diretamente
    if (isAdmin) {
      if (isPublic != null) {
        query = query.where('isPublic', isEqualTo: isPublic);
      }
      if (isPrivate != null) {
        query = query.where('isPrivate', isEqualTo: isPrivate);
      }
      if (isAnonymous != null) {
        query = query.where('isAnonymous', isEqualTo: isAnonymous);
      }
    } else {
      final baseQuery = _buildBaseQuery(
        filterCongregationId: filterCongregationId,
        status: null,
      );

      // Para usuários não-admin, compor resultado por streams simples
      // (evita OR em query, que aumenta dependência de índices compostos).
      if (isPublic == true) {
        return _applyStatusFilter(
          _runQuery(baseQuery.where('isPublic', isEqualTo: true)),
          status,
        );
      } else if (isPrivate == true) {
        final streams = <Stream<List<PrayerRequestEntity>>>[];
        if (userId != null) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              )
                  .where('isPrivate', isEqualTo: true)
                  .where('userId', isEqualTo: userId),
            ),
          );
        }
        if (canSeeCongregationPrivate &&
            congregationId != null &&
            congregationId.isNotEmpty &&
          congregationId != visitorCongregationId) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              )
                  .where('isPrivate', isEqualTo: true)
                  .where('congregationId', isEqualTo: congregationId),
            ),
          );
        }
        return _applyStatusFilter(_mergePrayerStreams(streams), status);
      } else if (isAnonymous == true) {
        final streams = <Stream<List<PrayerRequestEntity>>>[];

        streams.add(
          _runQuery(
            _buildBaseQuery(
              filterCongregationId: filterCongregationId,
              status: null,
            )
                .where('isAnonymous', isEqualTo: true)
                .where('isPublic', isEqualTo: true),
          ),
        );

        if (userId != null) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              )
                  .where('isAnonymous', isEqualTo: true)
                  .where('userId', isEqualTo: userId),
            ),
          );
        }

        if (canSeeCongregationPrivate &&
            congregationId != null &&
            congregationId.isNotEmpty &&
          congregationId != visitorCongregationId) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              )
                  .where('isAnonymous', isEqualTo: true)
                  .where('isPrivate', isEqualTo: true)
                  .where('congregationId', isEqualTo: congregationId),
            ),
          );
        }

        return _applyStatusFilter(_mergePrayerStreams(streams), status);
      } else {
        final streams = <Stream<List<PrayerRequestEntity>>>[];

        streams.add(
          _runQuery(
            _buildBaseQuery(
              filterCongregationId: filterCongregationId,
              status: null,
            ).where('isPublic', isEqualTo: true),
          ),
        );

        if (userId != null) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              ).where('userId', isEqualTo: userId),
            ),
          );
        }

        if (canSeeCongregationPrivate &&
            congregationId != null &&
            congregationId.isNotEmpty &&
          congregationId != visitorCongregationId) {
          streams.add(
            _runQuery(
              _buildBaseQuery(
                filterCongregationId: filterCongregationId,
                status: null,
              )
                  .where('isPrivate', isEqualTo: true)
                  .where('congregationId', isEqualTo: congregationId),
            ),
          );
        }

        return _applyStatusFilter(_mergePrayerStreams(streams), status);
      }
    }

    return _runQuery(query);
  }

  @override
  Future<void> addPrayerRequest(PrayerRequestEntity request) async {
    final model = PrayerRequestModel.fromEntity(request);
    await _firestore
        .collection('prayer_requests')
        .doc(request.id)
        .set(model.toMap());
  }

  @override
  Stream<PrayerRequestEntity?> watchPrayerRequestById(String id) {
    return _firestore.collection('prayer_requests').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      return PrayerRequestModel.fromMap(data, doc.id);
    });
  }

  @override
  Future<void> updatePrayerRequest(PrayerRequestEntity request) async {
    final model = PrayerRequestModel.fromEntity(request);
    await _firestore
        .collection('prayer_requests')
        .doc(request.id)
        .update(model.toMap());
  }

  @override
  Future<void> deletePrayerRequest(String id) async {
    await _firestore.collection('prayer_requests').doc(id).update({
      'isActive': false,
    });
  }

  @override
  Future<void> incrementPrayerCount(String id) async {
    await _firestore.collection('prayer_requests').doc(id).update({
      'prayerCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> prayForRequest(String requestId, String userId) async {
    final ref = _firestore.collection('prayer_requests').doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Pedido de oração não encontrado.');
      }
      final data = snapshot.data();
      final prayedBy = List<String>.from(data?['prayedByUserIds'] ?? []);
      if (prayedBy.contains(userId)) {
        return;
      }
      final currentStatus = (data?['status'] as String?) ?? PrayerStatus.open.name;
      transaction.update(ref, {
        'prayerCount': FieldValue.increment(1),
        'prayedByUserIds': FieldValue.arrayUnion([userId]),
        'status': currentStatus == PrayerStatus.open.name
            ? PrayerStatus.praying.name
            : currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<PrayerRequestEntity?> getPrayerRequestById(String id) async {
    final doc = await _firestore.collection('prayer_requests').doc(id).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return PrayerRequestModel.fromMap(data, doc.id);
  }
}
