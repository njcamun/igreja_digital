import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/announcement_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  final AnnouncementEntity? announcement;

  const AnnouncementFormScreen({super.key, this.announcement});

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late AnnouncementPriority _priority;
  late bool _isGlobal;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement?.title ?? '');
    _contentController = TextEditingController(text: widget.announcement?.content ?? '');
    _priority = widget.announcement?.priority ?? AnnouncementPriority.normal;
    _isGlobal = widget.announcement?.isGlobal ?? false;
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final newAnnouncement = AnnouncementEntity(
        id: widget.announcement?.id ?? const Uuid().v4(),
        title: _titleController.text,
        content: _contentController.text,
        priority: _priority,
        congregationId: user.congregationId ?? '',
        isGlobal: _isGlobal,
        publishedBy: user.uid,
        createdAt: widget.announcement?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      try {
        if (widget.announcement == null) {
          await ref.read(announcementRepositoryProvider).addAnnouncement(newAnnouncement);
          if (mounted) Navigator.pop(context);
        } else {
          await ref.read(announcementRepositoryProvider).updateAnnouncement(newAnnouncement);
          if (mounted) Navigator.pop(context, newAnnouncement);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.announcement == null ? 'Novo Aviso' : 'Editar Aviso')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Conteúdo'),
              maxLines: 5,
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AnnouncementPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Prioridade'),
              items: AnnouncementPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            SwitchListTile(
              title: const Text('Aviso Global'),
              value: _isGlobal,
              onChanged: (v) => setState(() => _isGlobal = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Publicar Aviso')),
          ],
        ),
      ),
    );
  }
}
