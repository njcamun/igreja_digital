import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.title,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  late final bool _isUnavailableSource;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    final normalized = widget.audioUrl.trim().toLowerCase();
    _isUnavailableSource =
        normalized.isEmpty ||
        normalized.contains('placeholder.audio') ||
        normalized.endsWith('/sermon.mp3');
    _init();
  }

  Future<void> _init() async {
    if (_isUnavailableSource) {
      return;
    }
    try {
      await _player.setUrl(widget.audioUrl);
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnavailableSource) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Áudio ainda não disponível para reprodução neste ambiente.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          StreamBuilder<Duration?>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = _player.duration ?? Duration.zero;
              return ProgressBar(
                progress: position,
                total: total,
                onSeek: _player.seek,
                progressBarColor: Theme.of(context).colorScheme.primary,
                baseBarColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.24),
                bufferedBarColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.24),
                thumbColor: Theme.of(context).colorScheme.primary,
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () => _player.seek(
                  Duration(seconds: _player.position.inSeconds - 10),
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final processingState = playerState?.processingState;
                  final playing = playerState?.playing;
                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (playing != true) {
                    return IconButton(
                      icon: const Icon(Icons.play_circle_filled, size: 64),
                      onPressed: _player.play,
                    );
                  } else if (processingState != ProcessingState.completed) {
                    return IconButton(
                      icon: const Icon(Icons.pause_circle_filled, size: 64),
                      onPressed: _player.pause,
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.replay_circle_filled, size: 64),
                      onPressed: () => _player.seek(Duration.zero),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () => _player.seek(
                  Duration(seconds: _player.position.inSeconds + 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
