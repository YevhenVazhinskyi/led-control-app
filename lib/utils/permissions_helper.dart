import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  static Future<void> requestBluetoothPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }
}