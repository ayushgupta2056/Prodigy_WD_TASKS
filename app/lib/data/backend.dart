import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';
import 'demo_data.dart';
import 'local_ops.dart';

class ApplyResponse {
  final List<Map<String, dynamic>> results;
  final Snapshot snapshot;
  ApplyResponse(this.results, this.snapshot);
}

abstract class Backend {
  Future<Snapshot> snapshot();
  Future<ApplyResponse> apply(List<Map<String, dynamic>> ops);

  /// Ask the backend to check Gmail now, then return fresh data.
  Future<Snapshot> checkEmailsNow();
}

class BackendException implements Exception {
  final String message;
  final bool unauthorized;
  BackendException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

/// Talks to the Apps Script Web App.
///
/// Apps Script answers a POST with a 302 redirect to a one-time
/// googleusercontent.com URL that must be fetched with GET; `package:http`
/// does not follow redirects for POST, so this does it by hand.
class RemoteBackend implements Backend {
  final String url;
  final String apiKey;
  final http.Client _client;
  RemoteBackend(this.url, this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Snapshot> snapshot() async => Snapshot.fromJson(await _get({'action': 'snapshot'}));

  @override
  Future<ApplyResponse> apply(List<Map<String, dynamic>> ops) async {
    final data = await _post({'action': 'apply', 'ops': ops});
    return ApplyResponse(
      ((data['results'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      Snapshot.fromJson((data['snapshot'] as Map).cast()),
    );
  }

  @override
  Future<Snapshot> checkEmailsNow() async {
    final data = await _post({'action': 'sync'});
    return Snapshot.fromJson((data['snapshot'] as Map).cast());
  }

  Future<String> ping() async {
    final d = await _get({'action': 'ping'});
    return '${d['version']}';
  }

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final uri = Uri.parse(url).replace(queryParameters: {...params, 'key': apiKey});
    final res = await _client.get(uri).timeout(const Duration(seconds: 60));
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final req = http.Request('POST', Uri.parse(url))
      ..followRedirects = false
      ..headers['Content-Type'] = 'text/plain;charset=utf-8'
      ..body = jsonEncode({...body, 'key': apiKey});
    var res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 90)));
    var hops = 0;
    while ((res.statusCode == 301 || res.statusCode == 302 || res.statusCode == 303 || res.statusCode == 307) && hops++ < 5) {
      final loc = res.headers['location'];
      if (loc == null) break;
      res = await _client.get(Uri.parse(loc)).timeout(const Duration(seconds: 60));
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode != 200) throw BackendException('Server returned ${res.statusCode}');
    final Map<String, dynamic> j;
    try {
      j = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast();
    } catch (_) {
      throw BackendException('Unexpected response. Check the Web App URL and that it is deployed for "Anyone".');
    }
    if (j['ok'] != true) {
      final err = '${j['error'] ?? 'Unknown error'}';
      throw BackendException(err == 'unauthorized' ? 'The API key was not accepted.' : err, unauthorized: err == 'unauthorized');
    }
    return (j['data'] as Map).cast();
  }
}

/// In-memory backend with realistic sample data, for trying the app (and
/// for screenshots) before the Google side is set up.
class DemoBackend implements Backend {
  Snapshot _s;
  DemoBackend([Snapshot? initial]) : _s = initial ?? buildDemoSnapshot(DateTime.now());

  @override
  Future<Snapshot> snapshot() async => _s;

  @override
  Future<ApplyResponse> apply(List<Map<String, dynamic>> ops) async {
    final now = DateTime.now().toIso8601String();
    final results = <Map<String, dynamic>>[];
    for (final op in ops) {
      final p = (op['payload'] as Map?) ?? {};
      if (op['type'] == 'deleteBooking' && _s.bookings.any((b) => b.id == p['id'] && b.isEmail)) {
        results.add({'op_id': op['op_id'], 'ok': false, 'error': 'Bookings from email can be cancelled but not deleted'});
        continue;
      }
      _s = applyOpLocally(_s, op, nowIso: now);
      results.add({'op_id': op['op_id'], 'ok': true});
    }
    return ApplyResponse(results, _s);
  }

  @override
  Future<Snapshot> checkEmailsNow() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return _s;
  }
}
