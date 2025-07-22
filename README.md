# ESP32 LED Controller Flutter App

This Flutter app connects to an ESP32 microcontroller via Bluetooth Low Energy (BLE) to control 4 individual LEDs.

## ESP32 Hardware Setup

### LED Connections:
- **LED 1**: GPIO 2
- **LED 2**: GPIO 4  
- **LED 3**: GPIO 5
- **LED 4**: GPIO 18

Connect each LED with a 220Ω resistor in series between the GPIO pin and ground.

```
ESP32 GPIO -> 220Ω Resistor -> LED (+) -> LED (-) -> GND
```

## ESP32 Configuration

### Device Name
The ESP32 should advertise as **"nimble-bleprph"**

### BLE Service & Characteristics
- **Service UUID**: `12345678-90ab-cdef-1234-567890abcdef`
- **LED1 Characteristic**: `12345678-90ab-cdef-1234-567890abcd01`
- **LED2 Characteristic**: `12345678-90ab-cdef-1234-567890abcd02`
- **LED3 Characteristic**: `12345678-90ab-cdef-1234-567890abcd03`
- **LED4 Characteristic**: `12345678-90ab-cdef-1234-567890abcd04`

### Communication Protocol
Each LED is controlled by writing to its characteristic:
- **Write [1]**: Turn LED ON
- **Write [0]**: Turn LED OFF
- **Read**: Get current LED state (0 or 1)

## Flutter App Features

- Scan for ESP32 devices (looks for "nimble-bleprph")
- Connect via BLE
- Individual LED control switches with visual feedback
- Connection status display
- Clean, modern UI with glowing effect for active LEDs

## Installation & Setup

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

3. **Platform Requirements:**
   - **Android**: Supports BLE, location permissions granted
   - **iOS**: Supports BLE, Bluetooth permissions granted
   - **Minimum Flutter version**: 3.0.0

## Usage

1. **Enable Bluetooth** on your mobile device
2. **Grant permissions** when prompted (Location, Bluetooth)
3. **Tap "Scan for ESP32"** to find your device
4. **Connect** to the "nimble-bleprph" device
5. **Control LEDs** using the toggle switches

## Troubleshooting

### ESP32:
- Verify ESP32 is running and advertising as "nimble-bleprph"
- Check GPIO connections and power supply
- Ensure BLE service and characteristics are properly configured

### Flutter App:
- Enable location services (required for BLE scanning)
- Check Bluetooth permissions are granted
- Ensure device supports BLE
- Try restarting Bluetooth if connection issues persist

### Common Issues:
1. **Can't find device**: Check ESP32 is running and advertising
2. **Connection fails**: Restart both ESP32 and app
3. **LEDs don't respond**: Verify GPIO connections and ESP32 firmware
4. **Permission denied**: Grant all requested permissions in device settings

## Architecture

The app uses a single-file architecture (`lib/main.dart`) that includes:
- BLE scanning and connection management
- Individual LED characteristic handling
- Modern Material Design 3 UI
- Proper permission handling for Android/iOS
- Error handling and user feedback
