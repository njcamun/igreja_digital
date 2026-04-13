import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/announcement_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import 'announcement_form_screen.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final AnnouncementEntity announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  late AnnouncementEntity _announcement;

  @override
  void initState() {
    super.initState();
    _announcement = widget.announcement;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role == UserRole.admin ||
        (user?.role == UserRole.lider &&
            user?.congregationId == _announcement.congregationId);

    final priorityColor = _getPriorityColor(_announcement.priority);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Aviso'),
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<AnnouncementEntity?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AnnouncementFormScreen(announcement: _announcement),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _announcement = updated);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    _announcement.priority.name.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_announcement.isGlobal) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'GLOBAL',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _announcement.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Publicado em ${DateFormat('dd/MM/yyyy HH:mm').format(_announcement.createdAt)}',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const Divider(height: 40),
            Text(
              _announcement.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Aviso'),
        content: const Text('Deseja eliminar este aviso definitivamente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(announcementRepositoryProvider)
                  .deleteAnnouncement(_announcement.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
