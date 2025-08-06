import 'package:flutter/material.dart';
import '../models/led_device.dart';
import '../utils/ui_helpers.dart';

class DeviceCard extends StatelessWidget {
  final LedDevice ledDevice;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.ledDevice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ledDevice.isEsp32 ? Colors.green : Colors.blue,
          child: Icon(
            ledDevice.isEsp32 ? Icons.memory : Icons.bluetooth,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          ledDevice.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${ledDevice.device.remoteId.str}'),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt,
                    size: 16, color: UiHelpers.getRssiColor(ledDevice.rssi)),
                const SizedBox(width: 4),
                Text(
                  '${ledDevice.rssi} dBm',
                  style: TextStyle(color: UiHelpers.getRssiColor(ledDevice.rssi)),
                ),
                const SizedBox(width: 16),
                if (ledDevice.isEsp32) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ESP32',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: ledDevice.isEsp32 ? Colors.green : null,
          ),
          child: const Text('Connect'),
        ),
        onTap: onTap,
      ),
    );
  }
}