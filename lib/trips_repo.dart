import 'dart:convert';
import 'package:http/http.dart' as http;

// TODO: replace both once infra gives the public HTTPS URL (no trailing slash)
const apiBase = 'https://PASTE_URL_LATER';
const apiKey = 'PASTE_KEY_LATER';
const verifyTripAtLogin = false; // set true once apiBase is the real URL
const _h = {'x-api-key': apiKey};

String today() => DateTime.now().toIso8601String().substring(0, 10);

/// Picker: all trips of a darkstore (Warehouse Name) for a date
Future<List<Map<String, dynamic>>> fetchTrips(String warehouse,
    {String? date}) async {
  final uri = Uri.parse('$apiBase/trips').replace(
      queryParameters: {'warehouse': warehouse, 'date': date ?? today()});
  final r = await http.get(uri, headers: _h).timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw Exception('trips ${r.statusCode}');
  return (jsonDecode(r.body)['trips'] as List).cast<Map<String, dynamic>>();
}

/// Driver: one trip by Ref ID. null = not found
Future<Map<String, dynamic>?> fetchTrip(String refId) async {
  final r = await http
      .get(Uri.parse('$apiBase/trips/${Uri.encodeComponent(refId)}'), headers: _h)
      .timeout(const Duration(seconds: 15));
  if (r.statusCode == 404) return null;
  if (r.statusCode != 200) throw Exception('trip ${r.statusCode}');
  return jsonDecode(r.body) as Map<String, dynamic>;
}