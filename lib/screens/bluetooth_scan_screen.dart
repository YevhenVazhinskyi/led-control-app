/**
 * @file: bluetooth_scan_screen.dart
 * @description: Screen for scanning and displaying all available BLE devices
 * @dependencies: ble_service.dart, constants.dart, helpers.dart
 * @created: 2024-12-19
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:led_control_app/services/ble_service.dart';
import 'package:led_control_app/utils/helpers.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  final BleService _bleService = bleService;

  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _stopScan();
    super.dispose();
  }

  /// Initialize Bluetooth and check state
  Future<void> _initializeBluetooth() async {
    try {
      await _bleService.initialize();

      // Check if Bluetooth is enabled
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (mounted) {
        setState(() {
          _isBluetoothEnabled = adapterState == BluetoothAdapterState.on;
        });
      }

      // Listen to Bluetooth state changes
      FlutterBluePlus.adapterState.listen((state) {
        if (mounted) {
          setState(() {
            _isBluetoothEnabled = state == BluetoothAdapterState.on;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to initialize Bluetooth: $e');
      }
    }
  }

  /// Start scanning for BLE devices
  Future<void> _startScan() async {
    if (!_isBluetoothEnabled) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Please enable Bluetooth');
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results;
          });
        }
      });

      // Stop scanning after timeout
      Future.delayed(const Duration(seconds: 10), () {
        _stopScan();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        Helpers.showSnackBar(context, 'Scan failed: $e');
      }
    }
  }

  /// Stop scanning
  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  /// Connect to selected device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Connected to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}',
          backgroundColor: Colors.green,
        );

        // Navigate back to home screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Connection failed: $e');
      }
    }
  }

  /// Get device name or ID
  String _getDeviceName(BluetoothDevice device) {
    return device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.toString();
  }

  /// Get signal strength indicator
  Widget _getSignalStrength(int rssi) {
    Color color;
    String strength;

    if (rssi >= -50) {
      color = Colors.green;
      strength = 'Excellent';
    } else if (rssi >= -60) {
      color = Colors.lightGreen;
      strength = 'Good';
    } else if (rssi >= -70) {
      color = Colors.orange;
      strength = 'Fair';
    } else {
      color = Colors.red;
      strength = 'Poor';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, color: color, size: 16),
        const SizedBox(width: 4),
        Text(strength, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  /// Build device list item
  Widget _buildDeviceItem(ScanResult result) {
    final device = result.device;
    final deviceName = _getDeviceName(device);
    final rssi = result.rssi;
    final advertisementData = result.advertisementData;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(Icons.bluetooth, color: Colors.white, size: 20),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.remoteId}'),
            if (advertisementData.manufacturerData.isNotEmpty)
              Text(
                'Manufacturer: ${advertisementData.manufacturerData.keys.first}',
              ),
            _getSignalStrength(rssi),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bluetooth),
          onPressed: () => _connectToDevice(device),
          tooltip: 'Connect to device',
        ),
        onTap: () => _connectToDevice(device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth status and scan button
          _buildStatusSection(),

          // Device list
          Expanded(child: _buildDeviceList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        tooltip: 'Scan for devices',
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

  /// Build status section
  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bluetooth status
          Row(
            children: [
              Icon(
                _isBluetoothEnabled
                    ? Icons.bluetooth
                    : Icons.bluetooth_disabled,
                color: _isBluetoothEnabled ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                _isBluetoothEnabled
                    ? 'Bluetooth Enabled'
                    : 'Bluetooth Disabled',
                style: TextStyle(
                  color: _isBluetoothEnabled ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Scan status
          Row(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.radar_outlined,
                color: _isScanning ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                _isScanning ? 'Scanning...' : 'Ready to scan',
                style: TextStyle(
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Device count
          Text(
            'Found ${_scanResults.length} device${_scanResults.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build device list
  Widget _buildDeviceList() {
    if (_scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Scanning for devices...' : 'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning
                  ? 'Please wait while we search for nearby devices'
                  : 'Tap the scan button to start searching',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _startScan,
      child: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          return _buildDeviceItem(_scanResults[index]);
        },
      ),
    );
  }
}
