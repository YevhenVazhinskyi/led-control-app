import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/led_device.dart';
import '../utils/ui_helpers.dart';
import 'device_card.dart';

class DeviceSelectionSheet extends StatefulWidget {
  final BluetoothAdapterState bluetoothState;
  final bool isScanning;
  final List<ScanResult> scanResults;
  final VoidCallback onScanPressed;
  final Function(BluetoothDevice) onDeviceSelected;

  const DeviceSelectionSheet({
    super.key,
    required this.bluetoothState,
    required this.isScanning,
    required this.scanResults,
    required this.onScanPressed,
    required this.onDeviceSelected,
  });

  @override
  State<DeviceSelectionSheet> createState() => _DeviceSelectionSheetState();
}

class _DeviceSelectionSheetState extends State<DeviceSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Bluetooth Device',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Bluetooth Status Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UiHelpers.getStatusColor(widget.bluetoothState).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: UiHelpers.getStatusColor(widget.bluetoothState)),
              ),
              child: Row(
                children: [
                  Icon(UiHelpers.getStatusIcon(widget.bluetoothState), 
                       color: UiHelpers.getStatusColor(widget.bluetoothState)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getBluetoothStateMessage(),
                      style: TextStyle(
                          color: UiHelpers.getStatusColor(widget.bluetoothState),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Scan Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.isScanning ? null : widget.onScanPressed,
                  icon: widget.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(widget.isScanning ? 'Scanning...' : 'Scan All Devices'),
                ),
              ),
            ),

            // Device List
            Expanded(
              child: _buildDeviceList(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  String _getBluetoothStateMessage() {
    switch (widget.bluetoothState) {
      case BluetoothAdapterState.off:
        return 'Bluetooth is OFF. Please enable Bluetooth to scan for devices.';
      case BluetoothAdapterState.unavailable:
        return 'Simulator Mode: Bluetooth not supported. Use physical device for BLE scanning.';
      case BluetoothAdapterState.unauthorized:
        return 'Bluetooth unauthorized. Please grant permissions.';
      case BluetoothAdapterState.on:
        return 'Bluetooth is ready for scanning';
      default:
        return 'Bluetooth state: ${widget.bluetoothState.name}';
    }
  }

  Widget _buildDeviceList(ScrollController scrollController) {
    if (widget.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              widget.isScanning ? 'Searching for devices...' : 'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isScanning
                  ? 'Please wait while we search for nearby devices'
                  : widget.bluetoothState == BluetoothAdapterState.unavailable
                      ? 'Simulator mode - Use physical device for real Bluetooth'
                      : 'Tap "Scan All Devices" to start searching',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: widget.scanResults.length,
      itemBuilder: (context, index) {
        final result = widget.scanResults[index];
        final ledDevice = LedDevice.fromScanResult(result);
        return DeviceCard(
          ledDevice: ledDevice,
          onTap: () {
            Navigator.pop(context);
            widget.onDeviceSelected(ledDevice.device);
          },
        );
      },
    );
  }
}