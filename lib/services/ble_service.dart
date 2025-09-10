import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../models/motor_device.dart';

class BleService {
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  
  // DUAL MOTOR SERVICES
  BluetoothService? motor1Service;
  BluetoothService? motor2Service;
  BluetoothService? systemService;

  // MOTOR 1 characteristics
  BluetoothCharacteristic? motor1PositionChar;
  BluetoothCharacteristic? motor1CommandChar;
  BluetoothCharacteristic? motor1StatusChar;
  BluetoothCharacteristic? motor1SpeedChar;

  // MOTOR 2 characteristics
  BluetoothCharacteristic? motor2PositionChar;
  BluetoothCharacteristic? motor2CommandChar;
  BluetoothCharacteristic? motor2StatusChar;
  BluetoothCharacteristic? motor2SpeedChar;

  // SYSTEM characteristics
  BluetoothCharacteristic? dualCommandChar;
  BluetoothCharacteristic? syncModeChar;
  BluetoothCharacteristic? systemStatusChar;

  // Legacy single motor support (backward compatibility)
  BluetoothService? get motorService => motor1Service;
  BluetoothCharacteristic? get motorPositionChar => motor1PositionChar;
  BluetoothCharacteristic? get motorCommandChar => motor1CommandChar;
  BluetoothCharacteristic? get motorStatusChar => motor1StatusChar;
  BluetoothCharacteristic? get motorSpeedChar => motor1SpeedChar;

  // Connection state
  bool isConnected = false;
  BluetoothAdapterState bluetoothState = BluetoothAdapterState.unknown;

  // DUAL MOTOR state with system status
  DualMotorStateWithSystem _dualMotorState = DualMotorStateWithSystem();
  DualMotorStateWithSystem get dualMotorState => _dualMotorState;
  
  // Legacy single motor state (backward compatibility)
  MotorState get motorState => _dualMotorState.motor1;

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
      // Filter for ESP32 devices (both old and new firmware)
      scanResults = results.where((result) {
        final deviceName = result.device.platformName;
        final advertisedName = result.advertisementData.advName;
        return deviceName.contains(BleConstants.deviceName) ||  // ESP32S3_DualMotor (new)
               advertisedName.contains(BleConstants.deviceName) ||
               deviceName.contains('ESP32S3_StepperMotor') ||    // Old single motor
               advertisedName.contains('ESP32S3_StepperMotor') ||
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

    // DUAL MOTOR SERVICE DISCOVERY
    for (BluetoothService service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();
      
      // Motor 1 Service Discovery
      if (serviceUuid == BleConstants.motor1ServiceUuid.toLowerCase()) {
        motor1Service = service;
        print('🔧 Found Motor 1 Service!');
        await _discoverMotorCharacteristics(service, MotorId.motor1);
      }
      // Motor 2 Service Discovery
      else if (serviceUuid == BleConstants.motor2ServiceUuid.toLowerCase()) {
        motor2Service = service;
        print('🔧 Found Motor 2 Service!');
        await _discoverMotorCharacteristics(service, MotorId.motor2);
      }
      // System Service Discovery
      else if (serviceUuid == BleConstants.systemServiceUuid.toLowerCase()) {
        systemService = service;
        print('🔧 Found System Service!');
        await _discoverSystemCharacteristics(service);
      }
    }

    // Read initial motor status
    if (motor1Service != null) {
      await readMotorStatus(MotorId.motor1);
    }
    if (motor2Service != null) {
      await readMotorStatus(MotorId.motor2);
    }
    if (systemService != null) {
      await readSystemStatus();
    }
  }

  Future<void> _discoverMotorCharacteristics(BluetoothService service, MotorId motorId) async {
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (motorId == MotorId.motor1) {
        if (charUuid == BleConstants.motor1PositionCharUuid.toLowerCase()) {
          motor1PositionChar = characteristic;
          print('📍 Found Motor 1 Position Char');
        } else if (charUuid == BleConstants.motor1CommandCharUuid.toLowerCase()) {
          motor1CommandChar = characteristic;
          print('🎮 Found Motor 1 Command Char');
        } else if (charUuid == BleConstants.motor1StatusCharUuid.toLowerCase()) {
          motor1StatusChar = characteristic;
          print('📊 Found Motor 1 Status Char');
        } else if (charUuid == BleConstants.motor1SpeedCharUuid.toLowerCase()) {
          motor1SpeedChar = characteristic;
          print('⚡ Found Motor 1 Speed Char');
        }
      } else if (motorId == MotorId.motor2) {
        if (charUuid == BleConstants.motor2PositionCharUuid.toLowerCase()) {
          motor2PositionChar = characteristic;
          print('📍 Found Motor 2 Position Char');
        } else if (charUuid == BleConstants.motor2CommandCharUuid.toLowerCase()) {
          motor2CommandChar = characteristic;
          print('🎮 Found Motor 2 Command Char');
        } else if (charUuid == BleConstants.motor2StatusCharUuid.toLowerCase()) {
          motor2StatusChar = characteristic;
          print('📊 Found Motor 2 Status Char');
        } else if (charUuid == BleConstants.motor2SpeedCharUuid.toLowerCase()) {
          motor2SpeedChar = characteristic;
          print('⚡ Found Motor 2 Speed Char');
        }
      }
    }

    // Subscribe to motor status notifications
    final statusChar = motorId == MotorId.motor1 ? motor1StatusChar : motor2StatusChar;
    if (statusChar != null && statusChar.properties.notify) {
      try {
        await statusChar.setNotifyValue(true);
        statusChar.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final newState = MotorState.fromStatusBytes(value);
            if (motorId == MotorId.motor1) {
              _dualMotorState = _dualMotorState.copyWith(motor1: newState);
            } else {
              _dualMotorState = _dualMotorState.copyWith(motor2: newState);
            }
            print('🔄 Motor ${motorId.name} status updated: ${newState.statusText}');
          }
        });
        print('🔔 Motor ${motorId.name} status notifications enabled');
      } catch (e) {
        print('⚠️ Could not enable motor ${motorId.name} notifications: $e');
      }
    }
  }

  Future<void> _discoverSystemCharacteristics(BluetoothService service) async {
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();

      if (charUuid == BleConstants.dualCommandCharUuid.toLowerCase()) {
        dualCommandChar = characteristic;
        print('🎮 Found Dual Command Char');
      } else if (charUuid == BleConstants.syncModeCharUuid.toLowerCase()) {
        syncModeChar = characteristic;
        print('🔄 Found Sync Mode Char');
      } else if (charUuid == BleConstants.systemStatusCharUuid.toLowerCase()) {
        systemStatusChar = characteristic;
        print('📊 Found System Status Char');
      }
    }

    // Subscribe to system status notifications
    if (systemStatusChar != null && systemStatusChar!.properties.notify) {
      try {
        await systemStatusChar!.setNotifyValue(true);
        systemStatusChar!.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final newSystemState = SystemStatus.fromBytes(value);
            _dualMotorState = _dualMotorState.copyWith(systemStatus: newSystemState);
            print('🔄 System status updated: ${newSystemState.statusText}');
          }
        });
        print('🔔 System status notifications enabled');
      } catch (e) {
        print('⚠️ Could not enable system notifications: $e');
      }
    }
  }

  // DUAL MOTOR COMMAND SENDER
  Future<void> sendMotorCommand(MotorCommand command, [MotorId? motorId]) async {
    final bytes = command.toBytes();
    print('🔧 Sending command: ${command.command} (${bytes}) to ${motorId?.name ?? "system"}');
    
    // Determine which characteristic to use
    BluetoothCharacteristic? targetChar;
    
    // Check if it's a dual command (0x10-0x18 range)
    if (command.command >= 0x10 && command.command <= 0x18) {
      targetChar = dualCommandChar;
      print('📡 Using dual command characteristic');
    } else if (motorId == MotorId.motor2) {
      targetChar = motor2CommandChar;
      print('📡 Using motor 2 characteristic');
    } else {
      // Default to motor 1
      targetChar = motor1CommandChar;
      print('📡 Using motor 1 characteristic');
    }
    
    if (targetChar != null) {
      try {
        await targetChar.write(bytes);
        print('✅ Command sent successfully');
        return;
      } catch (e) {
        print('❌ Command failed: $e');
        throw Exception('Failed to send command: $e');
      }
    }
    
    throw Exception('No suitable command characteristic found');
  }

  // Legacy method for backward compatibility
  Future<void> sendBasicMotorCommand(MotorCommand command) async {
    await sendMotorCommand(command, MotorId.motor1);
  }

  Future<MotorState> readMotorStatus([MotorId? motorId]) async {
    motorId ??= MotorId.motor1; // Default to motor 1
    
    final statusChar = motorId == MotorId.motor1 ? motor1StatusChar : motor2StatusChar;
    if (statusChar == null) {
      return _dualMotorState.getMotor(motorId);
    }

    try {
      final value = await statusChar.read();
      if (value.isNotEmpty) {
        final newState = MotorState.fromStatusBytes(value);
        if (motorId == MotorId.motor1) {
          _dualMotorState = _dualMotorState.copyWith(motor1: newState);
        } else {
          _dualMotorState = _dualMotorState.copyWith(motor2: newState);
        }
        return newState;
      }
      return _dualMotorState.getMotor(motorId);
    } catch (e) {
      print('❌ Failed to read motor ${motorId.name} status: $e');
      return _dualMotorState.getMotor(motorId);
    }
  }

  Future<SystemStatus> readSystemStatus() async {
    if (systemStatusChar == null) {
      return _dualMotorState.systemStatus;
    }

    try {
      final value = await systemStatusChar!.read();
      if (value.isNotEmpty) {
        final newSystemState = SystemStatus.fromBytes(value);
        _dualMotorState = _dualMotorState.copyWith(systemStatus: newSystemState);
        return newSystemState;
      }
      return _dualMotorState.systemStatus;
    } catch (e) {
      print('❌ Failed to read system status: $e');
      return _dualMotorState.systemStatus;
    }
  }

  // DISCONNECT METHOD WITH DUAL MOTOR CLEANUP
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      isConnected = false;
      
      // DUAL MOTOR CLEANUP
      motor1Service = null;
      motor2Service = null;
      systemService = null;
      
      motor1PositionChar = null;
      motor1CommandChar = null;
      motor1StatusChar = null;
      motor1SpeedChar = null;
      
      motor2PositionChar = null;
      motor2CommandChar = null;
      motor2StatusChar = null;
      motor2SpeedChar = null;
      
      dualCommandChar = null;
      syncModeChar = null;
      systemStatusChar = null;
      
      _dualMotorState = DualMotorStateWithSystem();
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

  // DUAL MOTOR HELPER METHODS
  int getFoundMotorCharacteristicsCount([MotorId? motorId]) {
    if (motorId == MotorId.motor2) {
      int foundChars = 0;
      if (motor2PositionChar != null) foundChars++;
      if (motor2CommandChar != null) foundChars++;
      if (motor2StatusChar != null) foundChars++;
      if (motor2SpeedChar != null) foundChars++;
      return foundChars;
    } else {
      // Motor 1 or legacy
      int foundChars = 0;
      if (motor1PositionChar != null) foundChars++;
      if (motor1CommandChar != null) foundChars++;
      if (motor1StatusChar != null) foundChars++;
      if (motor1SpeedChar != null) foundChars++;
      return foundChars;
    }
  }

  int getFoundSystemCharacteristicsCount() {
    int foundChars = 0;
    if (dualCommandChar != null) foundChars++;
    if (syncModeChar != null) foundChars++;
    if (systemStatusChar != null) foundChars++;
    return foundChars;
  }

  bool get hasMotorService => motor1Service != null; // Legacy compatibility
  bool get hasMotor1Service => motor1Service != null;
  bool get hasMotor2Service => motor2Service != null;
  bool get hasSystemService => systemService != null;
  bool get hasDualMotorSupport => hasMotor1Service && hasMotor2Service && hasSystemService;
  
  bool get canControlMotor => motor1CommandChar != null; // Legacy compatibility
  bool canControlMotor1() => motor1CommandChar != null;
  bool canControlMotor2() => motor2CommandChar != null;
  bool canControlDual() => dualCommandChar != null;
}
