import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_gate.dart';
import 'theme.dart';
import 'trips_repo.dart';

class Stop {
  Stop(this.name, this.type, this.eta, {this.done = false});
  final String name, type, eta;
  bool done;
}

class DriverHome extends StatelessWidget {
  const DriverHome({super.key, required this.prefs, required this.onLogout});
  final SharedPreferences prefs;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Trip'), actions: [
      IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
    ]),
    body: LocationGate(
      child: _TripView(
        name: prefs.getString('name') ?? '',
        tripId: prefs.getString('trip_id') ?? '',
        onEnded: onLogout,
      ),
    ),
  );
}

class _TripView extends StatefulWidget {
  const _TripView(
      {required this.name, required this.tripId, required this.onEnded});
  final String name, tripId;
  final VoidCallback onEnded;
  @override
  State<_TripView> createState() => _TripViewState();
}

class _TripViewState extends State<_TripView> {
  List<Stop> _stops = [];
  Map<String, dynamic>? _trip;
  bool _loading = true;
  String? _error;
  StreamSubscription<Position>? _sub;
  Position? _pos;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((p) => setState(() => _pos = p));
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final p = _pos;
      if (p != null && _trip != null) {
        sendLocation(widget.tripId, p.latitude, p.longitude, p.accuracy);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  // Route column looks like: hubA-ds1-ds2-ds3 (stops joined by '-')
  List<Stop> _parseRoute(String route) => route
      .split('-')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .map((p) => Stop(p, p.contains('_sh_') ? 'SH' : 'DS', '-'))
      .toList();

  String _s(String k) => (_trip?[k] ?? '').toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await fetchTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = t;
        _stops = t == null ? [] : _parseRoute((t['route'] ?? '').toString());
        _error = t == null ? 'Trip not found' : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load trip';
        _loading = false;
      });
    }
  }

  void _endTrip() {
    final pending = _stops.where((s) => !s.done).length;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(pending > 0 ? Icons.warning_amber : Icons.flag,
            color: pending > 0 ? Colors.orange : Colors.green, size: 40),
        title: Text(pending > 0 ? 'Cannot end trip' : 'End trip?'),
        content: Text(pending > 0
            ? '$pending stop(s) not completed yet.'
            : 'All stops are completed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(pending > 0 ? 'OK' : 'Cancel')),
          if (pending == 0)
            FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEnded();
                },
                child: const Text('End trip')),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _stops.length,
      itemBuilder: (_, i) {
        final s = _stops[i];
        return ListTile(
          // Demo only: tap a stop to toggle it as reached (live GPS later).
          onTap: () => setState(() => s.done = !s.done),
          leading: Icon(
              s.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: s.done ? Colors.green : Colors.grey),
          title: Text(s.name),
          subtitle: Text('${s.type} · ETA ${s.eta}'),
          trailing: Text(s.done ? 'Reached' : 'Pending',
              style:
              TextStyle(color: s.done ? Colors.green : Colors.orange)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: double.infinity,
      color: Brand.primary.withOpacity(0.08),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Trip ${widget.tripId}',
            style: Theme.of(context).textTheme.titleLarge),
        Text('Driver: ${widget.name}'),
        if (_trip != null) ...[
          Text('Vehicle: ${_s('vehicleNumber')} · ${_s('vehicleType')}'),
          Text('Status: ${_s('status')}'),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.my_location,
              size: 16, color: _pos == null ? Colors.grey : Colors.green),
          const SizedBox(width: 6),
          Text(_pos == null
              ? 'Getting location…'
              : '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}'),
        ]),
      ]),
    ),
    Expanded(child: _content()),
    Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        onPressed: _stops.isEmpty ? null : _endTrip,
        icon: const Icon(Icons.flag),
        label: const Text('End Trip'),
      ),
    ),
  ]);
}