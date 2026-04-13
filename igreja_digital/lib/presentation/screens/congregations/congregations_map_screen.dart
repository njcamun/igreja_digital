import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/congregation_provider.dart';
import 'congregation_detail_screen.dart';

class CongregationsMapScreen extends ConsumerStatefulWidget {
  const CongregationsMapScreen({super.key});

  @override
  ConsumerState<CongregationsMapScreen> createState() => _CongregationsMapScreenState();
}

class _CongregationsMapScreenState extends ConsumerState<CongregationsMapScreen> {
  final LatLng _initialCenter = const LatLng(-8.839988, 13.289437); // Centralizado em Luanda, Angola (exemplo)

  @override
  Widget build(BuildContext context) {
    final congregationsAsync = ref.watch(congregationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Congregações')),
      body: congregationsAsync.when(
        data: (congregations) {
          final mappableCongregations = congregations.where(
            (cong) => cong.latitude != 0 && cong.longitude != 0,
          );

          final markers = mappableCongregations.map((cong) {
            return Marker(
              markerId: MarkerId(cong.id),
              position: LatLng(cong.latitude, cong.longitude),
              infoWindow: InfoWindow(
                title: cong.name,
                snippet: '${cong.address}, ${cong.city}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CongregationDetailScreen(congregation: cong)),
                ),
              ),
            );
          }).toSet();

          if (markers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma congregação com coordenadas válidas para exibir no mapa.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(target: _initialCenter, zoom: 12),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar mapa: $err')),
      ),
    );
  }
}
