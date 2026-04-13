import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_admin_provider.dart';

class VisitorProfileScreen extends ConsumerStatefulWidget {
  const VisitorProfileScreen({super.key});

  @override
  ConsumerState<VisitorProfileScreen> createState() =>
      _VisitorProfileScreenState();
}

class _VisitorProfileScreenState extends ConsumerState<VisitorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _maritalStatusController = TextEditingController();
  final _contactController = TextEditingController();
  final _shortBioController = TextEditingController();
  DateTime? _birthDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _fullNameController.text = user?.fullName ?? '';
    _maritalStatusController.text = user?.maritalStatus ?? '';
    _contactController.text = user?.contact ?? '';
    _shortBioController.text = user?.shortBio ?? '';
    _birthDate = user?.birthDate;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _maritalStatusController.dispose();
    _contactController.dispose();
    _shortBioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 20, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (pickedDate != null) {
      setState(() => _birthDate = pickedDate);
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(userAdminServiceProvider).updateOwnVisitorProfile(
        userId: user.uid,
        fullName: _fullNameController.text.trim(),
        birthDate: _birthDate,
        maritalStatus: _maritalStatusController.text.trim().isEmpty
            ? null
            : _maritalStatusController.text.trim(),
        contact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        shortBio: _shortBioController.text.trim().isEmpty
            ? null
            : _shortBioController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar perfil: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Informe o nome.';
                }
                return null;
              },
            ),
            if (user.role == UserRole.membro || user.role == UserRole.lider) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de membresia',
                ),
                child: Text(
                  user.membershipDate == null
                      ? 'Não definida'
                      : DateFormat('dd/MM/yyyy').format(user.membershipDate!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento',
                ),
                child: Text(
                  _birthDate == null
                      ? 'Selecionar data'
                      : DateFormat('dd/MM/yyyy').format(_birthDate!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maritalStatusController,
              decoration: const InputDecoration(labelText: 'Estado civil'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Contacto'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortBioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Breve descrição',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Guardar perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
