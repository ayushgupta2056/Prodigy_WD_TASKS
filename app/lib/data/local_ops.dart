import '../core/models.dart';

/// Applies a queued op to a snapshot on the device, mirroring
/// apps-script/src/70_ApiCore.gs, so edits show instantly and work offline.
/// The server stays the source of truth: its next snapshot replaces this.
Snapshot applyOpLocally(Snapshot s, Map<String, dynamic> op, {String nowIso = ''}) {
  final p = (op['payload'] as Map?)?.cast<String, dynamic>() ?? {};
  switch (op['type']) {
    case 'upsertBooking':
      final incoming = Booking.fromJson((p['booking'] as Map).cast());
      final i = s.bookings.indexWhere((b) => b.id == incoming.id);
      final list = [...s.bookings];
      if (i < 0) {
        list.add(Booking.fromJson({...incoming.toJson(), 'source': 'manual', 'edited_fields': <String>[], 'created_at': nowIso, 'updated_at': nowIso}));
      } else {
        final old = list[i];
        final edited = old.isEmail ? {...old.editedFields, ...changedEmailFields(old, incoming)}.toList() : old.editedFields;
        list[i] = Booking.fromJson({
          ...incoming.toJson(),
          'source': old.source,
          'email_message_id': old.emailMessageId,
          'created_at': old.createdAt,
          'edited_fields': edited,
          'updated_at': nowIso,
        });
      }
      var unparsed = s.unparsed;
      final mid = '${(p['booking'] as Map)['email_message_id'] ?? ''}';
      if (i < 0 && mid.isNotEmpty) unparsed = unparsed.where((u) => u.emailMessageId != mid).toList();
      return s.copyWith(bookings: list, unparsed: unparsed);
    case 'cancelBooking':
      return s.copyWith(
          bookings: s.bookings.map((b) {
        if (b.id != p['id'] || b.isCancelled) return b;
        return b.copyWith(status: 'cancelled', editedFields: b.isEmail ? {...b.editedFields, 'status'}.toList() : b.editedFields);
      }).toList());
    case 'deleteBooking':
      return s.copyWith(bookings: s.bookings.where((b) => !(b.id == p['id'] && !b.isEmail)).toList());
    case 'upsertBlock':
      final blk = Block.fromJson((p['block'] as Map).cast());
      final i = s.blocks.indexWhere((b) => b.id == blk.id);
      final list = [...s.blocks];
      if (i < 0) {
        list.add(blk);
      } else {
        list[i] = blk;
      }
      return s.copyWith(blocks: list);
    case 'deleteBlock':
      return s.copyWith(blocks: s.blocks.where((b) => b.id != p['id']).toList());
    case 'resolveUnparsed':
      return s.copyWith(unparsed: s.unparsed.where((u) => u.emailMessageId != p['email_message_id']).toList());
    case 'setProperties':
      return s.copyWith(properties: ((p['properties'] as List?) ?? []).map((e) => '$e').toList());
    default:
      return s;
  }
}

/// Email-owned fields the user changed (these are protected from the parser).
List<String> changedEmailFields(Booking old, Booking now) {
  final out = <String>[];
  if (old.property != now.property) out.add('property');
  if (old.platform != now.platform) out.add('platform');
  if (old.platformBookingId != now.platformBookingId) out.add('platform_booking_id');
  if (old.guestName != now.guestName) out.add('guest_name');
  if (old.guestsCount != now.guestsCount) out.add('guests_count');
  if (old.checkIn != now.checkIn) out.add('check_in');
  if (old.checkOut != now.checkOut) out.add('check_out');
  if (old.guestTotalPaid != now.guestTotalPaid) out.add('guest_total_paid');
  if (old.status != now.status) out.add('status');
  return out;
}
