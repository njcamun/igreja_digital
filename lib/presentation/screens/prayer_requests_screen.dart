import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:igreja_digital/presentation/providers/prayer_request_provider.dart';
import 'package:igreja_digital/presentation/widgets/prayer_request_card.dart';
import 'package:igreja_digital/presentation/widgets/add_prayer_request_dialog.dart';

class PrayerRequestsScreen extends ConsumerWidget {
  const PrayerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerRequestsAsync = ref.watch(prayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos de Oração'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: prayerRequestsAsync.when(
        data: (prayerRequests) {
          if (prayerRequests.isEmpty) {
            return const Center(
              child: Text('Nenhum pedido adicionado'),
            );
          }
          return ListView.builder(
            itemCount: prayerRequests.length,
            itemBuilder: (context, index) {
              final request = prayerRequests[index];
              return PrayerRequestCard(
                request: request,
                onPray: () => ref.read(prayerRequestsProvider.notifier).incrementPrayerCount(request.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Erro ao carregar pedidos'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(prayerRequestsProvider),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddPrayerRequestDialog(),
    );
  }
}