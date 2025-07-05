/**
 * @file: home_screen.dart
 * @description: Main screen with 4 LED control buttons and BLE connection
 * @dependencies: ble_service.dart, constants.dart, helpers.dart
 * @created: 2024-12-19
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import '../services/ble_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = bleService;

  bool _isConnected = false;
  bool _isScanning = false;
  List<BluetoothDevice> _foundDevices = [];
  BluetoothDevice? _selectedDevice;

  // LED states (local for now)
  final Map<int, bool> _ledStates = {1: false, 2: false, 3: false, 4: false};

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  /// Initialize BLE service
  Future<void> _initializeBle() async {
    try {
      await _bleService.initialize();

      // Listen to connection status changes
      _bleService.connectionStatusStream.listen((isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
      });
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to initialize BLE: $e');
    }
  }

  /// Scan for STM32WB55 devices
  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      final devices = await _bleService.scanForDevices();
      setState(() {
        _foundDevices = devices;
        _isScanning = false;
      });

      if (devices.isEmpty) {
        Helpers.showSnackBar(context, 'No STM32WB55 devices found');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      Helpers.showSnackBar(context, 'Scan failed: $e');
    }
  }

  /// Connect to selected device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
      setState(() {
        _selectedDevice = device;
      });
      Helpers.showSnackBar(context, 'Connected to ${device.platformName}');
    } catch (e) {
      Helpers.showSnackBar(context, 'Connection failed: $e');
    }
  }

  /// Toggle LED state
  Future<void> _toggleLed(int ledId) async {
    if (!_isConnected) {
      Helpers.showSnackBar(context, 'Not connected to device');
      return;
    }

    try {
      // Haptic feedback
      HapticFeedback.lightImpact();

      // Toggle local state immediately for UI responsiveness
      setState(() {
        _ledStates[ledId] = !_ledStates[ledId]!;
      });

      // Send BLE command
      final action = _ledStates[ledId]! ? 'on' : 'off';
      await _bleService.sendLedCommand(ledId, action);

      Helpers.showSnackBar(
        context,
        'LED $ledId ${_ledStates[ledId]! ? 'ON' : 'OFF'}',
        backgroundColor: _ledStates[ledId]! ? Colors.green : Colors.red,
      );
    } catch (e) {
      // Revert local state on error
      setState(() {
        _ledStates[ledId] = !_ledStates[ledId]!;
      });
      Helpers.showSnackBar(context, 'Failed to toggle LED $ledId: $e');
    }
  }

  /// Show device selection dialog
  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select BLE Device'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  _foundDevices.isEmpty
                      ? const Center(
                        child: Text('No devices found. Try scanning first.'),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _foundDevices.length,
                        itemBuilder: (context, index) {
                          final device = _foundDevices[index];
                          final name =
                              device.platformName.isNotEmpty
                                  ? device.platformName
                                  : '(no name)';
                          return ListTile(
                            title: Text(name),
                            subtitle: Text(device.remoteId.toString()),
                            onTap: () {
                              Navigator.of(context).pop();
                              _connectToDevice(device);
                            },
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Connection status widget
          _buildConnectionWidget(),

          // LED control grid
          Expanded(child: _buildLedGrid()),

          // Control buttons
          _buildControlButtons(),
        ],
      ),
    );
  }

  /// Build connection status widget
  Widget _buildConnectionWidget() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Text(
              _isConnected
                  ? 'Connected to ${_selectedDevice?.platformName ?? 'STM32WB55'}'
                  : 'Not connected',
              style: TextStyle(
                color:
                    _isConnected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_isConnected)
            ElevatedButton(
              onPressed: _isScanning ? null : _scanForDevices,
              child:
                  _isScanning
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Scan'),
            ),
          if (!_isConnected)
            ElevatedButton(
              onPressed: () => context.go('/scan'),
              child: const Text('Scan All'),
            ),
        ],
      ),
    );
  }

  /// Build LED control grid
  Widget _buildLedGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppConstants.defaultPadding,
        mainAxisSpacing: AppConstants.defaultPadding,
        childAspectRatio: 1.2,
      ),
      itemCount: AppConstants.ledIds.length,
      itemBuilder: (context, index) {
        final ledId = AppConstants.ledIds[index];
        final isOn = _ledStates[ledId] ?? false;

        return _buildLedButton(ledId, isOn);
      },
    );
  }

  /// Build individual LED button
  Widget _buildLedButton(int ledId, bool isOn) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _toggleLed(ledId),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isOn
                      ? [Colors.amber.shade300, Colors.orange.shade400]
                      : [Colors.grey.shade200, Colors.grey.shade300],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                size: AppConstants.largeIconSize,
                color: isOn ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                'LED $ledId',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isOn ? Colors.white : Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                isOn ? 'ON' : 'OFF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOn ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _isConnected ? () => _turnAllLeds(true) : null,
            icon: const Icon(Icons.lightbulb),
            label: const Text('All ON'),
          ),
          ElevatedButton.icon(
            onPressed: _isConnected ? () => _turnAllLeds(false) : null,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('All OFF'),
          ),
          if (!_isConnected)
            ElevatedButton.icon(
              onPressed: _showDeviceSelectionDialog,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect'),
            ),
        ],
      ),
    );
  }

  /// Turn all LEDs on or off
  Future<void> _turnAllLeds(bool turnOn) async {
    if (!_isConnected) return;

    try {
      HapticFeedback.mediumImpact();

      for (int ledId in AppConstants.ledIds) {
        setState(() {
          _ledStates[ledId] = turnOn;
        });
        await _bleService.sendLedCommand(ledId, turnOn ? 'on' : 'off');
      }

      Helpers.showSnackBar(
        context,
        'All LEDs ${turnOn ? 'ON' : 'OFF'}',
        backgroundColor: turnOn ? Colors.green : Colors.red,
      );
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to control all LEDs: $e');
    }
  }
}
