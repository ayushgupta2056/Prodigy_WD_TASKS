import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../core/insights.dart';
import '../core/models.dart';
import 'backend.dart';
import 'import_file.dart';
import 'local_ops.dart';

/// local: no Google account; everything is kept on this device only.
enum Mode { unconfigured, demo, local, live }

/// Single source of state for the UI.
///
/// * Opens instantly from the on-device cache (Hive).
/// * Every edit is applied locally at once and queued; the queue is sent to
///   the backend when online. Ops carry app-generated ids, so a retry after a
///   dropped connection is harmless.
/// * Each successful sync replaces the local copy with the server's snapshot.
class Repository extends ChangeNotifier {
  final Box _box;
  Repository(this._box);

  static const _uuid = Uuid();

  Mode mode = Mode.unconfigured;
  String themeMode = 'system'; // system | light | dark
  String url = '';
  String apiKey = '';
  Backend? _backend;

  Snapshot _server = Snapshot.empty;
  Snapshot view = Snapshot.empty;
  List<Map<String, dynamic>> pendingOps = [];

  bool loaded = false;
  bool syncing = false;
  DateTime? lastSyncAt;
  String? lastError;
  final List<String> opErrors = [];

  List<Overlap> _overlaps = const [];
  List<Overlap> get overlaps => _overlaps;
  Set<String> get overlapIds => {for (final o in _overlaps) ...[o.aId, o.bId]};

  // ---- Lifecycle ----------------------------------------------------------

  Future<void> load() async {
    url = _box.get('url', defaultValue: '') as String;
    apiKey = _box.get('apiKey', defaultValue: '') as String;
    mode = Mode.values.byName(_box.get('mode', defaultValue: 'unconfigured') as String);
    themeMode = _box.get('themeMode', defaultValue: 'system') as String;
    final cached = _box.get('snapshot') as String?;
    if (cached != null) _server = Snapshot.fromJson((jsonDecode(cached) as Map).cast());
    final ops = _box.get('pendingOps') as String?;
    if (ops != null) pendingOps = (jsonDecode(ops) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final ls = _box.get('lastSyncAt') as String?;
    if (ls != null) lastSyncAt = DateTime.tryParse(ls);
    _backend = switch (mode) {
      Mode.live => RemoteBackend(url, apiKey),
      Mode.demo => DemoBackend(cached == null ? null : _server),
      Mode.local => DemoBackend(_server),
      Mode.unconfigured => null,
    };
    _recompute();
    loaded = true;
    notifyListeners();
    if (mode != Mode.unconfigured) unawaited(sync());
  }

  Future<void> connect(String newUrl, String newKey) async {
    final backend = RemoteBackend(newUrl.trim(), newKey.trim());
    await backend.ping(); // throws with a readable message if wrong
    url = newUrl.trim();
    apiKey = newKey.trim();
    final switching = mode != Mode.live;
    // Entries made in device-only mode are uploaded to the Sheet, not lost.
    final carry = mode == Mode.local ? uploadOpsFor(view) : <Map<String, dynamic>>[];
    mode = Mode.live;
    _backend = backend;
    if (switching) {
      _server = Snapshot.empty;
      pendingOps = carry;
    }
    await _box.putAll({'url': url, 'apiKey': apiKey, 'mode': mode.name});
    await _persist();
    _recompute();
    notifyListeners();
    await sync();
  }

  Future<void> startDemo() async {
    mode = Mode.demo;
    final b = DemoBackend();
    _backend = b;
    _server = await b.snapshot();
    pendingOps = [];
    await _box.put('mode', mode.name);
    await _persist();
    _recompute();
    lastSyncAt = DateTime.now();
    notifyListeners();
  }

  /// Start with an empty calendar saved only on this device (no Google).
  Future<void> startLocal() async {
    mode = Mode.local;
    _server = Snapshot.empty;
    _backend = DemoBackend(_server);
    pendingOps = [];
    lastSyncAt = null;
    await _box.putAll({'mode': mode.name, 'url': '', 'apiKey': ''});
    url = '';
    apiKey = '';
    await _persist();
    _recompute();
    notifyListeners();
  }

  /// Ops that recreate [s]'s manual data on a fresh backend.
  @visibleForTesting
  List<Map<String, dynamic>> uploadOpsFor(Snapshot s) => [
        if (s.properties.isNotEmpty) {'op_id': newId(), 'type': 'setProperties', 'payload': {'properties': s.properties}},
        for (final b in s.bookings) {'op_id': newId(), 'type': 'upsertBooking', 'payload': {'booking': b.toJson()}},
        for (final b in s.blocks) {'op_id': newId(), 'type': 'upsertBlock', 'payload': {'block': b.toJson()}},
      ];

  Future<void> signOut() async {
    mode = Mode.unconfigured;
    _backend = null;
    _server = Snapshot.empty;
    pendingOps = [];
    url = '';
    apiKey = '';
    await _box.clear();
    await _box.put('themeMode', themeMode);
    _recompute();
    notifyListeners();
  }

  // ---- Sync -------------------------------------------------------------------

  /// [checkEmails]: also ask the backend to read Gmail right now.
  Future<void> sync({bool checkEmails = false}) async {
    final backend = _backend;
    if (backend == null || syncing) return;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      var fetched = false;
      if (pendingOps.isNotEmpty) {
        fetched = true;
        final sent = [...pendingOps];
        final res = await backend.apply(sent);
        final done = {for (final r in res.results) r['op_id']};
        for (final r in res.results.where((r) => r['ok'] != true)) {
          opErrors.add('${r['error']}');
        }
        pendingOps = pendingOps.where((o) => !done.contains(o['op_id'])).toList();
        _server = res.snapshot;
      }
      if (checkEmails) {
        _server = await backend.checkEmailsNow();
      } else if (!fetched) {
        _server = await backend.snapshot();
      }
      lastSyncAt = DateTime.now();
      await _persist();
    } catch (e) {
      lastError = e is BackendException ? e.message : 'Offline. Changes are saved on this device and will sync later.';
    } finally {
      syncing = false;
      _recompute();
      notifyListeners();
    }
  }

  Timer? _debounce;
  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => sync());
  }

  // ---- Edits --------------------------------------------------------------------

  String newId() => _uuid.v4();

  Future<void> _enqueue(String type, Map<String, dynamic> payload) async {
    pendingOps.add({'op_id': newId(), 'type': type, 'payload': payload});
    await _persist();
    _recompute();
    notifyListeners();
    _scheduleSync();
  }

  /// Adds (or updates, by id) every booking and blocked period in [f].
  /// Properties in the file are added to the list, never removed.
  Future<void> importFile(ImportFile f) async {
    final props = [...view.properties];
    for (final p in f.properties) {
      if (!props.contains(p)) props.add(p);
    }
    if (props.length != view.properties.length) {
      pendingOps.add({'op_id': newId(), 'type': 'setProperties', 'payload': {'properties': props}});
    }
    for (final b in f.bookings) {
      pendingOps.add({'op_id': newId(), 'type': 'upsertBooking', 'payload': {'booking': b.toJson()}});
    }
    for (final b in f.blocks) {
      pendingOps.add({'op_id': newId(), 'type': 'upsertBlock', 'payload': {'block': b.toJson()}});
    }
    await _persist();
    _recompute();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> saveBooking(Booking b, {String emailMessageId = ''}) => _enqueue('upsertBooking', {
        'booking': {...b.toJson(), if (emailMessageId.isNotEmpty) 'email_message_id': emailMessageId},
      });

  Future<void> setInHand(Booking b, double inHand, double? costs) => saveBooking(b.copyWith(inHandAmount: () => inHand, costs: costs ?? b.costs));

  Future<void> cancelBooking(String id) => _enqueue('cancelBooking', {'id': id});
  Future<void> deleteBooking(String id) => _enqueue('deleteBooking', {'id': id});
  Future<void> saveBlock(Block b) => _enqueue('upsertBlock', {'block': b.toJson()});
  Future<void> deleteBlock(String id) => _enqueue('deleteBlock', {'id': id});
  Future<void> dismissUnparsed(String messageId) => _enqueue('resolveUnparsed', {'email_message_id': messageId});
  Future<void> setProperties(List<String> props) => _enqueue('setProperties', {'properties': props});

  Future<void> setThemeMode(String m) async {
    themeMode = m;
    await _box.put('themeMode', m);
    notifyListeners();
  }

  void clearOpErrors() {
    opErrors.clear();
    notifyListeners();
  }

  // ---- Derived ------------------------------------------------------------------

  List<String> get properties => view.properties.isEmpty ? const ['My property'] : view.properties;
  String get defaultProperty => view.defaultProperty.isNotEmpty ? view.defaultProperty : properties.first;

  Booking? booking(String id) {
    for (final b in view.bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Stays that have started (or finished) and still have no in-hand amount.
  List<Booking> get pendingInHand {
    final t = today();
    return view.bookings.where((b) => b.isActive && b.pendingInHand && !b.checkIn.isAfter(t)).toList()
      ..sort((a, b) => a.checkOut.compareTo(b.checkOut));
  }

  InsightsData insights({String? property}) => InsightsData(
        bookings: view.bookings,
        blocks: view.blocks,
        properties: properties,
        defaultProperty: defaultProperty,
        property: property,
      );

  void _recompute() {
    var s = _server;
    final now = DateTime.now().toIso8601String();
    for (final op in pendingOps) {
      s = applyOpLocally(s, op, nowIso: now);
    }
    // Same rule as the backend: stays past check-out are completed.
    final t = today();
    s = s.copyWith(
        bookings: s.bookings
            .map((b) => b.status == 'confirmed' && !b.checkOut.isAfter(t) && !b.editedFields.contains('status') ? b.copyWith(status: 'completed') : b)
            .toList());
    view = s;
    _overlaps = findOverlaps(s.bookings, s.blocks, defaultProperty: defaultProperty, properties: properties);
  }

  Future<void> _persist() async {
    await _box.putAll({
      'snapshot': jsonEncode(_server.toJson()),
      'pendingOps': jsonEncode(pendingOps),
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
    });
  }

  @visibleForTesting
  static String isoToday() => toIso(today());
}
