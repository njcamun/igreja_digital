import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/user_admin_provider.dart';

class ChurchSummaryScreen extends ConsumerWidget {
  const ChurchSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final congregationsAsync = ref.watch(congregationsStreamProvider);
    final memberCountAsync = ref.watch(memberCountStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo da Igreja')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Estatísticas gerais',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _StatCard(
            icon: Icons.church_outlined,
            label: 'Congregações',
            valueAsync: congregationsAsync.when(
              data: (list) => AsyncValue.data(list.length),
              loading: () => const AsyncValue.loading(),
              error: (e, s) => AsyncValue.error(e, s),
            ),
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          _StatCard(
            icon: Icons.people_outline,
            label: 'Membros',
            valueAsync: memberCountAsync,
            color: Colors.blue,
            subtitle: 'Inclui administradores, líderes e membros',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final AsyncValue<int> valueAsync;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.valueAsync,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(150),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            valueAsync.when(
              data: (count) => Text(
                '$count',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Icon(Icons.error_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
