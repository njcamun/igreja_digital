import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/sermon_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sermon_provider.dart';
import 'sermon_detail_screen.dart';
import 'sermon_form_screen.dart';

class SermonsListScreen extends ConsumerStatefulWidget {
  const SermonsListScreen({super.key});

  @override
  ConsumerState<SermonsListScreen> createState() => _SermonsListScreenState();
}

class _SermonsListScreenState extends ConsumerState<SermonsListScreen> {
  String _searchQuery = '';
  SermonContentType? _contentTypeFilter;

  Future<void> _confirmDeleteAllSermons(
    BuildContext context,
    List<SermonEntity> sermons,
  ) async {
    if (sermons.isEmpty) return;

    final inputController = TextEditingController();
    bool canDelete = false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eliminar Sermões'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja eliminar ${sermons.length} sermões visíveis nesta lista?',
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

    for (final sermon in sermons) {
      await ref.read(sermonRepositoryProvider).deleteSermon(
            sermon.id,
            sermon.audioUrl,
          );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sermons.length} sermões eliminados.')),
      );
    }
  }

  Future<bool> _confirmDeleteSermon(BuildContext context, SermonEntity sermon) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Sermão'),
        content: Text('Deseja eliminar "${sermon.title}"?'),
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
      await ref.read(sermonRepositoryProvider).deleteSermon(sermon.id, sermon.audioUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sermão eliminado.')),
        );
      }
      return true;
    }

    return false;
  }

  String _contentTypeLabel(SermonContentType? type) {
    if (type == null) return 'Todos';
    switch (type) {
      case SermonContentType.uploadedAudio:
        return 'Áudio enviado';
      case SermonContentType.recordedAudio:
        return 'Áudio gravado';
      case SermonContentType.externalLink:
        return 'Link externo';
      case SermonContentType.article:
        return 'Artigo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sermonsAsync = ref.watch(sermonsStreamProvider);
    final user = ref.watch(currentUserProvider);
    final canManage =
        user?.role == UserRole.admin || user?.role == UserRole.lider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sermões'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SermonFormScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              hintText: 'Pesquisar sermão, pregador ou tema...',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _contentTypeFilter == null,
                  onSelected: (_) {
                    setState(() => _contentTypeFilter = null);
                  },
                ),
                ...SermonContentType.values.map(
                  (type) => ChoiceChip(
                    label: Text(_contentTypeLabel(type)),
                    selected: _contentTypeFilter == type,
                    onSelected: (_) {
                      setState(() => _contentTypeFilter = type);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sermonsAsync.when(
              data: (sermons) {
                final filtered = sermons.where((s) {
                  final query = _searchQuery.toLowerCase();
                  final matchesQuery =
                      s.title.toLowerCase().contains(query) ||
                      s.preacherName.toLowerCase().contains(query) ||
                      s.theme.toLowerCase().contains(query);
                  final matchesType =
                      _contentTypeFilter == null ||
                      s.contentType == _contentTypeFilter;

                  return matchesQuery && matchesType;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Nenhum sermão encontrado.'));
                }

                return Column(
                  children: [
                    if (canManage)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmDeleteAllSermons(context, filtered),
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('Eliminar visíveis'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final sermon = filtered[index];
                          final card = _SermonCard(sermon: sermon);

                          if (!canManage) {
                            return card;
                          }

                          return Dismissible(
                            key: ValueKey('sermon-${sermon.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) =>
                                _confirmDeleteSermon(context, sermon),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                            child: card,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erro: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SermonCard extends StatelessWidget {
  final SermonEntity sermon;

  const _SermonCard({required this.sermon});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _contentTypeMeta(sermon.contentType);
    final (isInlinePlayable, availabilityLabel, availabilityIcon) =
        _playbackAvailability();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          sermon.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pregador: ${sermon.preacherName}'),
            Text(
              DateFormat('dd/MM/yyyy').format(sermon.sermonDate),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isInlinePlayable
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    availabilityIcon,
                    size: 14,
                    color: isInlinePlayable ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    availabilityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isInlinePlayable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Icon(
          sermon.contentType == SermonContentType.externalLink
              ? Icons.open_in_new
              : sermon.contentType == SermonContentType.article
              ? Icons.article_outlined
              : Icons.play_circle_outline,
          size: 32,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SermonDetailScreen(sermon: sermon)),
        ),
      ),
    );
  }

  (IconData, String) _contentTypeMeta(SermonContentType type) {
    switch (type) {
      case SermonContentType.uploadedAudio:
        return (Icons.audio_file, 'Áudio enviado');
      case SermonContentType.recordedAudio:
        return (Icons.mic, 'Áudio gravado');
      case SermonContentType.externalLink:
        return (Icons.link, 'Link externo');
      case SermonContentType.article:
        return (Icons.article_outlined, 'Artigo bíblico');
    }
  }

  (bool, String, IconData) _playbackAvailability() {
    if (sermon.contentType != SermonContentType.externalLink) {
      return (true, 'Reproduz na app', Icons.play_circle_outline);
    }

    final url = sermon.externalUrl?.toLowerCase() ?? '';
    final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');
    final isDirectAudio =
        url.endsWith('.mp3') ||
        url.endsWith('.m4a') ||
        url.endsWith('.aac') ||
        url.endsWith('.wav') ||
        url.endsWith('.ogg');
    final isDirectVideo =
        url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mov') ||
        url.endsWith('.m3u8');

    if (isYoutube || isDirectAudio || isDirectVideo) {
      return (true, 'Reproduz na app', Icons.play_circle_outline);
    }

    return (false, 'Abrir original', Icons.open_in_new);
  }
}
