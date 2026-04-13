import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/prayer_request_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/prayer_provider.dart';

class PrayerFormScreen extends ConsumerStatefulWidget {
  const PrayerFormScreen({super.key});

  @override
  ConsumerState<PrayerFormScreen> createState() => _PrayerFormScreenState();
}

class _PrayerFormScreenState extends ConsumerState<PrayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isAnonymous = false;
  bool _isPrivate = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = ref.read(currentUserProvider);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'É necessário iniciar sessão para criar pedidos de oração.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final prayer = PrayerRequestEntity(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        userId: user.uid,
        userName: user.fullName,
        congregationId: user.congregationId,
        isAnonymous: _isAnonymous,
        isPrivate: _isPrivate,
        isPublic: !_isPrivate,
        status: PrayerStatus.open,
        prayerCount: 0,
        prayedByUserIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      try {
        await ref.read(prayerRepositoryProvider).addPrayerRequest(prayer);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao enviar pedido: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Pedido de Oração')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título do Pedido (Ex: Saúde da Família)',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Obrigatório';
                      if (value.length < 5) {
                        return 'Use pelo menos 5 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Descreva o seu motivo de oração',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Obrigatório';
                      if (value.length < 10) {
                        return 'Descreva com mais detalhe (mínimo 10 caracteres)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('Pedido Anónimo'),
                    subtitle: const Text(
                      'O seu nome não será mostrado a outros membros.',
                    ),
                    value: _isAnonymous,
                    onChanged: (v) => setState(() => _isAnonymous = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visibilidade do pedido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Público'),
                        icon: Icon(Icons.public),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Privado'),
                        icon: Icon(Icons.lock_outline),
                      ),
                    ],
                    selected: {_isPrivate},
                    onSelectionChanged: (selection) {
                      setState(() => _isPrivate = selection.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPrivate
                        ? 'Privado: visível ao autor, líderes da congregação e admins.'
                        : 'Público: visível para utilizadores autorizados.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('ENVIAR PEDIDO'),
                  ),
                ],
              ),
            ),
    );
  }
}
