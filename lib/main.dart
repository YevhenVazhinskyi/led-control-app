import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/ble_service.dart';
import 'utils/permissions_helper.dart';
import 'utils/ui_helpers.dart';
import 'widgets/device_selection_sheet.dart';
import 'widgets/connection_status_card.dart';
import 'widgets/motor_control_widget.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32-S3 Stepper Motor Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MotorControllerPage(),
    );
  }
}

class MotorControllerPage extends StatefulWidget {
  const MotorControllerPage({super.key});

  @override
  State<MotorControllerPage> createState() => _MotorControllerPageState();
}

class _MotorControllerPageState extends State<MotorControllerPage> {
  final BleService _bleService = BleService();

  // Scanning state
  bool isScanning = false;
  List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    await PermissionsHelper.requestBluetoothPermissions();
    await _bleService.initializeBluetooth();

    // Listen to Bluetooth adapter state
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bleService.bluetoothState = state;
      });
    });
  }

  Future<void> _startScan() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      final results = await _bleService.startScan();
      setState(() {
        scanResults = results;
        isScanning = false;
      });
    } catch (e) {
      setState(() {
        isScanning = false;
      });
      UiHelpers.showSnackBar(context, 'Scan failed: ${e.toString()}');
    }
  }

  void _showDeviceSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceSelectionSheet(
        bluetoothState: _bleService.bluetoothState,
        isScanning: isScanning,
        scanResults: scanResults,
        onScanPressed: _startScan,
        onDeviceSelected: _connectToDevice,
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
      setState(() {});

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Connected to ${device.platformName}!', Colors.green);
      }

      // Check service discovery results
      if (_bleService.motorService == null) {
        UiHelpers.showSnackBar(
          context,
          'Motor Service NOT found!\n\nExpected: ${_bleService.getServicesDebugInfo()}',
          Colors.orange,
        );
      } else {
        final foundChars = _bleService.getFoundMotorCharacteristicsCount();
        UiHelpers.showSnackBar(
          context,
          'Motor Service found! ✅\n\nService: ${_bleService.motorService!.uuid.toString()}\nCharacteristics: $foundChars/4 found\n\nReady to control stepper motor!',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Failed to connect: $e');
      }
    }
  }

  Future<void> _disconnect() async {
    await _bleService.disconnect();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32-S3 Stepper Motor Controller'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection section
            ConnectionStatusCard(
              isConnected: _bleService.isConnected,
              connectedDevice: _bleService.connectedDevice,
              onSelectDevice: _showDeviceSelectionSheet,
              onDisconnect: _disconnect,
            ),

            const SizedBox(height: 20),

            // Motor controls
            if (_bleService.isConnected && _bleService.hasMotorService) ...[
              const Text(
                'Stepper Motor Controls',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: MotorControlWidget(
                  bleService: _bleService,
                ),
              ),
            ] else if (_bleService.isConnected)
              const Expanded(
                child: Center(
                  child: Text('Searching for motor service...'),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('Select ESP32-S3 device to control stepper motor'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}