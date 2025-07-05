# Step-by-Step Development Prompt for LED Control App

## Project Overview
You are developing a Flutter mobile app to control 4 LEDs via an STM32WB55 microcontroller. This is a separate project from the STM32 firmware development. Your responsibility is ONLY the Flutter application.

## Technical Stack
- **Framework**: Flutter 3.7.2+
- **Language**: Dart
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **BLE**: flutter_blue_plus
- **UI**: Material Design 3
- **Testing**: flutter_test, mockito

## Development Phases

### Phase 1: Project Setup (Week 1)

#### Step 1: Initialize Project Structure
```bash
# Create Flutter project
flutter create led_control_app
cd led_control_app

# Create folder structure
mkdir -p lib/{screens,services,models,widgets,utils,providers}
mkdir -p test/{unit,widget,integration}
mkdir -p assets/{images,icons}
```

#### Step 2: Configure Dependencies
Update `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod: ^2.4.9
  flutter_riverpod: ^2.4.9
  go_router: ^12.1.3
  flutter_blue_plus: ^1.31.8
  shared_preferences: ^2.2.2
  flutter_haptic_feedback: ^0.1.0
  permission_handler: ^11.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.7
```

#### Step 3: Create Base Architecture
Create the following files:

**lib/main.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LedControlApp(),
    ),
  );
}

class LedControlApp extends ConsumerWidget {
  const LedControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LED Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
```

**lib/utils/constants.dart**:
```dart
class AppConstants {
  // BLE Service UUIDs
  static const String serviceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String ledControlUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
  static const String ledStatusUuid = '0000FFE2-0000-1000-8000-00805F9B34FB';
  static const String connectionStatusUuid = '0000FFE3-0000-1000-8000-00805F9B34FB';
  
  // LED IDs
  static const List<int> ledIds = [1, 2, 3, 4];
  
  // Brightness levels
  static const int minBrightness = 0;
  static const int maxBrightness = 255;
}
```

#### Step 4: Create Base Models
**lib/models/led_state.dart**:
```dart
class LedState {
  final int id;
  final bool isOn;
  final int brightness;
  final DateTime lastUpdated;

  const LedState({
    required this.id,
    required this.isOn,
    required this.brightness,
    required this.lastUpdated,
  });

  LedState copyWith({
    int? id,
    bool? isOn,
    int? brightness,
    DateTime? lastUpdated,
  }) {
    return LedState(
      id: id ?? this.id,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isOn': isOn,
      'brightness': brightness,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory LedState.fromJson(Map<String, dynamic> json) {
    return LedState(
      id: json['id'] as int,
      isOn: json['isOn'] as bool,
      brightness: json['brightness'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}
```

**lib/models/ble_device.dart**:
```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDevice {
  final BluetoothDevice device;
  final String name;
  final bool isConnected;
  final int rssi;

  const BleDevice({
    required this.device,
    required this.name,
    required this.isConnected,
    required this.rssi,
  });

  bool get isStm32Device => name.contains('STM32WB55') || 
                           device.remoteId.toString().contains('STM32');
}
```

### Phase 2: BLE Integration (Week 2-3)

#### Step 5: Create BLE Service
**lib/services/ble_service.dart**:
```dart
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:riverpod/riverpod.dart';
import '../models/ble_device.dart';
import '../utils/constants.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _ledControlCharacteristic;
  BluetoothCharacteristic? _ledStatusCharacteristic;

  Future<List<BleDevice>> scanForDevices() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      List<BleDevice> devices = [];
      await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
        for (ScanResult result in results) {
          if (result.device.name.isNotEmpty) {
            devices.add(BleDevice(
              device: result.device,
              name: result.device.name,
              isConnected: false,
              rssi: result.rssi,
            ));
          }
        }
      }
      
      return devices;
    } catch (e) {
      throw Exception('Failed to scan for devices: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == AppConstants.serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == AppConstants.ledControlUuid) {
              _ledControlCharacteristic = characteristic;
            }
            if (characteristic.uuid.toString().toUpperCase() == AppConstants.ledStatusUuid) {
              _ledStatusCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  Future<void> sendLedCommand(int ledId, String action, {int? brightness}) async {
    if (_ledControlCharacteristic == null) {
      throw Exception('Not connected to device');
    }

    Map<String, dynamic> command = {
      'command': 'led_control',
      'led_id': ledId,
      'action': action,
    };

    if (brightness != null) {
      command['brightness'] = brightness;
    }

    String jsonCommand = jsonEncode(command);
    await _ledControlCharacteristic!.write(utf8.encode(jsonCommand));
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _ledControlCharacteristic = null;
      _ledStatusCharacteristic = null;
    }
  }
}

final bleServiceProvider = Provider<BleService>((ref) => BleService());
```

#### Step 6: Create LED Service
**lib/services/led_service.dart**:
```dart
import 'package:riverpod/riverpod.dart';
import '../models/led_state.dart';
import 'ble_service.dart';
import '../utils/constants.dart';

class LedService {
  final BleService _bleService;
  final Map<int, LedState> _ledStates = {};

  LedService(this._bleService) {
    _initializeLedStates();
  }

  void _initializeLedStates() {
    for (int id in AppConstants.ledIds) {
      _ledStates[id] = LedState(
        id: id,
        isOn: false,
        brightness: AppConstants.maxBrightness,
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> turnOnLed(int ledId) async {
    await _bleService.sendLedCommand(ledId, 'on');
    _updateLedState(ledId, isOn: true);
  }

  Future<void> turnOffLed(int ledId) async {
    await _bleService.sendLedCommand(ledId, 'off');
    _updateLedState(ledId, isOn: false);
  }

  Future<void> toggleLed(int ledId) async {
    final currentState = _ledStates[ledId];
    if (currentState != null) {
      if (currentState.isOn) {
        await turnOffLed(ledId);
      } else {
        await turnOnLed(ledId);
      }
    }
  }

  Future<void> setBrightness(int ledId, int brightness) async {
    brightness = brightness.clamp(AppConstants.minBrightness, AppConstants.maxBrightness);
    await _bleService.sendLedCommand(ledId, 'on', brightness: brightness);
    _updateLedState(ledId, brightness: brightness);
  }

  Future<void> turnAllOn() async {
    for (int ledId in AppConstants.ledIds) {
      await turnOnLed(ledId);
    }
  }

  Future<void> turnAllOff() async {
    for (int ledId in AppConstants.ledIds) {
      await turnOffLed(ledId);
    }
  }

  void _updateLedState(int ledId, {bool? isOn, int? brightness}) {
    final currentState = _ledStates[ledId];
    if (currentState != null) {
      _ledStates[ledId] = currentState.copyWith(
        isOn: isOn ?? currentState.isOn,
        brightness: brightness ?? currentState.brightness,
        lastUpdated: DateTime.now(),
      );
    }
  }

  LedState? getLedState(int ledId) => _ledStates[ledId];
  Map<int, LedState> getAllLedStates() => Map.from(_ledStates);
}

final ledServiceProvider = Provider<LedService>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return LedService(bleService);
});
```

### Phase 3: State Management (Week 4)

#### Step 7: Create Riverpod Providers
**lib/providers/led_providers.dart**:
```dart
import 'package:riverpod/riverpod.dart';
import '../models/led_state.dart';
import '../services/led_service.dart';

final ledStatesProvider = StateNotifierProvider<LedStatesNotifier, Map<int, LedState>>((ref) {
  final ledService = ref.watch(ledServiceProvider);
  return LedStatesNotifier(ledService);
});

class LedStatesNotifier extends StateNotifier<Map<int, LedState>> {
  final LedService _ledService;

  LedStatesNotifier(this._ledService) : super({}) {
    _initializeStates();
  }

  void _initializeStates() {
    state = _ledService.getAllLedStates();
  }

  Future<void> turnOnLed(int ledId) async {
    await _ledService.turnOnLed(ledId);
    _updateState(ledId);
  }

  Future<void> turnOffLed(int ledId) async {
    await _ledService.turnOffLed(ledId);
    _updateState(ledId);
  }

  Future<void> toggleLed(int ledId) async {
    await _ledService.toggleLed(ledId);
    _updateState(ledId);
  }

  Future<void> setBrightness(int ledId, int brightness) async {
    await _ledService.setBrightness(ledId, brightness);
    _updateState(ledId);
  }

  Future<void> turnAllOn() async {
    await _ledService.turnAllOn();
    _updateAllStates();
  }

  Future<void> turnAllOff() async {
    await _ledService.turnAllOff();
    _updateAllStates();
  }

  void _updateState(int ledId) {
    final newState = _ledService.getLedState(ledId);
    if (newState != null) {
      state = {...state, ledId: newState};
    }
  }

  void _updateAllStates() {
    state = _ledService.getAllLedStates();
  }
}

final connectionStatusProvider = StateProvider<bool>((ref) => false);
```

### Phase 4: UI Development (Week 5-6)

#### Step 8: Create Main Screens
**lib/screens/home_screen.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/led_providers.dart';
import '../widgets/led_control_widget.dart';
import '../widgets/connection_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledStates = ref.watch(ledStatesProvider);
    final isConnected = ref.watch(connectionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LED Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionWidget(isConnected: isConnected),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: ledStates.length,
              itemBuilder: (context, index) {
                final ledId = ledStates.keys.elementAt(index);
                final ledState = ledStates[ledId]!;
                return LedControlWidget(
                  ledId: ledId,
                  ledState: ledState,
                );
              },
            ),
          ),
          _buildControlButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => ref.read(ledStatesProvider.notifier).turnAllOn(),
            icon: const Icon(Icons.lightbulb),
            label: const Text('All On'),
          ),
          ElevatedButton.icon(
            onPressed: () => ref.read(ledStatesProvider.notifier).turnAllOff(),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('All Off'),
          ),
        ],
      ),
    );
  }
}
```

#### Step 9: Create LED Control Widget
**lib/widgets/led_control_widget.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import '../models/led_state.dart';
import '../providers/led_providers.dart';

class LedControlWidget extends ConsumerWidget {
  final int ledId;
  final LedState ledState;

  const LedControlWidget({
    super.key,
    required this.ledId,
    required this.ledState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _toggleLed(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ledState.isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                size: 48,
                color: ledState.isOn ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                'LED $ledId',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                ledState.isOn ? 'ON' : 'OFF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ledState.isOn ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ledState.isOn) ...[
                const SizedBox(height: 8),
                Slider(
                  value: ledState.brightness.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  onChanged: (value) => _setBrightness(context, ref, value.toInt()),
                ),
                Text('Brightness: ${ledState.brightness}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLed(BuildContext context, WidgetRef ref) {
    FlutterHapticFeedback.lightImpact();
    ref.read(ledStatesProvider.notifier).toggleLed(ledId);
  }

  void _setBrightness(BuildContext context, WidgetRef ref, int brightness) {
    ref.read(ledStatesProvider.notifier).setBrightness(ledId, brightness);
  }
}
```

#### Step 10: Create Connection Widget
**lib/widgets/connection_widget.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/led_providers.dart';

class ConnectionWidget extends ConsumerWidget {
  final bool isConnected;

  const ConnectionWidget({
    super.key,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Connected to STM32WB55' : 'Disconnected',
            style: TextStyle(
              color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (!isConnected)
            ElevatedButton(
              onPressed: () => _connectToDevice(context, ref),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }

  void _connectToDevice(BuildContext context, WidgetRef ref) {
    // TODO: Implement connection logic
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Connect to Device'),
        content: Text('This will open device selection dialog'),
      ),
    );
  }
}
```

### Phase 5: Testing (Week 7-8)

#### Step 11: Create Unit Tests
**test/unit/led_service_test.dart**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:led_control_app/services/led_service.dart';
import 'package:led_control_app/services/ble_service.dart';
import 'led_service_test.mocks.dart';

@GenerateMocks([BleService])
void main() {
  group('LedService', () {
    late MockBleService mockBleService;
    late LedService ledService;

    setUp(() {
      mockBleService = MockBleService();
      ledService = LedService(mockBleService);
    });

    test('should turn on LED', () async {
      // Arrange
      when(mockBleService.sendLedCommand(1, 'on')).thenAnswer((_) async {});

      // Act
      await ledService.turnOnLed(1);

      // Assert
      verify(mockBleService.sendLedCommand(1, 'on')).called(1);
      expect(ledService.getLedState(1)?.isOn, true);
    });

    test('should turn off LED', () async {
      // Arrange
      when(mockBleService.sendLedCommand(1, 'off')).thenAnswer((_) async {});

      // Act
      await ledService.turnOffLed(1);

      // Assert
      verify(mockBleService.sendLedCommand(1, 'off')).called(1);
      expect(ledService.getLedState(1)?.isOn, false);
    });
  });
}
```

#### Step 12: Create Widget Tests
**test/widget/led_control_widget_test.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:led_control_app/widgets/led_control_widget.dart';
import 'package:led_control_app/models/led_state.dart';

void main() {
  group('LedControlWidget', () {
    testWidgets('should display LED state correctly', (WidgetTester tester) async {
      final ledState = LedState(
        id: 1,
        isOn: true,
        brightness: 128,
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LedControlWidget(
                ledId: 1,
                ledState: ledState,
              ),
            ),
          ),
        ),
      );

      expect(find.text('LED 1'), findsOneWidget);
      expect(find.text('ON'), findsOneWidget);
      expect(find.text('Brightness: 128'), findsOneWidget);
    });

    testWidgets('should toggle LED when tapped', (WidgetTester tester) async {
      final ledState = LedState(
        id: 1,
        isOn: false,
        brightness: 255,
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LedControlWidget(
                ledId: 1,
                ledState: ledState,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Note: In a real test, you would verify the state change through providers
    });
  });
}
```

### Phase 6: Final Integration (Week 9-10)

#### Step 13: Create Settings Screen
**lib/screens/settings_screen.dart**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Bluetooth Settings'),
            subtitle: const Text('Configure BLE connection'),
            onTap: () {
              // TODO: Implement Bluetooth settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Default Brightness'),
            subtitle: const Text('Set default LED brightness'),
            onTap: () {
              // TODO: Implement brightness settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('App version and information'),
            onTap: () {
              // TODO: Show about dialog
            },
          ),
        ],
      ),
    );
  }
}
```

#### Step 14: Add Permissions
**android/app/src/main/AndroidManifest.xml**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Bluetooth permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- ... rest of manifest ... -->
</manifest>
```

**ios/Runner/Info.plist**:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to LED controller</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to LED controller</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location to scan for Bluetooth devices</string>
```

#### Step 15: Final Integration Steps

1. **Test with Mock Device**:
   - Create a mock STM32WB55 that responds to BLE commands
   - Test all LED control functions
   - Verify error handling

2. **Performance Optimization**:
   - Profile app performance
   - Optimize BLE communication
   - Reduce app size

3. **Final Testing**:
   - Test on real devices (Android/iOS)
   - Test with actual STM32WB55 hardware
   - User acceptance testing

4. **Deployment Preparation**:
   - Create app icons
   - Configure app signing
   - Prepare store listings
   - Create user documentation

## Success Criteria

- [ ] App connects successfully to STM32WB55
- [ ] All 4 LEDs can be controlled individually
- [ ] Brightness control works for each LED
- [ ] Group operations (all on/off) work
- [ ] App handles connection errors gracefully
- [ ] UI is responsive and intuitive
- [ ] App works on both Android and iOS
- [ ] All tests pass
- [ ] App is ready for store deployment

## Risk Mitigation

1. **BLE Compatibility**: Test with multiple BLE devices
2. **Platform Differences**: Test on various Android/iOS versions
3. **Hardware Integration**: Coordinate closely with STM32 team
4. **Performance**: Monitor app performance on low-end devices
5. **User Experience**: Conduct usability testing

## Next Steps After MVP

1. Add advanced features (schedules, patterns)
2. Implement user accounts and cloud sync
3. Add analytics and crash reporting
4. Create web dashboard
5. Expand to support multiple devices 