import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/sermon_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sermon_provider.dart';
import '../../widgets/audio_player_widget.dart';
import '../../widgets/external_media_player_widget.dart';
import 'sermon_form_screen.dart';

class SermonDetailScreen extends ConsumerStatefulWidget {
  final SermonEntity sermon;

  const SermonDetailScreen({super.key, required this.sermon});

  @override
  ConsumerState<SermonDetailScreen> createState() =>
      _SermonDetailScreenState();
}

class _SermonDetailScreenState extends ConsumerState<SermonDetailScreen> {
  late SermonEntity _sermon;

  @override
  void initState() {
    super.initState();
    _sermon = widget.sermon;
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link inválido.')));
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _shareSermon(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln('Sermão: ${_sermon.title}')
      ..writeln('Pregador: ${_sermon.preacherName}')
      ..writeln('Data: ${DateFormat('dd/MM/yyyy').format(_sermon.sermonDate)}');

    if (_sermon.contentType == SermonContentType.externalLink &&
        _sermon.externalUrl != null &&
        _sermon.externalUrl!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Aceder: ${_sermon.externalUrl}');
    } else if (_sermon.contentType == SermonContentType.article &&
        _sermon.articleContent != null &&
        _sermon.articleContent!.isNotEmpty) {
      final preview = _sermon.articleContent!.length > 220
          ? '${_sermon.articleContent!.substring(0, 220)}...'
          : _sermon.articleContent!;
      buffer
        ..writeln()
        ..writeln('Resumo do artigo:')
        ..writeln(preview);
    }

    await Share.share(buffer.toString(), subject: _sermon.title);
  }

  (bool, String, IconData) _playbackAvailability() {
    if (_sermon.contentType != SermonContentType.externalLink) {
      return (true, 'Reproduz na app', Icons.play_circle_outline);
    }

    final url = _sermon.externalUrl?.toLowerCase() ?? '';
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

    @override
    Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final (isInlinePlayable, availabilityLabel, availabilityIcon) =
      _playbackAvailability();
    final canManage =
      user?.role == UserRole.admin ||
      (user?.role == UserRole.lider &&
        user?.congregationId == _sermon.congregationId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Sermão'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partilhar sermão',
            onPressed: () => _shareSermon(context),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar sermão',
              onPressed: () => _confirmDelete(context),
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<SermonEntity?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SermonFormScreen(sermon: _sermon),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _sermon = updated);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sermon.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pregador: ${_sermon.preacherName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Data: ${DateFormat('dd/MM/yyyy').format(_sermon.sermonDate)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    size: 15,
                    color: isInlinePlayable ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    availabilityLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isInlinePlayable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_sermon.contentType == SermonContentType.externalLink) ...[
              if (_sermon.externalUrl != null && _sermon.externalUrl!.isNotEmpty)
                ExternalMediaPlayerWidget(
                  url: _sermon.externalUrl!,
                  onOpenOriginal: () =>
                      _openExternalLink(context, _sermon.externalUrl!),
                )
              else
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded),
                    title: Text('Link indisponível'),
                    subtitle: Text('Este sermão foi publicado sem URL válida.'),
                  ),
                ),
            ] else if (_sermon.contentType == SermonContentType.article) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Estudo Bíblico (Artigo)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _sermon.articleContent ??
                            'Conteúdo de artigo não informado.',
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_sermon.audioUrl.isNotEmpty) ...[
              AudioPlayerWidget(audioUrl: _sermon.audioUrl, title: _sermon.title),
            ] else ...[
              const Card(
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Conteúdo indisponível'),
                  subtitle: Text(
                    'Nenhum áudio ou link foi configurado para este sermão.',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            _buildSectionTitle(context, 'Tema e Texto Bíblico'),
            Text('${_sermon.theme} - ${_sermon.bibleText}'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Sermão'),
        content: const Text(
          'Deseja eliminar este sermão? Esta ação também remove o áudio associado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
                await ref
                  .read(sermonRepositoryProvider)
                  .deleteSermon(_sermon.id, _sermon.audioUrl);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sermão eliminado com sucesso.')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
