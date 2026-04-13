import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/event_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  Widget _buildFirestoreError(
    BuildContext context,
    WidgetRef ref,
    Object err,
    UserEntity? user,
  ) {
    final message = err.toString().toLowerCase();

    String title = 'Não foi possível carregar a agenda.';
    String detail = 'Tente novamente em instantes.';

    if (message.contains('unable to resolve host') ||
        message.contains('status{code=unavailable') ||
        message.contains('end of stream or ioexception')) {
      title = 'Sem ligação à internet.';
      detail =
          'Verifique a rede do dispositivo e tente novamente para carregar os eventos.';
    } else if (message.contains('failed_precondition') ||
        message.contains('requires an index')) {
      title = 'Índice do Firestore em falta.';
      detail =
          'O índice necessário ainda não está disponível. Aguarde o deploy/construção e volte a tentar.';
    }

    return FutureBuilder<List<EventEntity>>(
      future: ref.read(eventRepositoryProvider).getCachedEvents(
        congregationId: user?.congregationId,
            isGlobal: user == null ? true : null,
          ),
      builder: (context, snapshot) {
        final cached = snapshot.data ?? const <EventEntity>[];

        if (cached.isNotEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: MaterialBanner(
                  content: const Text(
                    'Ligação indisponível. A mostrar eventos guardados localmente.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => ref.invalidate(eventsStreamProvider),
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
                      _EventCard(event: cached[index], isPast: !cached[index].isFuture),
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
                  onPressed: () => ref.invalidate(eventsStreamProvider),
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

  Future<void> _confirmDeleteAllEvents(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> events,
  ) async {
    if (events.isEmpty) return;

    final inputController = TextEditingController();
    bool canDelete = false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eliminar Eventos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja eliminar ${events.length} eventos visíveis nesta lista?',
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

    for (final event in events) {
      await ref.read(eventRepositoryProvider).deleteEvent(event.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${events.length} eventos eliminados.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final user = ref.watch(currentUserProvider);
    
    final canManage = user?.role == UserRole.admin || user?.role == UserRole.lider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventFormScreen()),
              ),
            ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Nenhum evento agendado.'));
          }

          final futureEvents = events.where((e) => e.isFuture).toList();
          final pastEvents = events.where((e) => !e.isFuture).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmDeleteAllEvents(context, ref, events),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Eliminar visíveis'),
                  ),
                ),
              if (canManage) const SizedBox(height: 8),
              if (futureEvents.isNotEmpty) ...[
                Text(
                  'Próximos Eventos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...futureEvents.map(
                  (e) => _buildEventItem(context, ref, e, canManage: canManage),
                ),
              ],
              if (pastEvents.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Eventos Anteriores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ...pastEvents.map(
                  (e) => _buildEventItem(
                    context,
                    ref,
                    e,
                    isPast: true,
                    canManage: canManage,
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildFirestoreError(context, ref, err, user),
      ),
    );
  }

  Widget _buildEventItem(
    BuildContext context,
    WidgetRef ref,
    dynamic event, {
    bool isPast = false,
    required bool canManage,
  }) {
    final card = _EventCard(event: event, isPast: isPast);

    if (!canManage) {
      return card;
    }

    return Dismissible(
      key: ValueKey('event-${event.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar Evento'),
            content: Text('Deseja eliminar "${event.title}"?'),
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
          await ref.read(eventRepositoryProvider).deleteEvent(event.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Evento eliminado.')),
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
  }
}

class _EventCard extends StatelessWidget {
  final dynamic event;
  final bool isPast;

  const _EventCard({required this.event, this.isPast = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isPast ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: isPast
          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isPast ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(event.startDateTime)}\n${event.location}',
        ),
        isThreeLine: true,
        trailing: Icon(
          _getIconForType(event.type),
          color: isPast ? Colors.grey : Theme.of(context).colorScheme.primary,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
      ),
    );
  }

  IconData _getIconForType(dynamic type) {
    switch (type) {
      case 'culto': return Icons.church;
      case 'vigilia': return Icons.nightlight_round;
      case 'ensaio': return Icons.music_note;
      case 'reuniao': return Icons.groups;
      case 'evangelismo': return Icons.volunteer_activism;
      case 'conferencia': return Icons.event;
      default: return Icons.calendar_today;
    }
  }
}
