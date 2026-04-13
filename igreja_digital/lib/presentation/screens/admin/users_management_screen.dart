import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/user_admin_provider.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  String _searchQuery = '';
  UserRole? _roleFilter;
  bool? _statusFilter;
  String? _congregationFilter;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final usersAsync = currentUser == null
        ? const AsyncValue<List<UserEntity>>.loading()
        : ref.watch(managedUsersStreamProvider(currentUser));
    final congregationsAsync = ref.watch(allCongregationsStreamProvider);

    final isAdmin = currentUser?.role == UserRole.admin;
    final isLeader = currentUser?.role == UserRole.lider;

    if (!isAdmin && !isLeader) {
      return const Scaffold(
        body: Center(child: Text('Acesso permitido apenas para administradores e líderes.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestao de Utilizadores'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Pesquisar por nome ou email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos os perfis'),
                  selected: _roleFilter == null,
                  onSelected: (_) => setState(() => _roleFilter = null),
                ),
                ...UserRole.values.map(
                  (role) {
                    final isLeader = currentUser?.role == UserRole.lider;
                    if (isLeader && role != UserRole.visitante && role != UserRole.membro) {
                      return const SizedBox.shrink();
                    }
                    return FilterChip(
                    label: Text(role.name.toUpperCase()),
                    selected: _roleFilter == role,
                    onSelected: (_) => setState(() => _roleFilter = role),
                    );
                  },
                ),
                FilterChip(
                  label: const Text('Todos estados'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                FilterChip(
                  label: const Text('Ativos'),
                  selected: _statusFilter == true,
                  onSelected: (_) => setState(() => _statusFilter = true),
                ),
                FilterChip(
                  label: const Text('Inativos'),
                  selected: _statusFilter == false,
                  onSelected: (_) => setState(() => _statusFilter = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          congregationsAsync.when(
            data: (congregations) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<String?>(
                initialValue: _congregationFilter,
                decoration: const InputDecoration(labelText: 'Filtrar por congregacao'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                  ...congregations.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _congregationFilter = value),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filtered = users.where((user) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      user.fullName.toLowerCase().contains(_searchQuery) ||
                      user.email.toLowerCase().contains(_searchQuery);
                  final matchesRole = _roleFilter == null || user.role == _roleFilter;
                  final matchesStatus = _statusFilter == null || user.isActive == _statusFilter;
                  final matchesCongregation = _congregationFilter == null ||
                      user.congregationId == _congregationFilter;
                  return matchesSearch && matchesRole && matchesStatus && matchesCongregation;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Nenhum utilizador encontrado com os filtros aplicados.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?'),
                        ),
                        title: Text(user.fullName),
                        subtitle: Text('${user.email}\n${user.role.name.toUpperCase()} • ${user.isActive ? 'Ativo' : 'Inativo'}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit),
                        onTap: () => _openEditDialog(user),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro ao carregar utilizadores: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(UserEntity user) async {
    final manager = ref.read(currentUserProvider);
    if (manager == null) return;

    final isLeaderManager = manager.role == UserRole.lider;
    final managerCongregationId = manager.congregationId;

    final nameController = TextEditingController(text: user.fullName);
    var selectedRole = user.role;
    var selectedStatus = user.isActive;
    var selectedCongregation = user.congregationId;

    final congregations = await ref.read(allCongregationsStreamProvider.future);
    final uniqueCongregations = {
      for (final c in congregations) c.id: c,
    }.values.toList();

    if (selectedCongregation != null &&
        !uniqueCongregations.any((c) => c.id == selectedCongregation)) {
      selectedCongregation = null;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Editar perfil: ${user.fullName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome completo'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Perfil'),
                      items: (isLeaderManager
                              ? const <UserRole>[
                                  UserRole.visitante,
                                  UserRole.membro,
                                  UserRole.lider,
                                ]
                              : UserRole.values)
                          .map((role) => DropdownMenuItem(value: role, child: Text(role.name.toUpperCase())))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedRole = value;
                            if ((selectedRole == UserRole.membro || selectedRole == UserRole.lider) &&
                                (selectedCongregation == null ||
                                    selectedCongregation == visitorCongregationId)) {
                              final activeCongregations = uniqueCongregations
                                  .where((c) => c.isActive)
                                  .toList();
                              selectedCongregation = activeCongregations.isEmpty
                                  ? null
                                  : activeCongregations.first.id;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedCongregation,
                      decoration: const InputDecoration(labelText: 'Congregacao'),
                      items: [
                        if (!isLeaderManager && selectedRole != UserRole.membro && selectedRole != UserRole.lider)
                          const DropdownMenuItem<String?>(value: null, child: Text('Sem congregacao')),
                        ...(isLeaderManager
                                ? uniqueCongregations
                                    .where((c) => c.id == managerCongregationId)
                                    .toList()
                                : uniqueCongregations)
                            .map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.isActive ? c.name : '${c.name} (Inativa)'),
                          ),
                        ),
                      ],
                      onChanged: (value) => setStateDialog(() => selectedCongregation = value),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Utilizador ativo'),
                      value: selectedStatus,
                      onChanged: isLeaderManager
                          ? null
                          : (value) => setStateDialog(() => selectedStatus = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (isLeaderManager) {
                        final previousRole = user.role;
                        final roleChanged = selectedRole != previousRole;
                        final isAllowedTransition =
                            previousRole == UserRole.visitante &&
                            (selectedRole == UserRole.membro || selectedRole == UserRole.lider);

                        if (roleChanged && !isAllowedTransition) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Líder só pode alterar perfil de visitante para membro ou líder.'),
                            ),
                          );
                          return;
                        }

                        if (selectedCongregation != null && selectedCongregation != managerCongregationId) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Líder só pode atribuir a própria congregação.'),
                            ),
                          );
                          return;
                        }
                      }

                      if ((selectedRole == UserRole.membro || selectedRole == UserRole.lider) &&
                          (selectedCongregation == null ||
                              selectedCongregation == visitorCongregationId)) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Membro e líder devem ter uma congregação válida.'),
                          ),
                        );
                        return;
                      }

                      await ref.read(userAdminServiceProvider).updateUserProfile(
                        userId: user.uid,
                        role: selectedRole,
                        isActive: selectedStatus,
                        congregationId: selectedCongregation,
                        fullName: nameController.text.trim(),
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Perfil atualizado com sucesso.')),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
