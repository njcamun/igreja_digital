import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/sermon_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sermon_provider.dart';

class SermonFormScreen extends ConsumerStatefulWidget {
  final SermonEntity? sermon;

  const SermonFormScreen({super.key, this.sermon});

  @override
  ConsumerState<SermonFormScreen> createState() => _SermonFormScreenState();
}

class _SermonFormScreenState extends ConsumerState<SermonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _preacherController;
  late TextEditingController _themeController;
  late TextEditingController _bibleTextController;
  late TextEditingController _articleContentController;
  late DateTime _sermonDate;

  File? _audioFile;
  String? _audioPath;
  SermonContentType? _contentType;
  late TextEditingController _externalUrlController;
  String? _uploadedArticleText;
  String? _uploadedArticleFileName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _preacherController = TextEditingController(
      text: widget.sermon?.preacherName ?? '',
    );
    _themeController = TextEditingController(text: widget.sermon?.theme ?? '');
    _bibleTextController = TextEditingController(
      text: widget.sermon?.bibleText ?? '',
    );
    _articleContentController = TextEditingController(
      text: widget.sermon?.articleContent ?? '',
    );
    _externalUrlController = TextEditingController(
      text: widget.sermon?.externalUrl ?? '',
    );
    _sermonDate = widget.sermon?.sermonDate ?? DateTime.now();
    _contentType = widget.sermon?.contentType;
  }

  @override
  void dispose() {
    _preacherController.dispose();
    _themeController.dispose();
    _bibleTextController.dispose();
    _articleContentController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
        _audioPath = result.files.single.name;
      });
    }
  }

  String _detectPlatformFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    }
    if (lower.contains('spotify.com')) {
      return 'spotify';
    }
    if (lower.contains('soundcloud.com')) {
      return 'soundcloud';
    }
    if (lower.contains('vimeo.com')) {
      return 'vimeo';
    }
    return 'outro';
  }

  Future<Map<String, String>> _extractMetadataFromLink(String url) async {
    final platform = _detectPlatformFromUrl(url);
    Map<String, dynamic>? payload;

    if (platform == 'youtube') {
      final endpoint = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
      );
      payload = await _fetchJson(endpoint);
    } else if (platform == 'vimeo') {
      final endpoint = Uri.parse(
        'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}',
      );
      payload = await _fetchJson(endpoint);
    }

    final title = payload?['title']?.toString().trim();
    final author = payload?['author_name']?.toString().trim();

    return {
      'title': (title == null || title.isEmpty) ? 'Desconhecido' : title,
      'preacher': (author == null || author.isEmpty) ? 'Desconhecido' : author,
      'theme': 'Desconhecido',
      'bibleText': 'Desconhecido',
      'description': 'Conteúdo extraído automaticamente de link externo.',
      'platform': platform,
    };
  }

  Future<void> _pickArticleTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'text'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    setState(() {
      _uploadedArticleText = content.trim();
      _uploadedArticleFileName = result.files.single.name;
    });
  }

  Future<Map<String, dynamic>?> _fetchJson(Uri endpoint) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(endpoint);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await utf8.decoder.bind(response).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de conteúdo.')),
      );
      return;
    }

    if (_contentType == SermonContentType.externalLink) {
      if (_externalUrlController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o link do sermão.')),
        );
        return;
      }
    } else if (_contentType == SermonContentType.article) {
      final manualText = _articleContentController.text.trim();
      final fileText = _uploadedArticleText?.trim() ?? '';
      if (manualText.isEmpty && fileText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No artigo, informe texto manual ou carregue arquivo de texto.',
            ),
          ),
        );
        return;
      }
    } else if (_audioFile == null && widget.sermon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione ou grave um áudio.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);

      if (user == null || user.congregationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilizador sem congregação válida para upload.')),
        );
        return;
      }

      String audioUrl = widget.sermon?.audioUrl ?? '';
      String? externalUrl = widget.sermon?.externalUrl;
      String? externalPlatform = widget.sermon?.externalPlatform;
      String? articleContent = widget.sermon?.articleContent;
      String title = widget.sermon?.title ?? 'Desconhecido';
      String preacherName = _preacherController.text.trim();
      String theme = _themeController.text.trim();
      String bibleText = _bibleTextController.text.trim();
      String description = 'Desconhecido';

      if ((_contentType == SermonContentType.uploadedAudio ||
              _contentType == SermonContentType.recordedAudio ||
              _contentType == SermonContentType.article) &&
          preacherName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pregador é obrigatório.')),
        );
        return;
      }

      if ((_contentType == SermonContentType.uploadedAudio ||
              _contentType == SermonContentType.recordedAudio ||
              _contentType == SermonContentType.article) &&
          (theme.isEmpty || bibleText.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tema e Texto Bíblico são obrigatórios.'),
          ),
        );
        return;
      }

      if (_contentType == SermonContentType.externalLink) {
        final metadata = await _extractMetadataFromLink(
          _externalUrlController.text.trim(),
        );
        audioUrl = '';
        externalUrl = _externalUrlController.text.trim();
        externalPlatform = metadata['platform'];
        articleContent = null;
        title = metadata['title']!;
        preacherName = metadata['preacher']!;
        theme = metadata['theme']!;
        bibleText = metadata['bibleText']!;
        description = metadata['description']!;
      } else if (_contentType == SermonContentType.article) {
        audioUrl = '';
        externalUrl = null;
        externalPlatform = null;
        final manualText = _articleContentController.text.trim();
        articleContent = manualText.isNotEmpty
            ? manualText
            : (_uploadedArticleText?.trim() ?? '');
        title = theme;
        description = 'Artigo de estudo bíblico.';
      } else if (_audioFile != null) {
        final fileName = '${const Uuid().v4()}.m4a';
        final congregationId = user.congregationId!;
        audioUrl = await ref
            .read(sermonRepositoryProvider)
            .uploadAudio(_audioFile!, fileName, congregationId);
        externalUrl = null;
        externalPlatform = null;
        articleContent = null;
        title = theme;
        description = 'Sermão em áudio.';
      }

      final newSermon = SermonEntity(
        id: widget.sermon?.id ?? const Uuid().v4(),
        title: title,
        preacherName: preacherName,
        theme: theme,
        bibleText: bibleText,
        description: description,
        congregationId: user.congregationId!,
        audioUrl: audioUrl,
        contentType: _contentType!,
        externalUrl: externalUrl,
        externalPlatform: externalPlatform,
        articleContent: articleContent,
        durationInSeconds: 0,
        processingStatus:
            widget.sermon?.processingStatus ?? ProcessingStatus.completed,
        transcription: widget.sermon?.transcription,
        summary: widget.sermon?.summary,
        keyPoints: widget.sermon?.keyPoints ?? const [],
        keyVerse: widget.sermon?.keyVerse,
        createdBy: user.uid,
        createdAt: widget.sermon?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        sermonDate: _sermonDate,
        isPublished: true,
      );

      if (widget.sermon == null) {
        await ref.read(sermonRepositoryProvider).addSermon(newSermon);
        if (mounted) Navigator.pop(context);
      } else {
        await ref.read(sermonRepositoryProvider).updateSermon(newSermon);
        if (mounted) Navigator.pop(context, newSermon);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sermon == null ? 'Novo Sermão' : 'Editar Sermão'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enviando sermão...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Tipo de Conteúdo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<SermonContentType>(
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment<SermonContentType>(
                        value: SermonContentType.uploadedAudio,
                        label: Text('Arquivo'),
                        icon: Icon(Icons.upload_file),
                      ),
                      ButtonSegment<SermonContentType>(
                        value: SermonContentType.externalLink,
                        label: Text('Link'),
                        icon: Icon(Icons.link),
                      ),
                      ButtonSegment<SermonContentType>(
                        value: SermonContentType.article,
                        label: Text('Artigo'),
                        icon: Icon(Icons.article_outlined),
                      ),
                    ],
                    selected: _contentType == null ? {} : {_contentType!},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _contentType = selection.first;
                        if (_contentType == SermonContentType.externalLink ||
                            _contentType == SermonContentType.article) {
                          _audioFile = null;
                          _audioPath = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  if (_contentType == null) ...[
                    const Text(
                      'Selecione o tipo de conteúdo para continuar.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ] else if (_contentType ==
                      SermonContentType.externalLink) ...[
                    TextFormField(
                      controller: _externalUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Link do sermão',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (_contentType != SermonContentType.externalLink) {
                          return null;
                        }
                        final url = (value ?? '').trim();
                        if (url.isEmpty) return 'Obrigatório';
                        final uri = Uri.tryParse(url);
                        if (uri == null ||
                            (!uri.isScheme('http') && !uri.isScheme('https'))) {
                          return 'Informe um link válido (http/https)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Os dados visíveis da listagem serão extraídos automaticamente do link. Se não for possível, serão definidos como Desconhecido.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _themeController,
                      decoration: const InputDecoration(labelText: 'Tema'),
                      validator: (v) {
                        if (_contentType == SermonContentType.externalLink) {
                          return null;
                        }
                        return (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _preacherController,
                      decoration: const InputDecoration(labelText: 'Pregador'),
                      validator: (v) {
                        if (_contentType == SermonContentType.externalLink) {
                          return null;
                        }
                        return (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bibleTextController,
                      decoration: const InputDecoration(
                        labelText: 'Texto Bíblico',
                      ),
                      validator: (v) {
                        if (_contentType == SermonContentType.externalLink) {
                          return null;
                        }
                        return (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_contentType == SermonContentType.article) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickArticleTextFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload arquivo de texto'),
                            ),
                          ),
                        ],
                      ),
                      if (_uploadedArticleFileName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Arquivo: $_uploadedArticleFileName',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _articleContentController,
                        decoration: const InputDecoration(
                          labelText: 'Conteúdo manual do artigo',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        minLines: 8,
                        maxLines: 14,
                        validator: (value) {
                          if (_contentType != SermonContentType.article) {
                            return null;
                          }
                          final manual = (value ?? '').trim();
                          final file = _uploadedArticleText?.trim() ?? '';
                          if (manual.isEmpty && file.isEmpty) {
                            return 'Preencha o texto manual ou carregue arquivo.';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      const Text(
                        'Áudio do Sermão',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_audioPath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _audioPath!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload do arquivo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Data do Sermão'),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(_sermonDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _sermonDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _sermonDate = picked);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('PUBLICAR SERMÃO'),
                  ),
                ],
              ),
            ),
    );
  }
}
