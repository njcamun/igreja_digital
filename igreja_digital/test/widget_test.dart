import 'package:flutter_test/flutter_test.dart';
import 'package:igreja_digital/domain/entities/prayer_request_entity.dart';

void main() {
  test('PrayerRequestEntity copyWith atualiza estado e mantém campos', () {
    final now = DateTime.now();
    final request = PrayerRequestEntity(
      id: 'p1',
      title: 'Saúde',
      content: 'Ore pela minha família',
      userId: 'u1',
      userName: 'João',
      congregationId: 'c1',
      isAnonymous: false,
      isPrivate: false,
      isPublic: true,
      status: PrayerStatus.open,
      prayerCount: 0,
      prayedByUserIds: const [],
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );

    final updated = request.copyWith(
      status: PrayerStatus.praying,
      prayerCount: 1,
    );

    expect(updated.status, PrayerStatus.praying);
    expect(updated.prayerCount, 1);
    expect(updated.id, request.id);
    expect(updated.title, request.title);
  });
}
