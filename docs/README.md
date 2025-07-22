# ESP32 LED Controller via BLE with Flutter App

This project allows you to control 4 LEDs connected to an ESP32 using a Flutter mobile app via Bluetooth Low Energy (BLE).

## Hardware Setup

### ESP32 LED Connections:
- **LED 1**: GPIO 2
- **LED 2**: GPIO 4  
- **LED 3**: GPIO 5
- **LED 4**: GPIO 18

Connect each LED with a 220Ω resistor in series between the GPIO pin and ground.

```
ESP32 GPIO -> 220Ω Resistor -> LED (+) -> LED (-) -> GND
```

## ESP32 Code (bleprph)

### Features:
- BLE peripheral with custom LED service
- 4 separate characteristics for individual LED control
- GPIO control for physical LEDs
- Based on NimBLE stack

### UUIDs:
- **Service UUID**: `12345678-90ab-cdef-1234-567890abcdef`
- **LED1 Characteristic**: `12345678-90ab-cdef-1234-567890abcd01`
- **LED2 Characteristic**: `12345678-90ab-cdef-1234-567890abcd02`
- **LED3 Characteristic**: `12345678-90ab-cdef-1234-567890abcd03`
- **LED4 Characteristic**: `12345678-90ab-cdef-1234-567890abcd04`

### Building and Flashing:
```bash
cd bleprph
idf.py build
idf.py flash monitor
```

### Device Name:
The ESP32 will advertise as **"nimble-bleprph"**

## Flutter App

### Features:
- Scans for ESP32 devices
- Connects via BLE
- Individual LED control switches
- Visual LED status indicators
- Connection status display

### Requirements:
- Flutter SDK
- Android/iOS device with BLE support
- Location permissions (required for BLE scanning)

### Running the App:
```bash
cd flutter_led_controller
flutter pub get
flutter run
```

### App Usage:
1. **Enable Bluetooth** on your mobile device
2. **Grant permissions** when prompted (Location, Bluetooth)
3. **Tap "Scan for ESP32"** to find your device
4. **Connect** to the "nimble-bleprph" device
5. **Control LEDs** using the toggle switches

## Communication Protocol

Each LED is controlled by writing to its characteristic:
- **Write 1**: Turn LED ON
- **Write 0**: Turn LED OFF
- **Read**: Get current LED state

## Troubleshooting

### ESP32:
- Check GPIO connections
- Verify BLE is advertising: `ESP_LOGI` messages in monitor
- Ensure proper power supply

### Flutter App:
- Enable location services
- Check Bluetooth permissions
- Ensure device supports BLE
- Try restarting Bluetooth

### Common Issues:
1. **Can't find device**: Check ESP32 is running and advertising
2. **Connection fails**: Restart both ESP32 and app
3. **LEDs don't respond**: Verify GPIO connections and power
4. **Permission denied**: Grant all requested permissions

## Customization

### Change GPIO Pins:
Modify these defines in `gatt_svr.c`:
```c
#define LED1_GPIO 2
#define LED2_GPIO 4
#define LED3_GPIO 5
#define LED4_GPIO 18
```

### Change Device Name:
Modify in `main.c`:
```c
rc = ble_svc_gap_device_name_set("your-device-name");
```

### Change UUIDs:
Update both ESP32 and Flutter app with matching UUIDs.

## License
Apache 2.0 (inherited from ESP32 examples) 