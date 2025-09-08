class BleConstants {
  // Device Information (Updated from ESP32-S3 documentation)
  static const String deviceName = 'ESP32S3_StepperMotor';
  
  // LED Service UUIDs (Updated from ESP32-S3 documentation)
  static const String ledServiceUuid = 'efcdab90-7856-3412-efcd-ab9078563412';
  static const String led1CharUuid = '12345678-90ab-cdef-1234-567890abcd01'; // GPIO2
  static const String led2CharUuid = '12345678-90ab-cdef-1234-567890abcd02'; // GPIO4
  static const String led3CharUuid = '12345678-90ab-cdef-1234-567890abcd03'; // GPIO5
  static const String led4CharUuid = '12345678-90ab-cdef-1234-567890abcd04'; // GPIO18

  // MOTOR Service UUIDs (Updated from ESP32-S3 documentation)
  static const String motorServiceUuid = '2143658790efcdab-1234-5678-90ab-cdef';
  static const String motorPositionCharUuid = '2143658790efcdab-1234-5678-90ab-cd01';
  static const String motorCommandCharUuid = '2143658790efcdab-1234-5678-90ab-cd02';
  static const String motorStatusCharUuid = '2143658790efcdab-1234-5678-90ab-cd03';
  static const String motorSpeedCharUuid = '2143658790efcdab-1234-5678-90ab-cd04';

  // MOTOR Commands (from ESP32 gatt_svr.c)
  static const int motorCmdStop = 0x00;
  static const int motorCmdMoveAbsolute = 0x01;
  static const int motorCmdMoveRelative = 0x02;
  static const int motorCmdHome = 0x03;
  static const int motorCmdSetSpeed = 0x04;
  static const int motorCmdEnable = 0x05;
  static const int motorCmdDisable = 0x06;

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
