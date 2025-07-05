/**
 * @file: main.dart
 * @description: Main entry point for LED Control App
 * @dependencies: home_screen.dart, constants.dart
 * @created: 2024-12-19
 */

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/bluetooth_scan_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(const LedControlApp());
}

class LedControlApp extends StatelessWidget {
  const LedControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const BluetoothScanScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
