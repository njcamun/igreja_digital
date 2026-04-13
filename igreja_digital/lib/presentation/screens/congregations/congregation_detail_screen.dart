import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/congregation_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';
import 'congregation_form_screen.dart';

class CongregationDetailScreen extends ConsumerStatefulWidget {
  final CongregationEntity congregation;

  const CongregationDetailScreen({super.key, required this.congregation});

  @override
  ConsumerState<CongregationDetailScreen> createState() =>
      _CongregationDetailScreenState();
}

class _CongregationDetailScreenState
    extends ConsumerState<CongregationDetailScreen> {
  late CongregationEntity _congregation;

  @override
  void initState() {
    super.initState();
    _congregation = widget.congregation;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role == UserRole.admin || user?.role == UserRole.lider;
    final canDelete = user?.role == UserRole.admin || user?.role == UserRole.lider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Congregação'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<CongregationEntity?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CongregationFormScreen(congregation: _congregation),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _congregation = updated);
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remover congregação',
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_congregation.imageUrl != null)
              Image.network(
                _congregation.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.church,
                  size: 80,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _congregation.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _congregation.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Divider(height: 40),
                  _infoRow(
                    context,
                    Icons.location_on,
                    'Morada',
                    '${_congregation.address}, ${_congregation.city}, ${_congregation.province}',
                  ),
                  _infoRow(
                    context,
                    Icons.person,
                    'Responsável',
                    _congregation.leaderName,
                  ),
                  _infoRow(
                    context,
                    Icons.phone,
                    'Contacto',
                    _congregation.phone,
                    onTap: () => _launchURL('tel:${_congregation.phone}'),
                  ),
                  if (_congregation.whatsappNumber.isNotEmpty)
                    _infoRow(
                      context,
                      Icons.chat,
                      'WhatsApp',
                      _congregation.whatsappNumber,
                      onTap: () =>
                          _openWhatsApp(_congregation.whatsappNumber),
                    ),
                  _infoRow(
                    context,
                    Icons.email,
                    'Email',
                    _congregation.email,
                    onTap: () => _launchURL('mailto:${_congregation.email}'),
                  ),
                  Text(
                    'Horários de Culto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ..._congregation.serviceTimes.map((time) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(time, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () => _openMap(context),
                      icon: const Icon(Icons.directions),
                      label: const Text('COMO CHEGAR (ROTA)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(BuildContext context) async {
    final lat = _congregation.latitude;
    final lng = _congregation.longitude;
    final encodedAddress = Uri.encodeComponent(
      '${_congregation.address}, ${_congregation.city}, ${_congregation.province}, ${_congregation.country}',
    );
    final hasCoordinates = lat != 0 && lng != 0;
    final candidates = [
      if (hasCoordinates)
        Uri.parse('google.navigation:q=$lat,$lng&mode=d'),
      if (hasCoordinates)
        Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(_congregation.name)})'),
      if (hasCoordinates)
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
    ];

    for (final uri in candidates) {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a navegação para esta congregação.'),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final normalized = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/${normalized.replaceAll('+', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover congregação'),
        content: Text(
          'Deseja remover a congregação "${_congregation.name}"? Esta ação irá desativá-la da lista pública.',
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
          .deleteCongregation(_congregation.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Congregação removida com sucesso.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover congregação: $error')),
      );
    }
  }
}
