import 'dart:convert';

import '../core/models.dart';

/// A history file to load into the app: bookings and blocks in the same JSON
/// shape the app and the Sheet use. Ids are fixed in the file, so importing
/// the same file twice updates the same rows instead of duplicating them.
class ImportFile {
  final List<String> properties;
  final List<Booking> bookings;
  final List<Block> blocks;
  const ImportFile({this.properties = const [], this.bookings = const [], this.blocks = const []});

  static const format = 'booking-manager-import';

  /// Throws [FormatException] with a readable message if the file is wrong.
  factory ImportFile.parse(String text) {
    final Object? j;
    try {
      j = jsonDecode(text.trim().replaceFirst('﻿', ''));
    } catch (_) {
      throw const FormatException('This is not a Booking Manager import file.');
    }
    if (j is! Map || j['format'] != format) throw const FormatException('This is not a Booking Manager import file.');
    final bookings = <Booking>[];
    for (final e in (j['bookings'] as List?) ?? const []) {
      final m = (e as Map).cast<String, dynamic>();
      final b = Booking.fromJson(m);
      final label = b.guestName.isEmpty ? b.id : b.guestName;
      if (b.id.isEmpty || '${m['check_in']}'.isEmpty) throw FormatException('A booking has no id or check-in date ($label).');
      if (b.checkIn.year < 2000 || b.nights <= 0) throw FormatException('Check the dates of $label.');
      if (!platforms.contains(b.platform)) throw FormatException('Unknown platform "${b.platform}" for $label.');
      bookings.add(b);
    }
    final blocks = <Block>[];
    for (final e in (j['blocks'] as List?) ?? const []) {
      final b = Block.fromJson((e as Map).cast<String, dynamic>());
      if (b.id.isEmpty || b.endDate.isBefore(b.startDate)) throw FormatException('Check the dates of blocked period ${b.id}.');
      blocks.add(b);
    }
    final ids = bookings.map((b) => b.id).toSet();
    if (ids.length != bookings.length) throw const FormatException('Two bookings in the file share the same id.');
    return ImportFile(
      properties: ((j['properties'] as List?) ?? const []).map((e) => '$e').where((s) => s.trim().isNotEmpty).toList(),
      bookings: bookings,
      blocks: blocks,
    );
  }
}
