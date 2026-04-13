import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/announcement_repository.dart';
import 'auth_provider.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepositoryImpl();
});

final announcementsStreamProvider = StreamProvider<List<AnnouncementEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(announcementRepositoryProvider);

  if (user?.role == UserRole.visitante) {
    return Stream.value(const <AnnouncementEntity>[]);
  }
  
  if (user == null) {
    return repository.getAnnouncements(isGlobal: true);
  }
  
  return repository.getAnnouncements(congregationId: user.congregationId);
});
