import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/prayer_request_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/prayer_provider.dart';

class PrayerDetailScreen extends ConsumerWidget {
  final PrayerRequestEntity prayer;
  const PrayerDetailScreen({super.key, required this.prayer});

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    PrayerRequestEntity prayer,
    PrayerStatus newStatus,
  ) async {
    final updated = prayer.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await ref.read(prayerRepositoryProvider).updatePrayerRequest(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estado atualizado para ${newStatus.label}.',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _archiveRequest(
    BuildContext context,
    WidgetRef ref,
    PrayerRequestEntity prayer,
  ) async {
    final updated = prayer.copyWith(
      isActive: true,
      status: PrayerStatus.archived,
      updatedAt: DateTime.now(),
    );
    await ref.read(prayerRepositoryProvider).updatePrayerRequest(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido arquivado.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final prayerAsync = ref.watch(prayerRequestByIdStreamProvider(prayer.id));
    final congregationsAsync = ref.watch(allCongregationsStreamProvider);

    return prayerAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Detalhe do pedido')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Detalhe do pedido')),
        body: Center(child: Text('Erro ao carregar pedido: $error')),
      ),
      data: (currentPrayer) {
        if (currentPrayer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhe do pedido')),
            body: const Center(child: Text('Pedido de oração não encontrado.')),
          );
        }

        final isAuthor = user?.uid == currentPrayer.userId;
        final canManage =
            user?.role == UserRole.admin ||
            (user?.role == UserRole.lider &&
                user?.congregationId == currentPrayer.congregationId);
        final congregationName = congregationsAsync.maybeWhen(
          data: (congregations) {
            final congregationId = currentPrayer.congregationId;
            if (congregationId == null || congregationId.isEmpty) {
              return 'Sem congregação';
            }
            for (final congregation in congregations) {
              if (congregation.id == congregationId) {
                return congregation.name;
              }
            }
            return 'Congregação indisponível';
          },
          orElse: () => 'A carregar congregação...',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalhe do pedido'),
            actions: [
              if (canManage)
                PopupMenuButton<PrayerStatus>(
                  icon: const Icon(Icons.edit_note),
                  onSelected: (status) =>
                      _updateStatus(context, ref, currentPrayer, status),
                  itemBuilder: (_) {
                    return PrayerStatus.values
                        .map(
                          (status) => PopupMenuItem<PrayerStatus>(
                            value: status,
                            child: Text('Estado: ${status.label}'),
                          ),
                        )
                        .toList();
                  },
                ),
              if (canManage && currentPrayer.isActive)
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Arquivar',
                  onPressed: () => _archiveRequest(context, ref, currentPrayer),
                ),
              if (isAuthor || canManage)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, currentPrayer.id),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPrayer.isAnonymous
                          ? 'Pedido anónimo'
                          : currentPrayer.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'dd MMMM yyyy, HH:mm',
                      ).format(currentPrayer.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              currentPrayer.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              currentPrayer.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Estado: ${currentPrayer.status.label}',
                  ),
                ),
                Chip(label: Text(currentPrayer.isPublic ? 'Público' : 'Privado')),
                if (currentPrayer.isAnonymous)
                  const Chip(label: Text('Anónimo')),
                Chip(
                  avatar: const Icon(Icons.church_outlined, size: 16),
                  label: Text(congregationName),
                ),
              ],
            ),
            const Divider(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      '${currentPrayer.prayerCount}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text('PESSOAS ORANDO'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: user == null
                    ? null
                    : currentPrayer.prayedByUserIds.contains(user.uid)
                    ? null
                    : () async {
                        await ref
                            .read(prayerRepositoryProvider)
                            .prayForRequest(currentPrayer.id, user.uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                currentPrayer.prayedByUserIds.contains(user.uid)
                                    ? 'Você já estava orando por este pedido.'
                                    : 'Confirmado. Você também está orando por este pedido.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.favorite),
                label: Text(
                  currentPrayer.prayedByUserIds.contains(user?.uid)
                      ? 'JÁ ESTOU ORANDO'
                      : 'ESTOU ORANDO POR ISTO',
                ),
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String prayerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('Deseja remover este pedido de oração?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(prayerRepositoryProvider)
                  .deletePrayerRequest(prayerId);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
