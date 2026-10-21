import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'driver_home.dart';
import 'login_screen.dart';
import 'picker_home.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SharedPreferences? _p;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _p = p));
  }

  Future<void> _logout() async {
    await _p?.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return p.getString('role') == 'driver'
        ? DriverHome(prefs: p, onLogout: _logout)
        : PickerHome(prefs: p, onLogout: _logout);
  }
}