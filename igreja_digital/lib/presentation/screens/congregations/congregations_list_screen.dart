import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/congregation_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import 'congregation_detail_screen.dart';
import 'congregation_form_screen.dart';
import 'congregations_map_screen.dart';

class CongregationsListScreen extends ConsumerStatefulWidget {
  const CongregationsListScreen({super.key});

  @override
  ConsumerState<CongregationsListScreen> createState() => _CongregationsListScreenState();
}

class _CongregationsListScreenState extends ConsumerState<CongregationsListScreen> {
  String _searchQuery = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role == UserRole.admin || user?.role == UserRole.lider;
    final canDelete = user?.role == UserRole.admin || user?.role == UserRole.lider;
    final congregationsAsync = canManage && _showInactive
        ? ref.watch(allCongregationsStreamProvider)
        : ref.watch(congregationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Congregações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CongregationsMapScreen()),
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CongregationFormScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SwitchListTile.adaptive(
                value: _showInactive,
                onChanged: (value) => setState(() => _showInactive = value),
                title: const Text('Modo gestão: mostrar inativas'),
                subtitle: const Text(
                  'Ative para ver e identificar congregações removidas.',
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              hintText: 'Pesquisar congregação...',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: congregationsAsync.when(
              data: (congregations) {
                final filtered = congregations.where((c) {
                  final query = _searchQuery.toLowerCase();
                  return c.name.toLowerCase().contains(query) ||
                      c.address.toLowerCase().contains(query) ||
                      c.city.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Nenhuma congregação encontrada.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final cong = filtered[index];
                    return _CongregationCard(
                      congregation: cong,
                      canDelete: canDelete,
                    );
                  },
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

class _CongregationCard extends ConsumerWidget {
  final CongregationEntity congregation;
  final bool canDelete;

  const _CongregationCard({
    required this.congregation,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: congregation.imageUrl != null && congregation.imageUrl!.isNotEmpty
              ? NetworkImage(congregation.imageUrl!)
              : null,
          child: congregation.imageUrl == null || congregation.imageUrl!.isEmpty
              ? Icon(
                  Icons.church,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(congregation.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${congregation.address}, ${congregation.city}'),
            const SizedBox(height: 4),
            Text('Responsável: ${congregation.leaderName}', style: const TextStyle(fontSize: 12)),
            if (!congregation.isActive && canDelete) ...[
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('INATIVA'),
                  avatar: Icon(Icons.visibility_off_outlined, size: 16),
                ),
              ),
            ],
          ],
        ),
        trailing: canDelete
            ? SizedBox(
                width: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (congregation.isActive)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remover congregação',
                        onPressed: () => _confirmDelete(context, ref),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.restore_outlined),
                        tooltip: 'Reativar congregação',
                        onPressed: () => _confirmReactivate(context, ref),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CongregationDetailScreen(congregation: congregation)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover congregação'),
        content: Text(
          'Deseja remover a congregação "${congregation.name}"? Esta ação irá desativá-la da lista pública.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(congregationRepositoryProvider)
          .deleteCongregation(congregation.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congregação "${congregation.name}" removida.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover congregação: $error')),
      );
    }
  }

  Future<void> _confirmReactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reativar congregação'),
        content: Text(
          'Deseja reativar a congregação "${congregation.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reativar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(congregationRepositoryProvider)
          .reactivateCongregation(congregation.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congregação "${congregation.name}" reativada.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reativar congregação: $error')),
      );
    }
  }
}
