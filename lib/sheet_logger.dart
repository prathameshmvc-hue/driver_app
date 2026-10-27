import 'package:http/http.dart' as http;

const _driverUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLScwpmy2B8Dq291hK6-ty8kZjqPTBn6LoVVoTKETgInomTLk4g/formResponse';
const _pickerUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLScF6n2C_FlpNtWus9Nf_WNRIqQ_kDZgGIvznIkrUsANWjPMaw/formResponse';

Future<void> logLogin(Map<String, String> d) async {
  try {
    final isDriver = d['type'] == 'driver';
    await http
        .post(
      Uri.parse(isDriver ? _driverUrl : _pickerUrl),
      body: isDriver
          ? {
        'entry.242811592': d['name'] ?? '',     // Driver name
        'entry.1715708316': d['mobile'] ?? '',   // Mobile number
        'entry.1314192498': d['tripId'] ?? '',   // Trip ID
      }
          : {
        'entry.1913416542': d['casparId'] ?? '',    // Caspar ID
        'entry.395436524': d['darkstoreId'] ?? '', // Darkstore ID
      },
    )
        .timeout(const Duration(seconds: 10));
  } catch (_) {} // never block login
}