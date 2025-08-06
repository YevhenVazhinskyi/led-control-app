import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LedDevice {
  final BluetoothDevice device;
  final String displayName;
  final int rssi;
  final bool isEsp32;

  LedDevice({
    required this.device,
    required this.displayName,
    required this.rssi,
    required this.isEsp32,
  });

  factory LedDevice.fromScanResult(ScanResult result) {
    final device = result.device;
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : result.advertisementData.localName.isNotEmpty
            ? result.advertisementData.localName
            : 'Unknown Device';

    final isEsp32 = deviceName.toLowerCase().contains('esp32') ||
        deviceName.toLowerCase().contains('nimble');

    return LedDevice(
      device: device,
      displayName: deviceName,
      rssi: result.rssi,
      isEsp32: isEsp32,
    );
  }
}

class LedState {
  bool led1State;
  bool led2State;
  bool led3State;
  bool led4State;

  LedState({
    this.led1State = false,
    this.led2State = false,
    this.led3State = false,
    this.led4State = false,
  });

  void updateLedState(int ledNumber, bool state) {
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
  }

  bool getLedState(int ledNumber) {
    switch (ledNumber) {
      case 1:
        return led1State;
      case 2:
        return led2State;
      case 3:
        return led3State;
      case 4:
        return led4State;
      default:
        return false;
    }
  }
}