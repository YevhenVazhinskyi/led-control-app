import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../models/motor_device.dart';

class BleService {
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  
  // MOTOR SERVICE
  BluetoothService? motorService;

  // MOTOR characteristics
  BluetoothCharacteristic? motorPositionChar;
  BluetoothCharacteristic? motorCommandChar;
  BluetoothCharacteristic? motorStatusChar;
  BluetoothCharacteristic? motorSpeedChar;

  // Connection state (EXISTING - DO NOT TOUCH)
  bool isConnected = false;
  BluetoothAdapterState bluetoothState = BluetoothAdapterState.unknown;

  // MOTOR state (NEW)
  MotorState _motorState = MotorState();
  MotorState get motorState => _motorState;

  // EXISTING METHODS - DO NOT TOUCH
  Future<void> initializeBluetooth() async {
    // Listen to Bluetooth adapter state
    FlutterBluePlus.adapterState.listen((state) {
      bluetoothState = state;
    });

    // Get current state
    bluetoothState = await FlutterBluePlus.adapterState.first;
  }

  // UPDATED SCAN METHOD - Now looks for ESP32S3_StepperMotor
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
      // Filter for ESP32S3_StepperMotor devices
      scanResults = results.where((result) {
        final deviceName = result.device.platformName;
        final advertisedName = result.advertisementData.advName;
        return deviceName.contains(BleConstants.deviceName) || 
               advertisedName.contains(BleConstants.deviceName) ||
               deviceName.contains('ESP32') ||
               advertisedName.contains('ESP32');
      }).toList();
    });

    // Wait for scan to complete
    await Future.delayed(timeout);
    await FlutterBluePlus.stopScan();

    print('🔍 Found ${scanResults.length} ESP32 devices');
    for (var result in scanResults) {
      print('📱 Device: ${result.device.platformName} (${result.advertisementData.advName})');
    }

    return scanResults;
  }

  // EXISTING METHOD - DO NOT TOUCH
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

  // EXISTING METHOD - DO NOT TOUCH
  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect(timeout: const Duration(seconds: 15));
    connectedDevice = device;
    isConnected = true;
    
    await discoverServices();
  }

  // EXTENDED METHOD - ADD MOTOR DISCOVERY
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

    // MOTOR SERVICE DISCOVERY
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.motorServiceUuid.toLowerCase()) {
        motorService = service;
        print('🔧 Found Motor Service!');

        // Find motor characteristics
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toLowerCase();

          if (charUuid == BleConstants.motorPositionCharUuid.toLowerCase()) {
            motorPositionChar = characteristic;
            print('📍 Found Motor Position Char');
          } else if (charUuid == BleConstants.motorCommandCharUuid.toLowerCase()) {
            motorCommandChar = characteristic;
            print('🎮 Found Motor Command Char');
          } else if (charUuid == BleConstants.motorStatusCharUuid.toLowerCase()) {
            motorStatusChar = characteristic;
            print('📊 Found Motor Status Char');
          } else if (charUuid == BleConstants.motorSpeedCharUuid.toLowerCase()) {
            motorSpeedChar = characteristic;
            print('⚡ Found Motor Speed Char');
          }
        }

        // Subscribe to motor notifications if available
        try {
          if (motorStatusChar != null && motorStatusChar!.properties.notify) {
            await motorStatusChar!.setNotifyValue(true);
            motorStatusChar!.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                _motorState = MotorState.fromStatusBytes(value);
                print('🔄 Motor status updated: ${_motorState.statusText}');
              }
            });
            print('🔔 Motor status notifications enabled');
          }
        } catch (e) {
          print('⚠️ Could not enable motor notifications: $e');
        }
        
        break;
      }
    }

    // Read initial motor status
    if (motorService != null) {
      await readMotorStatus();
    }
  }


  // BASIC MOTOR COMMAND SENDER - TRY ALL AVAILABLE CHARACTERISTICS
  Future<void> sendBasicMotorCommand(MotorCommand command) async {
    final bytes = command.toBytes();
    print('🔧 Trying to send motor command: ${command.command} (${bytes}) to ESP32');
    
    // Try motor command characteristic first
    if (motorCommandChar != null) {
      try {
        await motorCommandChar!.write(bytes);
        print('✅ Motor command sent via motor characteristic');
        return;
      } catch (e) {
        print('❌ Motor characteristic failed: $e');
      }
    }
    
    // Try any available characteristic that can write
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          try {
            await char.write(bytes);
            print('✅ Command sent via ${service.uuid}/${char.uuid}');
            return;
          } catch (e) {
            print('❌ Failed via ${char.uuid}: $e');
          }
        }
      }
    }
    
    throw Exception('No writable characteristic found - check ESP32 connection');
  }

  Future<MotorState> readMotorStatus() async {
    if (motorStatusChar == null) {
      return _motorState;
    }

    try {
      final value = await motorStatusChar!.read();
      if (value.isNotEmpty) {
        _motorState = MotorState.fromStatusBytes(value);
      }
      return _motorState;
    } catch (e) {
      print('❌ Failed to read motor status: $e');
      return _motorState;
    }
  }

  // REMOVED CONVENIENCE METHODS - USE sendBasicMotorCommand DIRECTLY

  // DISCONNECT METHOD WITH MOTOR CLEANUP
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      isConnected = false;
      // MOTOR CLEANUP
      motorService = null;
      motorPositionChar = null;
      motorCommandChar = null;
      motorStatusChar = null;
      motorSpeedChar = null;
      _motorState = MotorState();
    }
  }

  // EXISTING METHOD - DO NOT TOUCH
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


  // MOTOR HELPER METHODS
  int getFoundMotorCharacteristicsCount() {
    int foundChars = 0;
    if (motorPositionChar != null) foundChars++;
    if (motorCommandChar != null) foundChars++;
    if (motorStatusChar != null) foundChars++;
    if (motorSpeedChar != null) foundChars++;
    return foundChars;
  }

  bool get hasMotorService => motorService != null;
  bool get canControlMotor => motorCommandChar != null;
}
