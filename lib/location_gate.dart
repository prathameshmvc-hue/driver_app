import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationGate extends StatefulWidget {
  const LocationGate({super.key, required this.child});
  final Widget child;
  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  bool _ok = false, _serviceOn = true, _forever = false, _busy = false;
  String? _error;
  StreamSubscription<ServiceStatus>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = Geolocator.getServiceStatusStream().listen((_) => _check());
    _check(ask: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check(ask: true);
  }

  Future<void> _check({bool ask = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask) {
        p = await Geolocator.requestPermission();
      }
      final on = await Geolocator.isLocationServiceEnabled();
      final granted =
          p == LocationPermission.whileInUse || p == LocationPermission.always;
      if (!mounted) return;
      setState(() {
        _error = null;
        _serviceOn = on;
        _forever = p == LocationPermission.deniedForever;
        _ok = on && granted;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return widget.child;
    final msg = !_serviceOn
        ? 'Turn on your phone location (GPS) to continue.'
        : _forever
        ? 'Location permission is blocked. Enable it in app settings.'
        : 'Location permission is required to continue.';
    final label = !_serviceOn
        ? 'Turn on GPS'
        : _forever
        ? 'Open settings'
        : 'Allow location';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_off, size: 72),
          const SizedBox(height: 16),
          Text(msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (!_serviceOn) {
                await Geolocator.openLocationSettings();
              } else if (_forever) {
                await Geolocator.openAppSettings();
              } else {
                await _check(ask: true);
              }
            },
            child: Text(label),
          ),
          TextButton(
              onPressed: () => _check(ask: true), child: const Text('Retry')),
        ]),
      ),
    );
  }
}