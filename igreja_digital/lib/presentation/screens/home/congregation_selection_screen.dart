import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/congregation_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/user_admin_provider.dart';

class CongregationSelectionScreen extends ConsumerStatefulWidget {
  final bool isRequired;

  const CongregationSelectionScreen({super.key, this.isRequired = false});

  @override
  ConsumerState<CongregationSelectionScreen> createState() =>
      _CongregationSelectionScreenState();
}

class _CongregationSelectionScreenState
    extends ConsumerState<CongregationSelectionScreen> {
  String? _selectedCongregationId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _selectedCongregationId = user?.congregationId;
    if (_selectedCongregationId == null || _selectedCongregationId!.isEmpty) {
      _selectedCongregationId = visitorCongregationId;
    }
  }

  Future<void> _saveSelection(UserEntity user) async {
    final selectedCongregationId = _selectedCongregationId;
    final requiresCongregation =
        user.role == UserRole.membro || user.role == UserRole.lider;

    if (requiresCongregation &&
        (selectedCongregationId == null ||
            selectedCongregationId.isEmpty ||
            selectedCongregationId == visitorCongregationId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membro e líder devem selecionar uma congregação válida.'),
        ),
      );
      return;
    }

    if (selectedCongregationId == null || selectedCongregationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha uma congregação ou selecione Sem congregação.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(userAdminServiceProvider)
          .updateUserCongregationChoice(
            user: user,
            congregationId: selectedCongregationId,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Congregação atualizada com sucesso.')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar congregação: $error')),
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
    final congregationsAsync = ref.watch(allCongregationsStreamProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isRequired,
          title: Text(
            widget.isRequired
                ? 'Escolha a sua congregação'
                : 'Alterar congregação',
          ),
        ),
        body: congregationsAsync.when(
          data: (congregations) {
            final requiresCongregation =
                user.role == UserRole.membro || user.role == UserRole.lider;
            final canSelectNoCongregation = user.role == UserRole.visitante;
            final availableCongregations = congregations.where((congregation) {
              return congregation.isActive ||
                  congregation.id == user.congregationId;
            }).toList()..sort((left, right) => left.name.compareTo(right.name));

            final currentCongregationName = () {
              final userCongregationId = user.congregationId;
              if (userCongregationId == null ||
                  userCongregationId.isEmpty ||
                  userCongregationId == visitorCongregationId) {
                return 'Sem congregação';
              }

              final matches = availableCongregations
                  .where((c) => c.id == userCongregationId)
                  .toList();
              return matches.isEmpty ? 'Congregação indisponível' : matches.first.name;
            }();

            if (requiresCongregation &&
                (_selectedCongregationId == null ||
                    _selectedCongregationId!.isEmpty ||
                    _selectedCongregationId == visitorCongregationId) &&
                availableCongregations.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedCongregationId = availableCongregations.first.id;
                });
              });
            }

            final canSave = !requiresCongregation ||
                (_selectedCongregationId != null &&
                    _selectedCongregationId!.isNotEmpty &&
                    _selectedCongregationId != visitorCongregationId);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  requiresCongregation
                      ? 'Como membro ou líder, deve escolher uma congregação para continuar.'
                      : widget.isRequired
                      ? 'Para continuar, selecione a sua congregação. Se ainda não pertence a nenhuma, escolha Sem congregação.'
                      : 'Pode alterar a sua congregação a qualquer momento. Se preferir acompanhar sem vínculo, escolha Sem congregação.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.church_outlined),
                    title: const Text('Congregação atual'),
                    subtitle: Text(currentCongregationName),
                  ),
                ),
                const SizedBox(height: 12),
                if (canSelectNoCongregation) ...[
                  RadioGroup<String>(
                    groupValue: _selectedCongregationId,
                    onChanged: (value) {
                      setState(() => _selectedCongregationId = value);
                    },
                    child: Card(
                      child: RadioListTile<String>(
                        value: visitorCongregationId,
                        title: const Text('Sem congregação'),
                        subtitle: const Text(
                          'Acede sem congregação específica.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _isSaving || !canSave
                    ? null
                    : () => _saveSelection(user),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(widget.isRequired ? 'Continuar' : 'Guardar'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Congregações disponíveis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _selectedCongregationId,
                  onChanged: (value) {
                    setState(() => _selectedCongregationId = value);
                  },
                  child: Column(
                    children: availableCongregations
                        .map(
                          (congregation) => _CongregationChoiceTile(
                            congregation: congregation,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user.role == UserRole.membro || user.role == UserRole.lider)
                Text(
                  'Não foi possível carregar as congregações. Como membro ou líder, não pode ficar sem congregação.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
              Text(
                'Não foi possível carregar as congregações agora. Ainda assim, pode continuar sem congregação.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (user.role == UserRole.visitante) ...[
                RadioGroup<String>(
                  groupValue: _selectedCongregationId,
                  onChanged: (value) {
                    setState(() => _selectedCongregationId = value);
                  },
                  child: Card(
                    child: RadioListTile<String>(
                      value: visitorCongregationId,
                      title: const Text('Sem congregação'),
                      subtitle: const Text(
                        'Acede sem congregação específica.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off_rounded),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Congregações indisponíveis no momento'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(allCongregationsStreamProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
              if (user.role == UserRole.visitante) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveSelection(user),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(widget.isRequired ? 'Continuar' : 'Guardar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CongregationChoiceTile extends StatelessWidget {
  final CongregationEntity congregation;

  const _CongregationChoiceTile({
    required this.congregation,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      '${congregation.city}, ${congregation.province}',
      if (!congregation.isActive) 'Inativa',
    ].join(' • ');

    return Card(
      child: RadioListTile<String>(
        value: congregation.id,
        enabled: congregation.isActive,
        title: Text(congregation.name),
        subtitle: Text(subtitle),
      ),
    );
  }
}
