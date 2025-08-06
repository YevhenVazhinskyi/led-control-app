import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';

class BleService {
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  BluetoothService? ledService;
  
  // LED characteristics
  BluetoothCharacteristic? led1Char;
  BluetoothCharacteristic? led2Char;
  BluetoothCharacteristic? led3Char;
  BluetoothCharacteristic? led4Char;

  // Connection state
  bool isConnected = false;
  BluetoothAdapterState bluetoothState = BluetoothAdapterState.unknown;

  Future<void> initializeBluetooth() async {
    // Listen to Bluetooth adapter state
    FlutterBluePlus.adapterState.listen((state) {
      bluetoothState = state;
    });

    // Get current state
    bluetoothState = await FlutterBluePlus.adapterState.first;
  }

  Future<List<ScanResult>> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    // Check Bluetooth state first
    if (bluetoothState != BluetoothAdapterState.on) {
      throw Exception(getBluetoothStateMessage());
    }

    List<ScanResult> scanResults = [];

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
    });

    // Wait for scan to complete
    await Future.delayed(timeout);
    await FlutterBluePlus.stopScan();

    return scanResults;
  }

  String getBluetoothStateMessage() {
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

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect(timeout: const Duration(seconds: 15));
    connectedDevice = device;
    isConnected = true;
    
    await discoverServices();
  }

  Future<void> discoverServices() async {
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

    // Look for LED service
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.ledServiceUuid.toLowerCase()) {
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

          if (charUuid == BleConstants.led1CharUuid.toLowerCase()) {
            led1Char = characteristic;
          } else if (charUuid == BleConstants.led2CharUuid.toLowerCase()) {
            led2Char = characteristic;
          } else if (charUuid == BleConstants.led3CharUuid.toLowerCase()) {
            led3Char = characteristic;
          } else if (charUuid == BleConstants.led4CharUuid.toLowerCase()) {
            led4Char = characteristic;
          }
        }
        break;
      }
    }
  }

  Future<void> controlLed(BluetoothCharacteristic? characteristic, bool state) async {
    if (characteristic == null) return;
    await characteristic.write([state ? 1 : 0]);
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      isConnected = false;
      ledService = null;
      led1Char = null;
      led2Char = null;
      led3Char = null;
      led4Char = null;
    }
  }

  String getServicesDebugInfo() {
    String debugInfo = 'Found ${services.length} services:\n\n';
    for (BluetoothService service in services) {
      debugInfo += '🔵 Service: ${service.uuid.toString()}\n';
      for (BluetoothCharacteristic char in service.characteristics) {
        debugInfo += '  📝 ${char.uuid.toString()}\n';
      }
      debugInfo += '\n';
    }
    return debugInfo;
  }

  int getFoundCharacteristicsCount() {
    int foundChars = 0;
    if (led1Char != null) foundChars++;
    if (led2Char != null) foundChars++;
    if (led3Char != null) foundChars++;
    if (led4Char != null) foundChars++;
    return foundChars;
  }
}