/**
 * @file: ble_service.dart
 * @description: BLE service for scanning, connecting and sending LED control commands
 * @dependencies: flutter_blue_plus, constants.dart, helpers.dart
 * @created: 2024-12-19
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// BLE Service for LED Control App
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Connected device and characteristics
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _ledControlCharacteristic;
  BluetoothCharacteristic? _ledStatusCharacteristic;

  // Stream controllers for state updates
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  final StreamController<List<BluetoothDevice>> _scanResultsController =
      StreamController<List<BluetoothDevice>>.broadcast();

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<List<BluetoothDevice>> get scanResultsStream =>
      _scanResultsController.stream;

  /// Initialize BLE service
  Future<void> initialize() async {
    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not supported on this device');
      }

      // Listen to Bluetooth state changes
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          debugPrint('Bluetooth adapter is on');
        } else {
          debugPrint('Bluetooth adapter state: $state');
        }
      });
    } catch (e) {
      throw Exception('Failed to initialize BLE service: $e');
    }
  }

  /// Scan for all BLE devices
  Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      final List<BluetoothDevice> devices = [];

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: AppConstants.scanTimeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
        for (ScanResult result in results) {
          final device = result.device;
          final deviceName = device.platformName;
          // Добавляем все устройства, даже без имени
          if (!devices.any((d) => d.remoteId == device.remoteId)) {
            devices.add(device);
            debugPrint('Found BLE device: $deviceName (${device.remoteId})');
          }
        }
        // Update scan results stream
        _scanResultsController.add(List.from(devices));
      }
      return devices;
    } catch (e) {
      throw Exception('Failed to scan for devices: $e');
    }
  }

  /// Connect to STM32WB55 device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('Connecting to device: ${device.platformName}');

      // Connect to device
      await device.connect(
        timeout: AppConstants.connectionTimeout,
        autoConnect: false,
      );

      _connectedDevice = device;

      // Discover services
      final List<BluetoothService> services = await device.discoverServices();

      // Find our custom service
      for (BluetoothService service in services) {
        final serviceUuid = service.uuid.toString().toUpperCase();
        debugPrint('Found service: $serviceUuid');

        if (serviceUuid == AppConstants.serviceUuid) {
          debugPrint('Found LED control service');

          // Find characteristics
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toUpperCase();
            debugPrint('Found characteristic: $charUuid');

            if (charUuid == AppConstants.ledControlUuid) {
              _ledControlCharacteristic = characteristic;
              debugPrint('Found LED control characteristic');
            }

            if (charUuid == AppConstants.ledStatusUuid) {
              _ledStatusCharacteristic = characteristic;

              // Enable notifications
              await characteristic.setNotifyValue(true);
              characteristic.onValueReceived.listen((value) {
                _handleLedStatusUpdate(value);
              });

              debugPrint('Found LED status characteristic');
            }
          }
        }
      }

      // Update connection status
      _connectionStatusController.add(true);
      debugPrint('Successfully connected to STM32WB55');
    } catch (e) {
      _connectedDevice = null;
      _connectionStatusController.add(false);
      throw Exception('Failed to connect to device: $e');
    }
  }

  /// Send LED control command
  Future<void> sendLedCommand(
    int ledId,
    String action, {
    int? brightness,
  }) async {
    if (_ledControlCharacteristic == null) {
      throw Exception('Not connected to device');
    }

    if (!Helpers.isValidLedId(ledId)) {
      throw Exception('Invalid LED ID: $ledId');
    }

    try {
      // Create command
      final command = Helpers.createLedCommand(
        ledId,
        action,
        brightness: brightness,
      );
      final commandBytes = utf8.encode(command);

      debugPrint('Sending command: $command');

      // Send command
      await _ledControlCharacteristic!.write(commandBytes);

      debugPrint('Command sent successfully');
    } catch (e) {
      throw Exception('Failed to send LED command: $e');
    }
  }

  /// Handle LED status updates from device
  void _handleLedStatusUpdate(List<int> value) {
    try {
      final response = utf8.decode(value);
      debugPrint('Received LED status: $response');

      final parsedResponse = Helpers.parseLedResponse(response);
      if (parsedResponse != null) {
        // TODO: Update LED state in app
        debugPrint('Parsed LED status: $parsedResponse');
      }
    } catch (e) {
      debugPrint('Failed to handle LED status update: $e');
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        debugPrint('Disconnected from device');
      }
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    } finally {
      _connectedDevice = null;
      _ledControlCharacteristic = null;
      _ledStatusCharacteristic = null;
      _connectionStatusController.add(false);
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _scanResultsController.close();
  }
}

/// Global BLE service instance
final bleService = BleService();
