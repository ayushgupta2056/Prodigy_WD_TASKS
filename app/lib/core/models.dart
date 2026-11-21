import 'dates.dart';

const platforms = ['Airbnb', 'MakeMyTrip', 'Goibibo', 'Agoda', 'Booking.com', 'Direct', 'Other'];
const statuses = ['confirmed', 'cancelled', 'completed'];
const blockReasons = ['personal use', 'maintenance', 'held', 'other'];

double? _num(Object? v) {
  if (v == null || v == '') return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}

class Booking {
  final String id;
  final String property;
  final String platform;
  final String platformBookingId;
  final String guestName;
  final int? guestsCount;
  final DateTime checkIn;
  final DateTime checkOut;
  final double? guestTotalPaid;
  final double? inHandAmount;
  final double costs;
  final String status;
  final String source;
  final List<String> editedFields;
  final String emailMessageId;
  final String createdAt;
  final String updatedAt;
  final String notes;

  const Booking({
    required this.id,
    this.property = '',
    this.platform = 'Direct',
    this.platformBookingId = '',
    this.guestName = '',
    this.guestsCount,
    required this.checkIn,
    required this.checkOut,
    this.guestTotalPaid,
    this.inHandAmount,
    this.costs = 0,
    this.status = 'confirmed',
    this.source = 'manual',
    this.editedFields = const [],
    this.emailMessageId = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.notes = '',
  });

  int get nights => daysBetween(checkIn, checkOut).clamp(0, 100000);

  /// Counts towards revenue and occupancy.
  bool get isActive => status == 'confirmed' || status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isEmail => source == 'email';
  bool get pendingInHand => inHandAmount == null;

  /// When the booking was made (best available: first time the app saw it).
  DateTime? get bookedOn => parseIso(createdAt);

  factory Booking.fromJson(Map<String, dynamic> j) {
    final ef = j['edited_fields'];
    return Booking(
      id: '${j['id']}',
      property: '${j['property'] ?? ''}',
      platform: '${j['platform'] ?? 'Other'}',
      platformBookingId: '${j['platform_booking_id'] ?? ''}',
      guestName: '${j['guest_name'] ?? ''}',
      guestsCount: _num(j['guests_count'])?.round(),
      checkIn: parseIso('${j['check_in']}') ?? DateTime.utc(1970),
      checkOut: parseIso('${j['check_out']}') ?? DateTime.utc(1970),
      guestTotalPaid: _num(j['guest_total_paid']),
      inHandAmount: _num(j['in_hand_amount']),
      costs: _num(j['costs']) ?? 0,
      status: '${j['status'] ?? 'confirmed'}',
      source: '${j['source'] ?? 'manual'}',
      editedFields: ef is List
          ? ef.map((e) => '$e').toList()
          : '${ef ?? ''}'.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      emailMessageId: '${j['email_message_id'] ?? ''}',
      createdAt: '${j['created_at'] ?? ''}',
      updatedAt: '${j['updated_at'] ?? ''}',
      notes: '${j['notes'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'property': property,
        'platform': platform,
        'platform_booking_id': platformBookingId,
        'guest_name': guestName,
        'guests_count': guestsCount,
        'check_in': toIso(checkIn),
        'check_out': toIso(checkOut),
        'nights': nights,
        'guest_total_paid': guestTotalPaid,
        'in_hand_amount': inHandAmount,
        'costs': costs,
        'status': status,
        'source': source,
        'edited_fields': editedFields,
        'email_message_id': emailMessageId,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'notes': notes,
      };

  Booking copyWith({
    String? property,
    String? platform,
    String? platformBookingId,
    String? guestName,
    int? Function()? guestsCount,
    DateTime? checkIn,
    DateTime? checkOut,
    double? Function()? guestTotalPaid,
    double? Function()? inHandAmount,
    double? costs,
    String? status,
    List<String>? editedFields,
    String? updatedAt,
    String? notes,
  }) =>
      Booking(
        id: id,
        property: property ?? this.property,
        platform: platform ?? this.platform,
        platformBookingId: platformBookingId ?? this.platformBookingId,
        guestName: guestName ?? this.guestName,
        guestsCount: guestsCount != null ? guestsCount() : this.guestsCount,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        guestTotalPaid: guestTotalPaid != null ? guestTotalPaid() : this.guestTotalPaid,
        inHandAmount: inHandAmount != null ? inHandAmount() : this.inHandAmount,
        costs: costs ?? this.costs,
        status: status ?? this.status,
        source: source,
        editedFields: editedFields ?? this.editedFields,
        emailMessageId: emailMessageId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        notes: notes ?? this.notes,
      );
}

class Block {
  final String id;
  final String property;
  final DateTime startDate;

  /// Last blocked night (inclusive).
  final DateTime endDate;
  final String reason;
  final String notes;

  const Block({
    required this.id,
    this.property = '',
    required this.startDate,
    required this.endDate,
    this.reason = 'other',
    this.notes = '',
  });

  /// Exclusive end, so blocks and bookings share [start, end) arithmetic.
  DateTime get endExclusive => addDays(endDate, 1);
  int get nights => daysBetween(startDate, endExclusive);

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        id: '${j['id']}',
        property: '${j['property'] ?? ''}',
        startDate: parseIso('${j['start_date']}') ?? DateTime.utc(1970),
        endDate: parseIso('${j['end_date']}') ?? DateTime.utc(1970),
        reason: '${j['reason'] ?? 'other'}',
        notes: '${j['notes'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'property': property,
        'start_date': toIso(startDate),
        'end_date': toIso(endDate),
        'reason': reason,
        'notes': notes,
      };
}

class UnparsedEmail {
  final String emailMessageId;
  final String platform;
  final String subject;
  final String from;
  final DateTime? receivedAt;
  final String error;
  final String gmailUrl;

  const UnparsedEmail({
    required this.emailMessageId,
    required this.platform,
    required this.subject,
    this.from = '',
    this.receivedAt,
    this.error = '',
    this.gmailUrl = '',
  });

  factory UnparsedEmail.fromJson(Map<String, dynamic> j) => UnparsedEmail(
        emailMessageId: '${j['email_message_id']}',
        platform: '${j['platform'] ?? ''}',
        subject: '${j['subject'] ?? ''}',
        from: '${j['from'] ?? ''}',
        receivedAt: DateTime.tryParse('${j['received_at'] ?? ''}')?.toLocal(),
        error: '${j['error'] ?? ''}',
        gmailUrl: '${j['gmail_url'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'email_message_id': emailMessageId,
        'platform': platform,
        'subject': subject,
        'from': from,
        'received_at': receivedAt?.toUtc().toIso8601String(),
        'error': error,
        'gmail_url': gmailUrl,
      };
}

class Snapshot {
  final List<Booking> bookings;
  final List<Block> blocks;
  final List<UnparsedEmail> unparsed;
  final List<String> properties;
  final String defaultProperty;
  final String sheetXlsxUrl;
  final String serverTime;

  const Snapshot({
    this.bookings = const [],
    this.blocks = const [],
    this.unparsed = const [],
    this.properties = const [],
    this.defaultProperty = '',
    this.sheetXlsxUrl = '',
    this.serverTime = '',
  });

  static const empty = Snapshot();

  factory Snapshot.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    return Snapshot(
      bookings: ((j['bookings'] as List?) ?? []).map((e) => Booking.fromJson((e as Map).cast())).toList(),
      blocks: ((j['blocks'] as List?) ?? []).map((e) => Block.fromJson((e as Map).cast())).toList(),
      unparsed: ((j['unparsed'] as List?) ?? []).map((e) => UnparsedEmail.fromJson((e as Map).cast())).toList(),
      properties: ((s['properties'] as List?) ?? []).map((e) => '$e').toList(),
      defaultProperty: '${s['default_property'] ?? ''}',
      sheetXlsxUrl: '${j['sheet_xlsx_url'] ?? ''}',
      serverTime: '${j['server_time'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'settings': {'currency': 'INR', 'properties': properties, 'default_property': defaultProperty},
        'bookings': bookings.map((b) => b.toJson()).toList(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'unparsed': unparsed.map((u) => u.toJson()).toList(),
        'sheet_xlsx_url': sheetXlsxUrl,
        'server_time': serverTime,
      };

  Snapshot copyWith({
    List<Booking>? bookings,
    List<Block>? blocks,
    List<UnparsedEmail>? unparsed,
    List<String>? properties,
  }) =>
      Snapshot(
        bookings: bookings ?? this.bookings,
        blocks: blocks ?? this.blocks,
        unparsed: unparsed ?? this.unparsed,
        properties: properties ?? this.properties,
        defaultProperty: defaultProperty,
        sheetXlsxUrl: sheetXlsxUrl,
        serverTime: serverTime,
      );
}
