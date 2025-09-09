class BleConstants {
  // Device Information (Updated from ESP32-S3 documentation)
  static const String deviceName = 'ESP32S3_StepperMotor';
  
  // MOTOR Service UUIDs (Updated to match actual ESP32 device)
  static const String motorServiceUuid = 'efcdab90-7856-3412-90ef-cdab21436587';
  static const String motorPositionCharUuid = '01cdab90-7856-3412-90ef-cdab21436587';
  static const String motorCommandCharUuid = '02cdab90-7856-3412-90ef-cdab21436587';
  static const String motorStatusCharUuid = '03cdab90-7856-3412-90ef-cdab21436587';
  static const String motorSpeedCharUuid = '04cdab90-7856-3412-90ef-cdab21436587';

  // MOTOR Commands (from ESP32 gatt_svr.c)
  static const int motorCmdStop = 0x00;
  static const int motorCmdMoveAbsolute = 0x01;
  static const int motorCmdMoveRelative = 0x02;
  static const int motorCmdHome = 0x03;
  static const int motorCmdSetSpeed = 0x04;
  static const int motorCmdEnable = 0x05;
  static const int motorCmdDisable = 0x06;
  static const int motorCmdCalibrate = 0x07;

  // MOTOR Status Values
  static const int motorStatusStopped = 0;
  static const int motorStatusMoving = 1;
  static const int motorStatusHoming = 2;
  static const int motorStatusError = 3;

  // MOTOR Speed limits (ms delay between steps)
  static const int minSpeed = 5;
  static const int maxSpeed = 100;
  static const int defaultSpeed = 10;
}
