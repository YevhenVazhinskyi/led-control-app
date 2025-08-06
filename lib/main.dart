import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/ble_service.dart';
import 'models/led_device.dart';
import 'utils/permissions_helper.dart';
import 'utils/ui_helpers.dart';
import 'widgets/device_selection_sheet.dart';
import 'widgets/connection_status_card.dart';
import 'widgets/led_control_widget.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 LED Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LedControllerPage(),
    );
  }
}

class LedControllerPage extends StatefulWidget {
  const LedControllerPage({super.key});

  @override
  State<LedControllerPage> createState() => _LedControllerPageState();
}

class _LedControllerPageState extends State<LedControllerPage> {
  final BleService _bleService = BleService();
  final LedState _ledState = LedState();

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
      if (_bleService.ledService == null) {
        UiHelpers.showSnackBar(
          context,
          'LED Service NOT found!\n\nExpected: ${_bleService.getServicesDebugInfo()}',
          Colors.orange,
        );
      } else {
        final foundChars = _bleService.getFoundCharacteristicsCount();
        UiHelpers.showSnackBar(
          context,
          'LED Service found! ✅\n\nService: ${_bleService.ledService!.uuid.toString()}\nCharacteristics: $foundChars/4 found\n\nReady to control LEDs!',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Failed to connect: $e');
      }
    }
  }

  Future<void> _controlLed(BluetoothCharacteristic? characteristic, bool state,
      int ledNumber) async {
    try {
      await _bleService.controlLed(characteristic, state);

      setState(() {
        _ledState.updateLedState(ledNumber, state);
      });

      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'LED $ledNumber turned ${state ? "ON" : "OFF"}',
          state ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Failed to control LED: $e');
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
        title: const Text('ESP32 LED Controller'),
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

            // LED controls
            if (_bleService.isConnected && _bleService.ledService != null) ...[
              const Text(
                'LED Controls',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  children: [
                    LedControlWidget(
                      ledName: 'LED 1',
                      state: _ledState.led1State,
                      characteristic: _bleService.led1Char,
                      ledNumber: 1,
                      onLedToggle: _controlLed,
                    ),
                    LedControlWidget(
                      ledName: 'LED 2',
                      state: _ledState.led2State,
                      characteristic: _bleService.led2Char,
                      ledNumber: 2,
                      onLedToggle: _controlLed,
                    ),
                    LedControlWidget(
                      ledName: 'LED 3',
                      state: _ledState.led3State,
                      characteristic: _bleService.led3Char,
                      ledNumber: 3,
                      onLedToggle: _controlLed,
                    ),
                    LedControlWidget(
                      ledName: 'LED 4',
                      state: _ledState.led4State,
                      characteristic: _bleService.led4Char,
                      ledNumber: 4,
                      onLedToggle: _controlLed,
                    ),
                  ],
                ),
              ),
            ] else if (_bleService.isConnected)
              const Expanded(
                child: Center(
                  child: Text('Searching for LED service...'),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('Select a Bluetooth device to control LEDs'),
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
