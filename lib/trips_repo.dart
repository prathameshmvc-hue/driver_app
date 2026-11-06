import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// TODO: replace both once infra gives the public HTTPS URL (no trailing slash).
// apiKey is only used for /login. All other calls use the token it returns.
const apiBase = 'https://PASTE_URL_LATER';
const apiKey = 'PASTE_KEY_LATER';

// Keep false until apiBase is the real URL. When true, login needs the backend.
const verifyTripAtLogin = false;

const _timeout = Duration(seconds: 15);

String today() => DateTime.now().toIso8601String().substring(0, 10);

// ---- Login: exchange Trip ID / Darkstore ID for a signed token ----

/// Driver login. Returns false if the Trip ID does not exist.
Future<bool> loginDriver(String refId) =>
    _login({'role': 'driver', 'refId': refId});

/// Picker login. Returns false if the Darkstore ID does not exist.
Future<bool> loginPicker(String darkstore) =>
    _login({'role': 'picker', 'warehouse': darkstore});

Future<bool> _login(Map<String, String> body) async {
  final r = await http
      .post(Uri.parse('$apiBase/login'),
      headers: {'x-api-key': apiKey, 'Content-Type': 'application/json'},
      body: jsonEncode(body))
      .timeout(_timeout);
  if (r.statusCode == 404) return false;
  if (r.statusCode != 200) throw Exception('login ${r.statusCode}');
  final p = await SharedPreferences.getInstance();
  await p.setString('api_token', jsonDecode(r.body)['token'] as String);
  return true;
}

// Token expired (401)? Log in again with the saved IDs, then retry once.
Future<bool> _relogin(SharedPreferences p) async {
  try {
    if (p.getString('role') == 'driver') {
      return await loginDriver(p.getString('trip_id') ?? '');
    }
    return await loginPicker(p.getString('darkstore_id') ?? '');
  } catch (_) {
    return false;
  }
}

Map<String, String> _headers(String? token) => {
  'Content-Type': 'application/json',
  if (token != null) 'Authorization': 'Bearer $token',
};

Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> h) call) async {
  final p = await SharedPreferences.getInstance();
  var r = await call(_headers(p.getString('api_token')));
  if (r.statusCode == 401 && await _relogin(p)) {
    r = await call(_headers(p.getString('api_token')));
  }
  return r;
}

// ---- Data calls ----

/// Picker: all trips of the picker's darkstore for a date.
/// The backend uses the darkstore inside the token, not this parameter.
Future<List<Map<String, dynamic>>> fetchTrips(String warehouse,
    {String? date}) async {
  final uri = Uri.parse('$apiBase/trips').replace(
      queryParameters: {'warehouse': warehouse, 'date': date ?? today()});
  final r = await _authed((h) => http.get(uri, headers: h).timeout(_timeout));
  if (r.statusCode != 200) throw Exception('trips ${r.statusCode}');
  return (jsonDecode(r.body)['trips'] as List).cast<Map<String, dynamic>>();
}

/// Driver: one trip by Ref ID. null = not found.
Future<Map<String, dynamic>?> fetchTrip(String refId) async {
  final uri = Uri.parse('$apiBase/trips/${Uri.encodeComponent(refId)}');
  final r = await _authed((h) => http.get(uri, headers: h).timeout(_timeout));
  if (r.statusCode == 404) return null;
  if (r.statusCode != 200) throw Exception('trip ${r.statusCode}');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// Driver: send live location (fire and forget).
Future<void> sendLocation(
    String refId, double lat, double lng, double accuracy) async {
  try {
    await _authed((h) => http
        .post(Uri.parse('$apiBase/location'),
        headers: h,
        body: jsonEncode({
          'refId': refId,
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
        }))
        .timeout(const Duration(seconds: 8)));
  } catch (_) {}
}