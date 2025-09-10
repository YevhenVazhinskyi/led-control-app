import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/ble_service.dart';
import 'models/motor_device.dart';
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
      if (_bleService.hasDualMotorSupport) {
        final motor1Chars = _bleService.getFoundMotorCharacteristicsCount(MotorId.motor1);
        final motor2Chars = _bleService.getFoundMotorCharacteristicsCount(MotorId.motor2);
        final systemChars = _bleService.getFoundSystemCharacteristicsCount();
        UiHelpers.showSnackBar(
          context,
          'Dual Motor System found! ✅\n\nMotor 1: $motor1Chars/4 chars\nMotor 2: $motor2Chars/4 chars\nSystem: $systemChars/3 chars\n\nReady for dual motor control!',
          Colors.green,
        );
      } else if (_bleService.hasMotor1Service) {
        final foundChars = _bleService.getFoundMotorCharacteristicsCount(MotorId.motor1);
        UiHelpers.showSnackBar(
          context,
          'Motor 1 Service found! ✅\n\nCharacteristics: $foundChars/4 found\n\nSingle motor mode ready!',
          Colors.green,
        );
      } else {
        UiHelpers.showSnackBar(
          context,
          'No Motor Services found!\n\nExpected: ${_bleService.getServicesDebugInfo()}',
          Colors.orange,
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
      body: SingleChildScrollView(
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
              MotorControlWidget(
                bleService: _bleService,
              ),
            ] else if (_bleService.isConnected)
              const SizedBox(
                height: 200,
                child: Center(
                  child: Text('Searching for motor service...'),
                ),
              )
            else
              const SizedBox(
                height: 200,
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