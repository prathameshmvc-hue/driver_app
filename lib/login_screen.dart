import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'sheet_logger.dart';
import 'trips_repo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in ['name', 'mobile', 'trip_id', 'caspar_id', 'darkstore_id'])
      k: TextEditingController()
  };
  String _role = 'driver';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'driver' && verifyTripAtLogin) {
      try {
        final t = await fetchTrip(_c['trip_id']!.text.trim());
        if (t == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip ID not found')));
          return;
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cannot verify trip. Check internet.')));
        return;
      }
    }
    final keys = _role == 'driver'
        ? ['name', 'mobile', 'trip_id']
        : ['caspar_id', 'darkstore_id'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', _role);

    for (final k in keys) {
      await prefs.setString(k, _c[k]!.text.trim());
    }

    // Log login to Google Sheet (fire-and-forget, don't await)
    logLogin(_role == 'driver'
        ? {
      'type': 'driver',
      'name': _c['name']!.text.trim(),
      'mobile': _c['mobile']!.text.trim(),
      'tripId': _c['trip_id']!.text.trim(),
    }
        : {
      'type': 'picker',
      'casparId': _c['caspar_id']!.text.trim(),
      'darkstoreId': _c['darkstore_id']!.text.trim(),
    });

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Widget _field(String key, String label,
      {TextInputType? type,
        List<TextInputFormatter>? fmt,
        String? Function(String?)? check}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: _c[key],
          keyboardType: type,
          inputFormatters: fmt,
          decoration: InputDecoration(labelText: label),
          validator: check ??
                  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      );

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const SizedBox(height: 32),
            const BrandHeader(),
            const SizedBox(height: 32),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'driver',
                    icon: Icon(Icons.local_shipping),
                    label: Text('Driver')),
                ButtonSegment(
                    value: 'picker',
                    icon: Icon(Icons.inventory_2),
                    label: Text('Picker')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 24),
            if (_role == 'driver') ...[
              _field('name', 'Driver name'),
              _field('mobile', 'Mobile number',
                  type: TextInputType.phone,
                  fmt: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10)
                  ],
                  check: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter a valid 10-digit number'),
              _field('trip_id', 'Trip ID'),
            ] else ...[
              _field('caspar_id', 'Caspar ID'),
              _field('darkstore_id', 'Darkstore ID'),
            ],
            const SizedBox(height: 8),
            FilledButton(onPressed: _submit, child: const Text('Login')),
          ]),
        ),
      ),
    ),
  );
}