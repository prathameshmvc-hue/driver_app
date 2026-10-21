import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class _Vehicle {
  const _Vehicle(this.no, this.eta, this.qty, this.reached);
  final String no, eta;
  final int qty;
  final bool reached;
}

class PickerHome extends StatelessWidget {
  const PickerHome({super.key, required this.prefs, required this.onLogout});
  final SharedPreferences prefs;
  final VoidCallback onLogout;

  // Mock data. Replace with backend data later.
  static const _vehicles = [
    _Vehicle('MH04AB1234', '09:15', 320, true),
    _Vehicle('MH43CD5678', '11:30', 180, false),
    _Vehicle('MH05EF9012', '14:00', 240, false),
  ];

  void _simulateArrival(BuildContext context) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.local_shipping, size: 48, color: Brand.primary),
        title: const Text('Vehicle arrived'),
        content: const Text(
            'MH43CD5678 is within 100 m of your darkstore.\nLoad: 180 units'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Acknowledge')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reached = _vehicles.where((v) => v.reached).length;
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Vehicles"), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _simulateArrival(context),
        icon: const Icon(Icons.notifications_active),
        label: const Text('Test arrival'),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: Brand.primary.withOpacity(0.08),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Darkstore ${prefs.getString('darkstore_id')}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Caspar ID: ${prefs.getString('caspar_id')}'),
            const SizedBox(height: 10),
            Row(children: [
              Chip(label: Text('Expected ${_vehicles.length}')),
              const SizedBox(width: 8),
              Chip(label: Text('Reached $reached')),
              const SizedBox(width: 8),
              Chip(label: Text('Coming ${_vehicles.length - reached}')),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              for (final v in _vehicles)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.local_shipping,
                        color: v.reached ? Colors.green : Brand.primary),
                    title: Text(v.no,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ETA ${v.eta} · Load ${v.qty} units'),
                    trailing: Chip(
                      label: Text(v.reached ? 'Reached' : 'Coming'),
                      backgroundColor: v.reached
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}