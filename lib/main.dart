import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  BluetoothService? ledService;

  // LED characteristics
  BluetoothCharacteristic? led1Char;
  BluetoothCharacteristic? led2Char;
  BluetoothCharacteristic? led3Char;
  BluetoothCharacteristic? led4Char;

  // LED states
  bool led1State = false;
  bool led2State = false;
  bool led3State = false;
  bool led4State = false;

  // Scanning state
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> scanResults = [];
  BluetoothAdapterState bluetoothState = BluetoothAdapterState.unknown;

  // UUIDs (Real ESP32 format from your device)
  static const String ledServiceUuid = 'efcdab90-7856-3412-efcd-ab9078563412';
  static const String led1CharUuid = '12345678-90ab-cdef-1234-567890abcd01';
  static const String led2CharUuid = '12345678-90ab-cdef-1234-567890abcd02';
  static const String led3CharUuid = '12345678-90ab-cdef-1234-567890abcd03';
  static const String led4CharUuid = '12345678-90ab-cdef-1234-567890abcd04';

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    await _requestPermissions();

    // Listen to Bluetooth adapter state
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        bluetoothState = state;
      });
    });

    // Get current state
    bluetoothState = await FlutterBluePlus.adapterState.first;
    setState(() {});
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  Future<void> _startScan() async {
    // Check Bluetooth state first
    if (bluetoothState != BluetoothAdapterState.on) {
      _showSnackBar(_getBluetoothStateMessage());
      return;
    }

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
      });

      Future.delayed(const Duration(seconds: 15), () {
        FlutterBluePlus.stopScan();
        setState(() {
          isScanning = false;
        });
      });
    } catch (e) {
      setState(() {
        isScanning = false;
      });
      _showSnackBar('Scan failed: ${e.toString()}');
    }
  }

  String _getBluetoothStateMessage() {
    switch (bluetoothState) {
      case BluetoothAdapterState.off:
        return 'Bluetooth is OFF. Please enable Bluetooth to scan for devices.';
      case BluetoothAdapterState.unavailable:
        return 'Simulator Mode: Bluetooth not supported. Use physical device for BLE scanning.';
      case BluetoothAdapterState.unauthorized:
        return 'Bluetooth unauthorized. Please grant permissions.';
      case BluetoothAdapterState.on:
        return 'Bluetooth is ready for scanning';
      default:
        return 'Bluetooth state: ${bluetoothState.name}';
    }
  }

  void _showDeviceSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor()),
                ),
                child: Row(
                  children: [
                    Icon(_getStatusIcon(), color: _getStatusColor()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getBluetoothStateMessage(),
                        style: TextStyle(
                            color: _getStatusColor(),
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
                    onPressed: isScanning ? null : _startScan,
                    icon: isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label:
                        Text(isScanning ? 'Scanning...' : 'Scan All Devices'),
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
      ),
    );
  }

  Color _getStatusColor() {
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

  IconData _getStatusIcon() {
    switch (bluetoothState) {
      case BluetoothAdapterState.on:
        return Icons.bluetooth;
      default:
        return Icons.bluetooth_disabled;
    }
  }

  Widget _buildDeviceList(ScrollController scrollController) {
    if (scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching for devices...' : 'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              isScanning
                  ? 'Please wait while we search for nearby devices'
                  : bluetoothState == BluetoothAdapterState.unavailable
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
      itemCount: scanResults.length,
      itemBuilder: (context, index) {
        final result = scanResults[index];
        return _buildDeviceCard(result);
      },
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : result.advertisementData.localName.isNotEmpty
            ? result.advertisementData.localName
            : 'Unknown Device';

    final isEsp32 = deviceName.toLowerCase().contains('esp32') ||
        deviceName.toLowerCase().contains('nimble');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEsp32 ? Colors.green : Colors.blue,
          child: Icon(
            isEsp32 ? Icons.memory : Icons.bluetooth,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.remoteId.str}'),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt,
                    size: 16, color: _getRssiColor(result.rssi)),
                const SizedBox(width: 4),
                Text(
                  '${result.rssi} dBm',
                  style: TextStyle(color: _getRssiColor(result.rssi)),
                ),
                const SizedBox(width: 16),
                if (isEsp32) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          onPressed: () {
            Navigator.pop(context);
            _connectToDevice(device);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isEsp32 ? Colors.green : null,
          ),
          child: const Text('Connect'),
        ),
        onTap: () {
          Navigator.pop(context);
          _connectToDevice(device);
        },
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      setState(() {
        connectedDevice = device;
        isConnected = true;
      });

      _discoverServices();

      if (mounted) {
        _showSnackBar('Connected to ${device.platformName}!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to connect: $e');
      }
    }
  }

  Future<void> _discoverServices() async {
    if (connectedDevice == null) return;

    services = await connectedDevice!.discoverServices();

    // DEBUG: Print all discovered services
    print('🔍 Discovered ${services.length} services:');
    for (BluetoothService service in services) {
      print('📋 Service: ${service.uuid.toString()}');
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        print('  📝 Characteristic: ${characteristic.uuid.toString()}');
      }
    }

    // Show user what services were found with their characteristics
    String debugInfo = 'Found ${services.length} services:\n\n';
    for (BluetoothService service in services) {
      debugInfo += '🔵 Service: ${service.uuid.toString()}\n';
      for (BluetoothCharacteristic char in service.characteristics) {
        debugInfo += '  📝 ${char.uuid.toString()}\n';
      }
      debugInfo += '\n';
    }
    _showSnackBar('Services & Characteristics:\n$debugInfo', Colors.blue);

    // Look for LED service
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() ==
          ledServiceUuid.toLowerCase()) {
        ledService = service;

        // Assign characteristics to LEDs (use available characteristics)
        final characteristics = service.characteristics;
        if (characteristics.length >= 1) led1Char = characteristics[0];
        if (characteristics.length >= 2) led2Char = characteristics[1];
        if (characteristics.length >= 3) led3Char = characteristics[2];
        if (characteristics.length >= 4) led4Char = characteristics[3];

        // Also check for specific UUIDs (fallback)
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toLowerCase();

          if (charUuid == led1CharUuid.toLowerCase()) {
            led1Char = characteristic;
          } else if (charUuid == led2CharUuid.toLowerCase()) {
            led2Char = characteristic;
          } else if (charUuid == led3CharUuid.toLowerCase()) {
            led3Char = characteristic;
          } else if (charUuid == led4CharUuid.toLowerCase()) {
            led4Char = characteristic;
          }
        }
        break;
      }
    }

    // If LED service not found, show what we expected vs found
    if (ledService == null) {
      _showSnackBar(
        'LED Service NOT found!\n\nExpected: $ledServiceUuid\n\nActual services:\n$debugInfo',
        Colors.orange,
      );
    } else {
      int foundChars = 0;
      if (led1Char != null) foundChars++;
      if (led2Char != null) foundChars++;
      if (led3Char != null) foundChars++;
      if (led4Char != null) foundChars++;

      _showSnackBar(
        'LED Service found! ✅\n\nService: ${ledService!.uuid.toString()}\nCharacteristics: $foundChars/4 found\n\nReady to control LEDs!',
        Colors.green,
      );
    }

    setState(() {});
  }

  Future<void> _controlLed(BluetoothCharacteristic? characteristic, bool state,
      int ledNumber) async {
    if (characteristic == null) return;

    try {
      await characteristic.write([state ? 1 : 0]);

      setState(() {
        switch (ledNumber) {
          case 1:
            led1State = state;
            break;
          case 2:
            led2State = state;
            break;
          case 3:
            led3State = state;
            break;
          case 4:
            led4State = state;
            break;
        }
      });

      if (mounted) {
        _showSnackBar('LED $ledNumber turned ${state ? "ON" : "OFF"}',
            state ? Colors.green : Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to control LED: $e');
      }
    }
  }

  void _showSnackBar(String message, [Color? backgroundColor]) {
    if (!mounted) return;
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

  Future<void> _disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      setState(() {
        connectedDevice = null;
        isConnected = false;
        ledService = null;
        led1Char = null;
        led2Char = null;
        led3Char = null;
        led4Char = null;
      });
    }
  }

  Widget _buildLedControl(String ledName, bool state,
      BluetoothCharacteristic? char, int ledNumber) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              ledName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state ? Colors.red : Colors.grey,
                boxShadow: state
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          spreadRadius: 2,
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Switch(
              value: state,
              onChanged: (bool value) {
                _controlLed(char, value, ledNumber);
              },
            ),
          ],
        ),
      ),
    );
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
            Card(
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
                          onPressed: _showDeviceSelectionSheet,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Select Bluetooth Device'),
                        ),
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: _disconnect,
                        child: const Text('Disconnect'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // LED controls
            if (isConnected && ledService != null) ...[
              const Text(
                'LED Controls',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  children: [
                    _buildLedControl('LED 1', led1State, led1Char, 1),
                    _buildLedControl('LED 2', led2State, led2Char, 2),
                    _buildLedControl('LED 3', led3State, led3Char, 3),
                    _buildLedControl('LED 4', led4State, led4Char, 4),
                  ],
                ),
              ),
            ] else if (isConnected)
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
