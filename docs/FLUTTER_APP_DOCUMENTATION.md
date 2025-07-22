# Flutter ESP32 LED Controller - Complete Documentation

This document contains everything you need to recreate the Flutter app for controlling ESP32 LEDs via BLE in a new workspace.

## Project Overview

Flutter app that connects to ESP32 via Bluetooth Low Energy (BLE) to control 4 individual LEDs with on/off switches and visual feedback.

## Dependencies (pubspec.yaml)

```yaml
name: flutter_led_controller
description: Flutter app to control ESP32 LEDs via BLE
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.32.12
  permission_handler: ^11.3.1
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
```

## BLE Communication Details

### ESP32 Device Information
- **Device Name**: `nimble-bleprph`
- **Service UUID**: `12345678-90ab-cdef-1234-567890abcdef`

### LED Characteristics
- **LED 1 UUID**: `12345678-90ab-cdef-1234-567890abcd01`
- **LED 2 UUID**: `12345678-90ab-cdef-1234-567890abcd02`
- **LED 3 UUID**: `12345678-90ab-cdef-1234-567890abcd03`
- **LED 4 UUID**: `12345678-90ab-cdef-1234-567890abcd04`

### Communication Protocol
- **Write `[1]`**: Turn LED ON
- **Write `[0]`**: Turn LED OFF
- **Read**: Get current LED state (0 or 1)

### ESP32 GPIO Mapping
- LED 1 → GPIO 2
- LED 2 → GPIO 4
- LED 3 → GPIO 5
- LED 4 → GPIO 18

## Platform Permissions

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- BLE Permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <uses-feature 
        android:name="android.hardware.bluetooth_le" 
        android:required="true"/>
    
    <application
        android:label="ESP32 LED Controller"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### iOS (ios/Runner/Info.plist)
Add these keys to the `<dict>` section:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to ESP32 and control LEDs</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to ESP32 and control LEDs</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to scan for Bluetooth devices</string>
```

## Complete Flutter Code (lib/main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
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
  
  bool isScanning = false;
  bool isConnected = false;
  List<BluetoothDevice> devicesList = [];
  
  // UUIDs (convert from ESP32 format to Dart format)
  static const String ledServiceUuid = "12345678-90ab-cdef-1234-567890abcdef";
  static const String led1CharUuid = "12345678-90ab-cdef-1234-567890abcd01";
  static const String led2CharUuid = "12345678-90ab-cdef-1234-567890abcd02";
  static const String led3CharUuid = "12345678-90ab-cdef-1234-567890abcd03";
  static const String led4CharUuid = "12345678-90ab-cdef-1234-567890abcd04";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  Future<void> _startScan() async {
    setState(() {
      isScanning = true;
      devicesList.clear();
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name.isNotEmpty && 
            result.device.name.contains('nimble-bleprph')) {
          if (!devicesList.contains(result.device)) {
            setState(() {
              devicesList.add(result.device);
            });
          }
        }
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      FlutterBluePlus.stopScan();
      setState(() {
        isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
        isConnected = true;
      });
      
      _discoverServices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to ESP32!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> _discoverServices() async {
    if (connectedDevice == null) return;
    
    services = await connectedDevice!.discoverServices();
    
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == ledServiceUuid.toLowerCase()) {
        ledService = service;
        
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();
          
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
    
    setState(() {});
  }

  Future<void> _controlLed(BluetoothCharacteristic? characteristic, bool state, int ledNumber) async {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LED $ledNumber turned ${state ? "ON" : "OFF"}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to control LED: $e')),
      );
    }
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

  Widget _buildLedControl(String ledName, bool state, BluetoothCharacteristic? char, int ledNumber) {
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
                          color: Colors.red.withOpacity(0.5),
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
                      isConnected ? 'Connected to ESP32' : 'Not connected',
                      style: TextStyle(
                        fontSize: 18,
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isConnected) ...[
                      ElevatedButton(
                        onPressed: isScanning ? null : _startScan,
                        child: Text(isScanning ? 'Scanning...' : 'Scan for ESP32'),
                      ),
                      const SizedBox(height: 16),
                      if (devicesList.isNotEmpty) ...[
                        const Text('Found devices:'),
                        ...devicesList.map((device) => ListTile(
                              title: Text(device.name),
                              subtitle: Text(device.id.id),
                              trailing: ElevatedButton(
                                onPressed: () => _connectToDevice(device),
                                child: const Text('Connect'),
                              ),
                            )),
                      ],
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
                  child: Text('Connect to ESP32 to control LEDs'),
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
```

## Setup Steps for New Workspace

1. **Create new Flutter project:**
   ```bash
   flutter create flutter_led_controller
   cd flutter_led_controller
   ```

2. **Replace `pubspec.yaml`** with the dependencies above

3. **Replace `lib/main.dart`** with the complete Flutter code above

4. **Update Android permissions** in `android/app/src/main/AndroidManifest.xml`

5. **Update iOS permissions** in `ios/Runner/Info.plist`

6. **Install dependencies:**
   ```bash
   flutter pub get
   ```

7. **Run the app:**
   ```bash
   flutter run
   ```

## Key Features

### BLE Connection Flow
1. **Scan** → Find devices named "nimble-bleprph"
2. **Connect** → Establish BLE connection
3. **Discover Services** → Find LED service UUID
4. **Map Characteristics** → Identify LED1-4 characteristics
5. **Control** → Write 0/1 to toggle LEDs

### UI Components
- **Connection Card**: Shows status and scan/connect buttons
- **LED Grid**: 2x2 grid of LED controls
- **LED Controls**: Each has name, visual indicator, and switch
- **Visual Feedback**: LEDs glow red when ON, grey when OFF
- **Status Messages**: SnackBar notifications for all actions

### Error Handling
- Connection failures with retry capability
- Permission requests with proper handling
- BLE communication error messages
- Device disconnection handling

## Troubleshooting

### Common Issues:
1. **Permissions denied**: Ensure all BLE permissions are granted
2. **Can't find device**: Check ESP32 is running and advertising
3. **Connection timeout**: Try restarting Bluetooth or device
4. **Service not found**: Verify ESP32 is running the correct firmware

### Debug Tips:
- Check device logs for BLE events
- Verify UUIDs match between ESP32 and Flutter
- Test on different devices if issues persist
- Ensure location services are enabled (required for BLE scan)

This documentation contains everything needed to recreate the Flutter LED controller app in any workspace! 