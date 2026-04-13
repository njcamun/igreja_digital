import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'audio_player_widget.dart';

class ExternalMediaPlayerWidget extends StatefulWidget {
  final String url;
  final VoidCallback onOpenOriginal;

  const ExternalMediaPlayerWidget({
    super.key,
    required this.url,
    required this.onOpenOriginal,
  });

  @override
  State<ExternalMediaPlayerWidget> createState() =>
      _ExternalMediaPlayerWidgetState();
}

class _ExternalMediaPlayerWidgetState extends State<ExternalMediaPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isLoadingVideo = false;

  @override
  void initState() {
    super.initState();
    _setupControllers();
  }

  Future<void> _setupControllers() async {
    final type = _detectType(widget.url);

    if (type == _MediaType.video) {
      setState(() => _isLoadingVideo = true);
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
        );
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        setState(() {
          _videoController = controller;
          _isLoadingVideo = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingVideo = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  _MediaType _detectType(String url) {
    final lower = url.toLowerCase();

    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return _MediaType.youtube;
    }

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg')) {
      return _MediaType.audio;
    }

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8')) {
      return _MediaType.video;
    }

    return _MediaType.unsupported;
  }

  Future<void> _openYoutubeInApp() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      widget.onOpenOriginal();
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      widget.onOpenOriginal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _detectType(widget.url);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == _MediaType.audio) ...[
              AudioPlayerWidget(audioUrl: widget.url, title: 'Áudio externo'),
            ] else if (type == _MediaType.video) ...[
              if (_isLoadingVideo)
                const Center(child: CircularProgressIndicator())
              else if (_videoController != null)
                Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            size: 32,
                          ),
                          onPressed: () {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                )
              else
                const Text(
                  'Não foi possível reproduzir este vídeo diretamente.',
                ),
            ] else if (type == _MediaType.youtube) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.ondemand_video),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'YouTube detectado',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Neste dispositivo, o player incorporado pode falhar. Use reprodução interna abaixo.',
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _openYoutubeInApp,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reproduzir na app'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Este link não oferece reprodução incorporada na app. Use "Abrir original".',
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.onOpenOriginal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir original'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MediaType { audio, video, youtube, unsupported }
