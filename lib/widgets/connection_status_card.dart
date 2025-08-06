import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final BluetoothDevice? connectedDevice;
  final VoidCallback onSelectDevice;
  final VoidCallback onDisconnect;

  const ConnectionStatusCard({
    super.key,
    required this.isConnected,
    required this.connectedDevice,
    required this.onSelectDevice,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              isConnected
                  ? 'Connected to ${connectedDevice?.platformName ?? "Device"}'
                  : 'Not connected',
              style: TextStyle(
                fontSize: 18,
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!isConnected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSelectDevice,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Select Bluetooth Device'),
                ),
              ),
            ] else
              ElevatedButton(
                onPressed: onDisconnect,
                child: const Text('Disconnect'),
              ),
          ],
        ),
      ),
    );
  }
}