import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/prayer_request_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/prayer_provider.dart';
import 'prayer_form_screen.dart';
import 'prayer_detail_screen.dart';

class PrayerListScreen extends ConsumerWidget {
  const PrayerListScreen({super.key});

  Widget _buildScrollableState(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildVisibilityFilterBar(BuildContext context, WidgetRef ref) {
    try {
      final visibilityFilter = ref.watch(prayerVisibilityFilterProvider);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PrayerVisibilityFilter.values.map((filter) {
            try {
              final label = {
                PrayerVisibilityFilter.all: 'Todos',
                PrayerVisibilityFilter.public: 'Públicos',
                PrayerVisibilityFilter.private: 'Privados',
                PrayerVisibilityFilter.anonymous: 'Anónimos',
              }[filter]!;

              return ChoiceChip(
                label: Text(label),
                selected: filter == visibilityFilter,
                onSelected: (_) {
                  try {
                    ref.read(prayerVisibilityFilterProvider.notifier).state =
                        filter;
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao aplicar filtro: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            } catch (e) {
              return Chip(
                label: const Text('Erro no filtro'),
                backgroundColor: Colors.red.shade100,
              );
            }
          }).toList(),
        ),
      );
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Erro ao carregar filtros: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildStatusFilterBar(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(prayerStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Todos estados'),
            selected: selectedStatus == null,
            onSelected: (_) {
              ref.read(prayerStatusFilterProvider.notifier).state = null;
            },
          ),
          ...PrayerStatus.values.map(
            (status) => ChoiceChip(
              label: Text(status.label),
              selected: selectedStatus == status,
              onSelected: (_) {
                ref.read(prayerStatusFilterProvider.notifier).state = status;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCongregationFilter(
    BuildContext context,
    WidgetRef ref,
    UserEntity? user,
  ) {
    final canFilterByCongregation =
        user?.role == UserRole.admin || user?.role == UserRole.lider;

    if (!canFilterByCongregation) {
      return const SizedBox.shrink();
    }

    final selectedCongregation = ref.watch(prayerCongregationFilterProvider);
    final congregationsAsync = ref.watch(allCongregationsStreamProvider);

    return congregationsAsync.when(
      data: (congregations) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String?>(
            initialValue: selectedCongregation,
            decoration: const InputDecoration(
              labelText: 'Filtrar por congregação',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas congregações'),
              ),
              ...congregations.map(
                (c) =>
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ),
            ],
            onChanged: (value) {
              ref.read(prayerCongregationFilterProvider.notifier).state = value;
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final prayersAsync = ref.watch(prayerRequestsStreamProvider);
      final user = ref.watch(currentUserProvider);

      return Scaffold(
        appBar: AppBar(title: const Text('Pedidos de Oração')),
        body: Column(
          children: [
            if (user?.role != UserRole.visitante)
              _buildVisibilityFilterBar(context, ref),
            if (user?.role != UserRole.visitante)
              _buildStatusFilterBar(context, ref),
            _buildCongregationFilter(context, ref, user),
            Expanded(
              child: prayersAsync.when(
                data: (prayers) {
                  try {
                    if (prayers.isEmpty) {
                      return _buildScrollableState(
                        context,
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum pedido de oração encontrado.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: prayers.length,
                      itemBuilder: (context, index) {
                        try {
                          final prayer = prayers[index];
                          return _PrayerCard(prayer: prayer);
                        } catch (e) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.red.shade50,
                            child: const ListTile(
                              leading: Icon(Icons.error, color: Colors.red),
                              title: Text('Erro ao carregar pedido'),
                              subtitle: Text('Tente recarregar a tela'),
                            ),
                          );
                        }
                      },
                    );
                  } catch (e) {
                    return _buildScrollableState(
                      context,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Erro ao processar pedidos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Detalhes: $e',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(prayerRequestsStreamProvider),
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                loading: () => _buildScrollableState(
                  context,
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Carregando pedidos...'),
                    ],
                  ),
                ),
                error: (err, stack) {
                  final errorText = err.toString();
                  final normalizedError = errorText.toLowerCase();
                  final isIndexBuilding =
                      normalizedError.contains('failed-precondition') &&
                      normalizedError.contains('currently building');

                  return _buildScrollableState(
                    context,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          isIndexBuilding
                              ? 'A preparar dados no servidor'
                              : 'Não foi possível carregar os pedidos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isIndexBuilding
                              ? 'Os índices do Firestore ainda estão em construção. Tente novamente em alguns minutos.'
                              : 'Verifique sua conexão com a internet e tente novamente.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Detalhes do erro: $errorText',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.invalidate(prayerRequestsStreamProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: user != null
            ? FloatingActionButton(
                onPressed: () {
                  try {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrayerFormScreen(),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao abrir formulário: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Icon(Icons.add),
              )
            : null,
      );
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Erro crítico na tela',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Detalhes: $e',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _PrayerCard extends ConsumerWidget {
  final PrayerRequestEntity prayer;
  const _PrayerCard({required this.prayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isRecent = DateTime.now().difference(prayer.createdAt).inHours < 24;
      final authorLabel = prayer.isAnonymous
          ? 'Pedido Anónimo'
          : prayer.userName;
      final statusLabel = prayer.status.label.toUpperCase();

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          title: Text(
            prayer.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$authorLabel • ${DateFormat('dd/MM').format(prayer.createdAt)}',
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (prayer.isPrivate)
                    const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                  if (prayer.isAnonymous)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.visibility_off,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text('${prayer.prayerCount} intercessões'),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRecent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Novo',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              const SizedBox(height: 4),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
          onTap: () {
            try {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrayerDetailScreen(prayer: prayer),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao abrir detalhes: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: const Text('Erro ao carregar pedido'),
          subtitle: Text('Detalhes: $e'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro no pedido: $e'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      );
    }
  }
}
