import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import 'auth_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepositoryImpl();
});

final eventsStreamProvider = StreamProvider<List<EventEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(eventRepositoryProvider);
  
  // Se for admin, vê tudo. Se for membro/líder, vê da sua congregação + globais.
  // Se for visitante, vê apenas globais (simplificação para o MVP).
  if (user == null) {
    return repository.getEvents(isGlobal: true);
  }
  
  return repository.getEvents(congregationId: user.congregationId);
});
