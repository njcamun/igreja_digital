import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/prayer_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/prayer_repository.dart';
import '../../data/repositories/prayer_repository_impl.dart';
import 'auth_provider.dart';

enum PrayerVisibilityFilter { all, public, private, anonymous }

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepositoryImpl();
});

final prayerRequestByIdStreamProvider =
    StreamProvider.family<PrayerRequestEntity?, String>((ref, id) {
      return ref.watch(prayerRepositoryProvider).watchPrayerRequestById(id);
    });

final prayerStatusFilterProvider = StateProvider<PrayerStatus?>((_) => null);
final prayerVisibilityFilterProvider = StateProvider<PrayerVisibilityFilter>(
  (_) => PrayerVisibilityFilter.all,
);
final prayerCongregationFilterProvider = StateProvider<String?>((_) => null);

final prayerRequestsStreamProvider = StreamProvider<List<PrayerRequestEntity>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const <PrayerRequestEntity>[]);
  }

  final statusFilter = ref.watch(prayerStatusFilterProvider);
  final visibilityFilter = ref.watch(prayerVisibilityFilterProvider);
  final congregationFilter = ref.watch(prayerCongregationFilterProvider);

  final isAdmin = user.role == UserRole.admin;
  final canSeeCongregationPrivate = user.role == UserRole.lider;
  final isVisitor = user.role == UserRole.visitante;

  bool? isPublic;
  bool? isPrivate;
  bool? isAnonymous;
  switch (visibilityFilter) {
    case PrayerVisibilityFilter.public:
      isPublic = true;
      isPrivate = false;
      break;
    case PrayerVisibilityFilter.private:
      isPublic = false;
      isPrivate = true;
      break;
    case PrayerVisibilityFilter.anonymous:
      isAnonymous = true;
      break;
    case PrayerVisibilityFilter.all:
      break;
  }

  if (isVisitor) {
    // Visitante vê somente orações anónimas públicas.
    isPublic = true;
    isPrivate = false;
    isAnonymous = true;
  }

  return ref
      .watch(prayerRepositoryProvider)
      .getPrayerRequests(
        userId: user.uid,
        congregationId: user.congregationId,
        filterCongregationId: congregationFilter,
        isAdmin: isAdmin,
        canSeeCongregationPrivate: canSeeCongregationPrivate,
        status: statusFilter,
        isPublic: isPublic,
        isPrivate: isPrivate,
        isAnonymous: isAnonymous,
      );
});

final homePrayerRequestsStreamProvider =
    StreamProvider<List<PrayerRequestEntity>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return Stream.value(const <PrayerRequestEntity>[]);
      }

      final isAdmin = user.role == UserRole.admin;
      final canSeeCongregationPrivate = user.role == UserRole.lider;

      return ref
          .watch(prayerRepositoryProvider)
          .getPrayerRequests(
            userId: user.uid,
            congregationId: user.congregationId,
            isAdmin: isAdmin,
            canSeeCongregationPrivate: canSeeCongregationPrivate,
            // Home sempre mostra feed padrão sem filtros mutáveis da tela de lista.
            status: null,
            isPublic: null,
            isPrivate: null,
            isAnonymous: null,
          );
    });
