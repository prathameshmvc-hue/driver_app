import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'trips_repo.dart';

class PickerHome extends StatefulWidget {
  const PickerHome({super.key, required this.prefs, required this.onLogout});
  final SharedPreferences prefs;
  final VoidCallback onLogout;

  @override
  State<PickerHome> createState() => _PickerHomeState();
}

class _PickerHomeState extends State<PickerHome> {
  late Future<List<Map<String, dynamic>>> _trips;

  String get _darkstore => widget.prefs.getString('darkstore_id') ?? '';

  @override
  void initState() {
    super.initState();
    _trips = fetchTrips(_darkstore);
  }

  Future<void> _reload() async {
    final f = fetchTrips(_darkstore);
    setState(() => _trips = f);
    try {
      await f;
    } catch (_) {}
  }

  // Still a demo. Real alert will come from live driver GPS (100 m) later.
  void _simulateArrival(BuildContext context) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.local_shipping, size: 48, color: Brand.primary),
        title: const Text('Vehicle arrived'),
        content: const Text('A vehicle is within 100 m of your darkstore.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Acknowledge')),
        ],
      ),
    );
  }

  static Color _bg(String status) {
    final u = status.toUpperCase();
    if (u.contains('COMPLETE')) return Colors.green.shade100;
    if (u.contains('CANCEL')) return Colors.red.shade100;
    return Colors.orange.shade100;
  }

  static String _s(Map<String, dynamic> t, String k) => (t[k] ?? '').toString();

  Widget _header(BuildContext context, List<Map<String, dynamic>>? trips) {
    final counts = <String, int>{};
    for (final t in trips ?? const <Map<String, dynamic>>[]) {
      final s = _s(t, 'status').isEmpty ? 'UNKNOWN' : _s(t, 'status');
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return Container(
      width: double.infinity,
      color: Brand.primary.withOpacity(0.08),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Darkstore $_darkstore',
            style: Theme.of(context).textTheme.titleLarge),
        Text('Caspar ID: ${widget.prefs.getString('caspar_id')}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          Chip(label: Text('Total ${trips?.length ?? 0}')),
          for (final e in counts.entries)
            Chip(label: Text('${e.key} ${e.value}')),
        ]),
      ]),
    );
  }

  Widget _body(AsyncSnapshot<List<Map<String, dynamic>>> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Could not load trips'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reload, child: const Text('Retry')),
        ]),
      );
    }
    final trips = snap.data ?? const <Map<String, dynamic>>[];
    if (trips.isEmpty) {
      return const Center(child: Text('No trips for today'));
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          for (final t in trips)
            Card(
              child: ListTile(
                isThreeLine: true,
                leading: Icon(Icons.local_shipping,
                    color: _s(t, 'status').toUpperCase().contains('COMPLETE')
                        ? Colors.green
                        : Brand.primary),
                title: Text(
                    _s(t, 'vehicleNumber').isEmpty
                        ? _s(t, 'refId')
                        : _s(t, 'vehicleNumber'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${_s(t, 'vehicleType').isEmpty ? '-' : _s(t, 'vehicleType')} · ${_s(t, 'refId')}\n'
                        '${_s(t, 'lastEvent')} ${_s(t, 'lastEventTime')}'),
                trailing: Chip(
                  label: Text(_s(t, 'status')),
                  backgroundColor: _bg(_s(t, 'status')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Vehicles"), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _simulateArrival(context),
        icon: const Icon(Icons.notifications_active),
        label: const Text('Test arrival'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _trips,
        builder: (context, snap) => Column(children: [
          _header(context, snap.data),
          Expanded(child: _body(snap)),
        ]),
      ),
    );
  }
}