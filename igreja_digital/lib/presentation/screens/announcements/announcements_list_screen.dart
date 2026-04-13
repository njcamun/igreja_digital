import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/announcement_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import 'announcement_detail_screen.dart';
import 'announcement_form_screen.dart';

class AnnouncementsListScreen extends ConsumerWidget {
  const AnnouncementsListScreen({super.key});

  Widget _buildFirestoreError(
    BuildContext context,
    WidgetRef ref,
    Object err,
    UserEntity? user,
  ) {
    final message = err.toString().toLowerCase();

    String title = 'Não foi possível carregar os avisos.';
    String detail = 'Tente novamente em instantes.';

    if (message.contains('unable to resolve host') ||
        message.contains('status{code=unavailable') ||
        message.contains('end of stream or ioexception')) {
      title = 'Sem ligação à internet.';
      detail =
          'Verifique a rede do dispositivo e tente novamente para carregar os avisos.';
    } else if (message.contains('failed_precondition') ||
        message.contains('requires an index')) {
      title = 'Índice do Firestore em falta.';
      detail =
          'O índice necessário ainda não está disponível. Aguarde o deploy/construção e volte a tentar.';
    }

    return FutureBuilder<List<AnnouncementEntity>>(
      future: ref.read(announcementRepositoryProvider).getCachedAnnouncements(
        congregationId: user?.congregationId,
            isGlobal: user == null ? true : null,
          ),
      builder: (context, snapshot) {
        final cached = snapshot.data ?? const <AnnouncementEntity>[];

        if (cached.isNotEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: MaterialBanner(
                  content: const Text(
                    'Ligação indisponível. A mostrar avisos guardados localmente.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(announcementsStreamProvider),
                      child: const Text('Atualizar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cached.length,
                  itemBuilder: (context, index) =>
                      _AnnouncementCard(announcement: cached[index]),
                ),
              ),
            ],
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 40),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(detail, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(announcementsStreamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAllAnnouncements(
    BuildContext context,
    WidgetRef ref,
    List<AnnouncementEntity> announcements,
  ) async {
    if (announcements.isEmpty) return;

    final inputController = TextEditingController();
    bool canDelete = false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eliminar Avisos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja eliminar ${announcements.length} avisos visíveis nesta lista?',
              ),
              const SizedBox(height: 12),
              const Text('Digite CONFIRMAR para continuar.'),
              const SizedBox(height: 8),
              TextField(
                controller: inputController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'CONFIRMAR',
                ),
                onChanged: (value) {
                  setDialogState(() {
                    canDelete = value.trim().toUpperCase() == 'CONFIRMAR';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
              child: const Text(
                'Eliminar todos',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    inputController.dispose();

    if (shouldDelete != true) return;

    for (final announcement in announcements) {
      await ref
          .read(announcementRepositoryProvider)
          .deleteAnnouncement(announcement.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${announcements.length} avisos eliminados.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role == UserRole.admin || user?.role == UserRole.lider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnnouncementFormScreen()),
              ),
            ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return const Center(child: Text('Sem avisos no momento.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteAllAnnouncements(
                      context,
                      ref,
                      announcements,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Eliminar visíveis'),
                  ),
                ),
              if (canManage) const SizedBox(height: 8),
              ...announcements.map((announcement) {
                final card = _AnnouncementCard(announcement: announcement);

                if (!canManage) {
                  return card;
                }

                return Dismissible(
                  key: ValueKey('announcement-${announcement.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar Aviso'),
                        content: Text('Deseja eliminar "${announcement.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (shouldDelete == true) {
                      await ref
                          .read(announcementRepositoryProvider)
                          .deleteAnnouncement(announcement.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aviso eliminado.')),
                        );
                      }
                      return true;
                    }

                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  child: card,
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildFirestoreError(context, ref, err, user),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementEntity announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor(announcement.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: announcement)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (announcement.priority != AnnouncementPriority.normal)
                            Icon(Icons.priority_high, size: 16, color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(announcement.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(AnnouncementPriority priority) {
    switch (priority) {
      case AnnouncementPriority.urgente: return Colors.red;
      case AnnouncementPriority.importante: return Colors.orange;
      default: return Colors.blue;
    }
  }
}
