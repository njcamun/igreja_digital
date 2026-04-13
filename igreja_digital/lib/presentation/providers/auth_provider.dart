import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/notification_service.dart';

// Revertido para AuthRepositoryImpl para utilizar o Firebase real
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChanged;
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  final asyncUser = ref.watch(authStateProvider);
  return asyncUser.maybeWhen(data: (user) => user, orElse: () => null);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider para inicializar notificações quando o usuário está logado
final notificationInitializerProvider = Provider<void>((ref) {
  ref.listen<UserEntity?>(currentUserProvider, (previous, next) {
    final notificationService = ref.read(notificationServiceProvider);

    bool isValidCongregation(String? congregationId) {
      return congregationId != null &&
          congregationId.isNotEmpty &&
          congregationId != visitorCongregationId;
    }

    if (next != null && next.role != UserRole.visitante) {
      if (!notificationService.isInitialized || previous?.uid != next.uid) {
        notificationService.initialize(next.uid);
      }

      final previousCongregationId = previous?.congregationId;
      final nextCongregationId = next.congregationId;
      if (previousCongregationId != nextCongregationId) {
        if (isValidCongregation(previousCongregationId)) {
          notificationService.unsubscribeFromCongregation(
            previousCongregationId!,
          );
        }
        if (isValidCongregation(nextCongregationId)) {
          notificationService.subscribeToCongregation(nextCongregationId!);
        }
      }

      if (previous?.role != next.role) {
        if (previous != null) {
          notificationService.unsubscribeFromRole(previous.role.name);
        }
        notificationService.subscribeToRole(next.role.name);
      }
    } else if (previous != null) {
      if (isValidCongregation(previous.congregationId)) {
        notificationService.unsubscribeFromCongregation(
          previous.congregationId!,
        );
      }
      notificationService.unsubscribeFromRole(previous.role.name);
    }
  });
});
