import 'package:flutter/material.dart';

class Brand {
  // TODO: replace with the official Flipkart Minutes colours
  static const primary = Color(0xFF2874F0);
  static const accent = Color(0xFFFFE500);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.primary, primary: Brand.primary),
  appBarTheme: const AppBarTheme(
      backgroundColor: Brand.primary, foregroundColor: Colors.white),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  inputDecorationTheme:
  const InputDecorationTheme(border: OutlineInputBorder()),
);

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
    // TODO: add assets/logo.png and declare it in pubspec.yaml
    Image.asset('assets/logo.png',
        height: 72,
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.local_shipping, size: 64, color: Brand.primary)),
    const SizedBox(height: 8),
    Text('Minutes',
        style: Theme.of(context)
            .textTheme
            .headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: Brand.primary)),
  ]);
}