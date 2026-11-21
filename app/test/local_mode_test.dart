import 'dart:io';

import 'package:booking_manager/core/dates.dart';
import 'package:booking_manager/core/models.dart';
import 'package:booking_manager/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bm');
    Hive.init(dir.path);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> settle(Repository r) async {
    for (var i = 0; i < 50 && (r.pendingOps.isNotEmpty || r.syncing); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  test('demo data can be replaced by an empty device-only calendar that survives a restart', () async {
    final box = await Hive.openBox('app');
    final repo = Repository(box);
    await repo.load();
    await repo.startDemo();
    expect(repo.view.bookings, isNotEmpty);

    await repo.startLocal();
    expect(repo.mode, Mode.local);
    expect(repo.view.bookings, isEmpty);

    await repo.saveBooking(Booking(id: 'b1', guestName: 'Asha', checkIn: parseIso('2026-12-01')!, checkOut: parseIso('2026-12-03')!, guestTotalPaid: 9000));
    await settle(repo);
    expect(repo.pendingOps, isEmpty);

    final reopened = Repository(box);
    await reopened.load();
    await settle(reopened);
    expect(reopened.mode, Mode.local);
    expect(reopened.view.bookings.map((b) => b.guestName), ['Asha']);
  });

  test('device-only entries become upload ops when a Sheet is connected', () async {
    final repo = Repository(await Hive.openBox('app'));
    final s = Snapshot(
      properties: const ['Cedar'],
      bookings: [Booking(id: 'b1', checkIn: parseIso('2026-12-01')!, checkOut: parseIso('2026-12-03')!)],
    );
    final ops = repo.uploadOpsFor(s);
    expect(ops.map((o) => o['type']), ['setProperties', 'upsertBooking']);
    expect(((ops[1]['payload'] as Map)['booking'] as Map)['id'], 'b1');
  });
}
