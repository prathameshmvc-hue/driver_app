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
  bool _ok = false, _serviceOn = true, _forever = false;
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
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool ask = false}) async {
    final on = await Geolocator.isLocationServiceEnabled();
    var p = await Geolocator.checkPermission();
    if (on && p == LocationPermission.denied && ask) {
      p = await Geolocator.requestPermission();
    }
    final granted =
        p == LocationPermission.whileInUse || p == LocationPermission.always;
    if (!mounted) return;
    setState(() {
      _serviceOn = on;
      _forever = p == LocationPermission.deniedForever;
      _ok = on && granted;
    });
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_off, size: 72),
          const SizedBox(height: 16),
          Text(msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
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
        ]),
      ),
    );
  }
}