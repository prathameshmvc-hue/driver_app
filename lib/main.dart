import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MaterialApp(
    title: 'Minutes',
    theme: appTheme(),
    home: prefs.getString('role') != null
        ? const HomeScreen()
        : const LoginScreen(),
  ));
}