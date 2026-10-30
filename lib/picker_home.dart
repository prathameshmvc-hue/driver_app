import 'dart:async';
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
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  // Arrival alerts. A vehicle alerts once per arrival (refId + arrivedAt).
  final Set<String> _alerted = {};
  final List<String> _pending = [];
  bool _firstLoad = true; // arrivals that already happened are not alerted
  bool _dialogOpen = false;

  String get _darkstore => widget.prefs.getString('darkstore_id') ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final l = await fetchTrips(_darkstore);
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
        _error = null;
      });
      _checkAlerts(l);
    } catch (_) {
      if (!mounted) return;
      if (!silent || _list.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Could not load trips';
        });
      }
    }
  }

  static String _s(Map<String, dynamic> t, String k) => (t[k] ?? '').toString();

  static String _name(Map<String, dynamic> t) =>
      _s(t, 'vehicleNumber').isEmpty ? _s(t, 'refId') : _s(t, 'vehicleNumber');

  static bool _arrived(Map<String, dynamic> t) {
    final live = t['live'];
    return live is Map && live['arrived'] == true;
  }

  void _checkAlerts(List<Map<String, dynamic>> trips) {
    final fresh = <String>[];
    for (final t in trips) {
      if (!_arrived(t)) continue;
      final key = '${t['refId']}|${(t['live'] as Map)['arrivedAt']}';
      if (_alerted.add(key) && !_firstLoad) fresh.add(_name(t));
    }
    _firstLoad = false;
    if (fresh.isNotEmpty) _showArrival(fresh);
  }

  Future<void> _showArrival(List<String> vehicles) async {
    if (_dialogOpen) {
      _pending.addAll(vehicles);
      return;
    }
    _dialogOpen = true;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_shipping, size: 48, color: Brand.primary),
        title: const Text('Vehicle arrived'),
        content: Text('${vehicles.join(', ')}\nwithin 100 m of your darkstore.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Acknowledge')),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || _pending.isEmpty) return;
    final p = List<String>.from(_pending);
    _pending.clear();
    _showArrival(p);
  }

  static Color _bg(String status) {
    final u = status.toUpperCase();
    if (u.contains('COMPLETE')) return Colors.green.shade100;
    if (u.contains('CANCEL')) return Colors.red.shade100;
    return Colors.orange.shade100;
  }

  String _liveText(Map<String, dynamic> t) {
    final live = t['live'];
    if (live is! Map) return '';
    return live['arrived'] == true
        ? 'Arrived (${live['distanceM']} m)'
        : '${live['distanceM']} m away';
  }

  Widget _header(BuildContext context) {
    final counts = <String, int>{};
    for (final t in _list) {
      final s = _s(t, 'status').isEmpty ? 'UNKNOWN' : _s(t, 'status');
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final arrived = _list.where(_arrived).length;
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
          Chip(label: Text('Total ${_list.length}')),
          Chip(label: Text('Arrived $arrived')),
          for (final e in counts.entries)
            Chip(label: Text('${e.key} ${e.value}')),
        ]),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    if (_list.isEmpty) {
      return const Center(child: Text('No trips for today'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          for (final t in _list)
            Card(
              child: ListTile(
                isThreeLine: true,
                leading: Icon(Icons.local_shipping,
                    color: _arrived(t) ? Colors.green : Brand.primary),
                title: Text(_name(t),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${_s(t, 'vehicleType').isEmpty ? '-' : _s(t, 'vehicleType')} · ${_s(t, 'refId')}\n'
                        '${_s(t, 'lastEvent')} ${_s(t, 'lastEventTime')}'
                        '${_liveText(t).isEmpty ? '' : '\n${_liveText(t)}'}'),
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
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load()),
        IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showArrival(['Test vehicle']),
        icon: const Icon(Icons.notifications_active),
        label: const Text('Test arrival'),
      ),
      body: Column(children: [
        _header(context),
        Expanded(child: _body()),
      ]),
    );
  }
}