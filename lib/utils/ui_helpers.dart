import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class UiHelpers {
  static Color getStatusColor(BluetoothAdapterState bluetoothState) {
    switch (bluetoothState) {
      case BluetoothAdapterState.on:
        return Colors.green;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.unavailable:
        return Colors.red;
      case BluetoothAdapterState.unauthorized:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static IconData getStatusIcon(BluetoothAdapterState bluetoothState) {
    switch (bluetoothState) {
      case BluetoothAdapterState.on:
        return Icons.bluetooth;
      default:
        return Icons.bluetooth_disabled;
    }
  }

  static Color getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.orange;
    return Colors.red;
  }

  static void showSnackBar(BuildContext context, String message, [Color? backgroundColor]) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 8), // Longer duration for debugging
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'CLOSE',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          textColor: Colors.white,
        ),
      ),
    );
  }
}