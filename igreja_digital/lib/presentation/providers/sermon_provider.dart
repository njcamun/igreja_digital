import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sermon_repository_impl.dart';
import '../../domain/entities/sermon_entity.dart';
import '../../domain/repositories/sermon_repository.dart';
import 'auth_provider.dart';
import '../../domain/entities/user_entity.dart';

final sermonRepositoryProvider = Provider<SermonRepository>((ref) {
  return SermonRepositoryImpl();
});

final sermonsStreamProvider = StreamProvider<List<SermonEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(sermonRepositoryProvider);

  if (user == null) {
    return Stream.value(const <SermonEntity>[]);
  }

  if (user.role == UserRole.visitante) {
    return repository.getSermons(
      congregationId: null,
      isPublished: true,
    );
  }

  final congregationId = user.congregationId;
  final hasValidCongregation =
      congregationId != null &&
      congregationId.isNotEmpty &&
      congregationId != visitorCongregationId;

  if (user.role != UserRole.admin && !hasValidCongregation) {
    return Stream.value(const <SermonEntity>[]);
  }

  // Admin vê publicados de todas congregações.
  // Líder e membro veem publicados da própria congregação.
  return repository.getSermons(
    congregationId: user.role == UserRole.admin ? null : congregationId,
    isPublished: true,
  );
});
