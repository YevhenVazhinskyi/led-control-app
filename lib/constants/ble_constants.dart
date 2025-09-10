class BleConstants {
  // Device Information (Updated from ESP32-S3 dual motor documentation)
  static const String deviceName = 'ESP32S3_DualMotor';
  
  // ESP32-S3 DUAL MOTOR Service UUIDs (CORRECTED to match ESP32 BLE_UUID128_INIT byte order)
  
  // Motor 1 Service - FIXED UUIDs matching ESP32 actual broadcast
  static const String motor1ServiceUuid = 'e1cdab90-7856-3412-abcd-ef9087654321';
  static const String motor1PositionCharUuid = '11cdab90-7856-3412-abcd-ef9087654321';
  static const String motor1CommandCharUuid = '12cdab90-7856-3412-abcd-ef9087654321';
  static const String motor1StatusCharUuid = '13cdab90-7856-3412-abcd-ef9087654321';
  static const String motor1SpeedCharUuid = '14cdab90-7856-3412-abcd-ef9087654321';

  // Motor 2 Service - FIXED UUIDs matching ESP32 actual broadcast
  static const String motor2ServiceUuid = 'e2cdab90-7856-3412-abcd-ef9087654321';
  static const String motor2PositionCharUuid = '21cdab90-7856-3412-abcd-ef9087654321';
  static const String motor2CommandCharUuid = '22cdab90-7856-3412-abcd-ef9087654321';
  static const String motor2StatusCharUuid = '23cdab90-7856-3412-abcd-ef9087654321';
  static const String motor2SpeedCharUuid = '24cdab90-7856-3412-abcd-ef9087654321';

  // System Control Service - FIXED UUIDs matching ESP32 actual broadcast
  static const String systemServiceUuid = 'e0cdab90-7856-3412-abcd-ef9087654321';
  static const String dualCommandCharUuid = '01cdab90-7856-3412-abcd-ef9087654321';
  static const String syncModeCharUuid = '02cdab90-7856-3412-abcd-ef9087654321';
  static const String systemStatusCharUuid = '03cdab90-7856-3412-abcd-ef9087654321';

  // Legacy single motor support (backward compatibility)
  static const String motorServiceUuid = motor1ServiceUuid;
  static const String motorPositionCharUuid = motor1PositionCharUuid;
  static const String motorCommandCharUuid = motor1CommandCharUuid;
  static const String motorStatusCharUuid = motor1StatusCharUuid;
  static const String motorSpeedCharUuid = motor1SpeedCharUuid;

  // MOTOR Commands (from ESP32 gatt_svr.c)
  static const int motorCmdStop = 0x00;
  static const int motorCmdMoveAbsolute = 0x01;
  static const int motorCmdMoveRelative = 0x02;
  static const int motorCmdHome = 0x03;
  static const int motorCmdSetSpeed = 0x04;
  static const int motorCmdEnable = 0x05;
  static const int motorCmdDisable = 0x06;
  static const int motorCmdCalibrate = 0x07;

  // DUAL MOTOR Commands (for System Control Service)
  static const int dualCmdStopAll = 0x10;
  static const int dualCmdHomeAll = 0x11;
  static const int dualCmdSyncMove = 0x12;
  static const int dualCmdParallelMove = 0x13;
  static const int dualCmdMirrorMove = 0x14;
  static const int dualCmdSequenceMove = 0x15;
  static const int dualCmdCalibrateAll = 0x16;
  static const int dualCmdEnableAll = 0x17;
  static const int dualCmdDisableAll = 0x18;

  // MOTOR Status Values (Updated for new firmware)
  static const int motorStatusIdle = 0;      // Motor is idle/stopped
  static const int motorStatusMoving = 1;    // Motor is moving
  static const int motorStatusError = 2;     // Motor fault detected
  static const int motorStatusDisabled = 3;  // Motor driver disabled

  // Legacy status values for backward compatibility
  static const int motorStatusStopped = 0;   // Maps to IDLE
  static const int motorStatusHoming = 1;    // Maps to MOVING

  // MOTOR Speed limits (ms delay between steps)
  static const int minSpeed = 5;
  static const int maxSpeed = 100;
  static const int defaultSpeed = 10;
}
