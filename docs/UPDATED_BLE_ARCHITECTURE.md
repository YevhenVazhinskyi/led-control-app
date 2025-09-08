# Updated BLE Architecture - ESP32-S3 Stepper Motor Control

## Project Overview

This Flutter application has been updated to work with the ESP32-S3 Stepper Motor device according to the specifications in `flutter_esp32/BLE_Flutter_Info.txt`. The project maintains its existing UI structure and architecture while updating all BLE communication to match the ESP32-S3 implementation.

## Device Information

- **Device Name**: `ESP32S3_StepperMotor`
- **BLE Version**: 5.0
- **Advertising Interval**: 20-40ms
- **Example MAC**: 24:ec:4a:3a:2c:c8

## BLE Services & Characteristics

### 1. LED Control Service
- **Service UUID**: `efcdab90-7856-3412-efcd-ab9078563412`
- **Characteristics**:
  - LED1: `12345678-90ab-cdef-1234-567890abcd01` (GPIO2) [Read, Write]
  - LED2: `12345678-90ab-cdef-1234-567890abcd02` (GPIO4) [Read, Write]
  - LED3: `12345678-90ab-cdef-1234-567890abcd03` (GPIO5) [Read, Write]
  - LED4: `12345678-90ab-cdef-1234-567890abcd04` (GPIO18) [Read, Write]

### 2. Motor Control Service
- **Service UUID**: `2143658790efcdab-1234-5678-90ab-cdef`
- **Characteristics**:
  - Motor Position: `2143658790efcdab-1234-5678-90ab-cd01` [Read]
  - Motor Command: `2143658790efcdab-1234-5678-90ab-cd02` [Write]
  - Motor Status: `2143658790efcdab-1234-5678-90ab-cd03` [Read, Notify]
  - Motor Speed: `2143658790efcdab-1234-5678-90ab-cd04` [Read, Write]

## Motor Commands (3-byte format)

| Command | Value | Parameter | Description |
|---------|-------|-----------|-------------|
| STOP | 0x00 | 0 | Stop motor movement |
| MOVE_ABS | 0x01 | position | Move to absolute position (0-65535) |
| MOVE_REL | 0x02 | steps | Move relative steps (-32768 to +32767) |
| HOME | 0x03 | 0 | Home the motor (find GPIO13 sensor) |
| SET_SPEED | 0x04 | delay_ms | Set step delay (5-100ms) |
| ENABLE | 0x05 | 0 | Enable motor driver (DRV8833) |
| DISABLE | 0x06 | 0 | Disable motor driver |

## Motor Status Response (4-byte format)

| Byte | Description | Values |
|------|-------------|---------|
| 0 | Status | 0=STOPPED, 1=MOVING, 2=HOMING, 3=ERROR |
| 1 | Position Low | Low byte of 16-bit position |
| 2 | Position High | High byte of 16-bit position |
| 3 | Fault | 0=OK, 1=Hardware fault detected |

## Updated Flutter Architecture

### Key Files Updated

1. **`lib/constants/ble_constants.dart`**
   - Added device name constant: `ESP32S3_StepperMotor`
   - Updated service UUIDs to match ESP32-S3 specification
   - Added GPIO pin mapping comments for LEDs

2. **`lib/services/ble_service.dart`**
   - Updated scanning to filter for ESP32S3_StepperMotor devices
   - Enhanced device discovery with fallback ESP32 matching
   - Improved logging and debugging output

3. **`lib/models/motor_device.dart`**
   - Verified 3-byte command format matches ESP32 specification
   - Confirmed 4-byte status parsing implementation
   - Factory methods for all motor commands

### Preserved Architecture Components

- **UI Structure**: All widgets maintain their existing interfaces
- **State Management**: LedState and motor state handling preserved
- **Connection Flow**: Same connection and service discovery pattern
- **Error Handling**: Existing error handling and user feedback maintained

### Hardware Mapping

#### ESP32-S3 GPIO Pins
- **Motor Control**: GPIO21,19,16,17,14,12 (DRV8833 driver)
- **Home Sensor**: GPIO13 (D2F-01F sensor, active low)
- **LED Status**: GPIO2,4,5,18

#### Motor Specifications
- **Direction**: MOVES LEFT when positive steps (reversed firmware)
- **Home Position**: GPIO13 sensor triggers when LOW (0V)
- **Step Resolution**: Configurable via DRV8833
- **Speed Range**: 5-100ms delay between steps
- **Position Range**: 0-65535 (16-bit)

## Connection Flow

1. **Scan** → Find devices named "ESP32S3_StepperMotor" or containing "ESP32"
2. **Connect** → Establish BLE connection with 15-second timeout
3. **Discover Services** → Find LED and Motor service UUIDs
4. **Map Characteristics** → Identify all characteristics for both services
5. **Enable Notifications** → Subscribe to motor status updates
6. **Control** → Send commands and receive status updates

## Timing Considerations

- **Service discovery**: ~2-5 seconds
- **Command response**: ~10-50ms
- **Home operation**: ~10-30 seconds (depends on position)
- **1000 steps at 20ms**: ~20 seconds movement time
- **BLE connection timeout**: 15 seconds recommended

## Testing and Debugging

### Debug Output
The updated BLE service provides comprehensive logging:
- Service discovery details
- Characteristic mapping confirmation
- Command sending status
- Motor status updates

### Troubleshooting
1. **Device not found**: Check device name "ESP32S3_StepperMotor"
2. **Connection fails**: Ensure ESP32 is powered and not connected elsewhere
3. **Service not found**: Wait for full service discovery completion
4. **Commands ignored**: Check motor is enabled first (0x05 command)
5. **No movement**: Verify motor power supply and wiring
6. **Position drift**: Use home command (0x03) to recalibrate

## Project Status

✅ **Completed Updates:**
- BLE constants updated to ESP32-S3 specification
- Device discovery updated for ESP32S3_StepperMotor
- Motor command format verified and confirmed
- LED service UUIDs confirmed correct
- Connection logic updated for new device
- UI compatibility verified and maintained

The project now fully supports the ESP32-S3 Stepper Motor device while preserving all existing UI structure and user experience.
