/**
 * @file: constants.dart
 * @description: Application constants including BLE UUIDs, LED configurations, and app settings
 * @dependencies: None
 * @created: 2024-12-19
 */

/// Application constants for LED Control App
class AppConstants {
  // BLE Service UUIDs
  static const String serviceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String ledControlUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
  static const String ledStatusUuid = '0000FFE2-0000-1000-8000-00805F9B34FB';
  static const String connectionStatusUuid =
      '0000FFE3-0000-1000-8000-00805F9B34FB';

  // LED Configuration
  static const List<int> ledIds = [1, 2, 3, 4];
  static const int minBrightness = 0;
  static const int maxBrightness = 255;
  static const int defaultBrightness = 255;

  // BLE Configuration
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration commandTimeout = Duration(seconds: 5);

  // App Configuration
  static const String appName = 'LED Control';
  static const String appVersion = '1.0.0';
  static const String deviceNamePrefix = 'STM32WB55';

  // Storage Keys
  static const String lastConnectedDeviceKey = 'last_connected_device';
  static const String defaultBrightnessKey = 'default_brightness';
  static const String themeModeKey = 'theme_mode';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
  static const double largeIconSize = 48.0;
}
