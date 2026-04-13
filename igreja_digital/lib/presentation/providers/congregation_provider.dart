import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/congregation_repository_impl.dart';
import '../../domain/entities/congregation_entity.dart';
import '../../domain/repositories/congregation_repository.dart';

final congregationRepositoryProvider = Provider<CongregationRepository>((ref) {
  return CongregationRepositoryImpl();
});

final congregationsStreamProvider = StreamProvider<List<CongregationEntity>>((ref) {
  final repository = ref.watch(congregationRepositoryProvider);

  // A lista pública deve exibir apenas congregações ativas.
  return repository.getCongregations(onlyActive: true);
});

final allCongregationsStreamProvider = StreamProvider<List<CongregationEntity>>((ref) {
  final repository = ref.watch(congregationRepositoryProvider);

  // Visão de gestão: inclui congregações ativas e inativas.
  return repository.getCongregations(onlyActive: false);
});

final selectedCongregationProvider = StateProvider<CongregationEntity?>((ref) => null);
