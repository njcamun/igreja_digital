import 'package:flutter/material.dart';
import 'package:igreja_digital/domain/models/prayer_request.dart';

class PrayerRequestCard extends StatelessWidget {
  final PrayerRequest request;
  final VoidCallback onPray;

  const PrayerRequestCard({
    super.key,
    required this.request,
    required this.onPray,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  request.isAnonymous
                      ? 'Anônimo'
                      : request.userName ?? 'Usuário',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: onPray,
                      tooltip: 'Orar por este pedido',
                    ),
                    Text('${request.prayerCount} orações'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}