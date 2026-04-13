import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/event_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final EventEntity? event;

  const EventFormScreen({super.key, this.event});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late DateTime _startDate;
  late DateTime _endDate;
  late EventType _type;
  late bool _isGlobal;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _startDate = widget.event?.startDateTime ?? DateTime.now().add(const Duration(hours: 1));
    _endDate = widget.event?.endDateTime ?? _startDate.add(const Duration(hours: 2));
    _type = widget.event?.type ?? EventType.culto;
    _isGlobal = widget.event?.isGlobal ?? false;
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final newEvent = EventEntity(
        id: widget.event?.id ?? const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        congregationId: user.congregationId ?? '',
        isGlobal: _isGlobal,
        startDateTime: _startDate,
        endDateTime: _endDate,
        location: _locationController.text,
        createdBy: user.uid,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        if (widget.event == null) {
          await ref.read(eventRepositoryProvider).addEvent(newEvent);
          if (mounted) Navigator.pop(context);
        } else {
          await ref.read(eventRepositoryProvider).updateEvent(newEvent);
          if (mounted) Navigator.pop(context, newEvent);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao guardar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Novo Evento' : 'Editar Evento')),
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
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Localização'),
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: EventType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Início'),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_startDate)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (!context.mounted) return;
                if (date != null) {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startDate));
                  if (!context.mounted) return;
                  if (time != null) {
                    setState(() => _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                }
              },
            ),
            SwitchListTile(
              title: const Text('Evento Global'),
              subtitle: const Text('Visível para todas as congregações'),
              value: _isGlobal,
              onChanged: (v) => setState(() => _isGlobal = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Guardar Evento')),
          ],
        ),
      ),
    );
  }
}
