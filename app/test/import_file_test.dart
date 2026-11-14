import 'dart:convert';
import 'dart:io';

import 'package:booking_manager/data/import_file.dart';
import 'package:booking_manager/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

String file(List<Map<String, dynamic>> bookings, {List<Map<String, dynamic>> blocks = const []}) =>
    jsonEncode({'format': 'booking-manager-import', 'version': 1, 'bookings': bookings, 'blocks': blocks});

Map<String, dynamic> stay(String id, String ci, String co, {String platform = 'Airbnb', num? paid, num? inHand}) => {
      'id': id, 'platform': platform, 'guest_name': 'Guest $id', 'check_in': ci, 'check_out': co,
      'guest_total_paid': paid, 'in_hand_amount': inHand, 'created_at': 'imported',
    };

void main() {
  test('rejects files that are not import files or have bad rows', () {
    expect(() => ImportFile.parse('hello'), throwsFormatException);
    expect(() => ImportFile.parse('{"bookings":[]}'), throwsFormatException);
    expect(() => ImportFile.parse(file([stay('a', '2026-05-03', '2026-05-01')])), throwsFormatException);
    expect(() => ImportFile.parse(file([stay('a', '2026-05-01', '2026-05-02', platform: 'Hotels')])), throwsFormatException);
    expect(() => ImportFile.parse(file([stay('a', '2026-05-01', '2026-05-02'), stay('a', '2026-06-01', '2026-06-02')])), throwsFormatException);
  });

  test('importing twice updates instead of duplicating, and keeps the unknown booking date', () async {
    final dir = await Directory.systemTemp.createTemp('bm');
    Hive.init(dir.path);
    final repo = Repository(await Hive.openBox('app'));
    await repo.load();
    await repo.startLocal();
    final f = ImportFile.parse(file(
      [stay('a', '2026-05-01', '2026-05-03', paid: 10000, inHand: 8000), stay('b', '2026-05-28', '2026-06-02', platform: 'Direct', inHand: 9000)],
      blocks: [{'id': 'x', 'start_date': '2026-06-10', 'end_date': '2026-06-10', 'reason': 'personal use'}],
    ));
    await repo.importFile(f);
    await repo.importFile(f);
    for (var i = 0; i < 50 && (repo.pendingOps.isNotEmpty || repo.syncing); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(repo.view.bookings.length, 2);
    expect(repo.view.blocks.length, 1);
    expect(repo.view.bookings.every((b) => b.bookedOn == null), isTrue);
    expect(repo.view.bookings.fold<double>(0, (s, b) => s + b.inHandAmount!), 17000);
    await Hive.close();
    await dir.delete(recursive: true);
  });
}
