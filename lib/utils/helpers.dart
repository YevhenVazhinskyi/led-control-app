/**
 * @file: helpers.dart
 * @description: Utility functions for BLE operations, validation, and common app operations
 * @dependencies: constants.dart
 * @created: 2024-12-19
 */

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';

/// Utility functions for LED Control App
class Helpers {
  /// Validates if a device name matches STM32WB55 pattern
  static bool isStm32Device(String deviceName) {
    return deviceName.toLowerCase().contains('stm32wb55') ||
        deviceName.toLowerCase().contains('stm32');
  }

  /// Validates LED ID
  static bool isValidLedId(int ledId) {
    return AppConstants.ledIds.contains(ledId);
  }

  /// Validates brightness value
  static bool isValidBrightness(int brightness) {
    return brightness >= AppConstants.minBrightness &&
        brightness <= AppConstants.maxBrightness;
  }

  /// Clamps brightness value to valid range
  static int clampBrightness(int brightness) {
    return brightness.clamp(
      AppConstants.minBrightness,
      AppConstants.maxBrightness,
    );
  }

  /// Creates LED control command JSON
  static String createLedCommand(int ledId, String action, {int? brightness}) {
    final Map<String, dynamic> command = {
      'command': 'led_control',
      'led_id': ledId,
      'action': action,
    };

    if (brightness != null) {
      command['brightness'] = clampBrightness(brightness);
    }

    return jsonEncode(command);
  }

  /// Parses LED status response
  static Map<String, dynamic>? parseLedResponse(String response) {
    try {
      return jsonDecode(response) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to parse LED response: $e');
      return null;
    }
  }

  /// Shows a snackbar with message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Shows error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Formats duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Gets LED color based on state
  static Color getLedColor(bool isOn, {int brightness = 255}) {
    if (!isOn) return Colors.grey;

    final opacity = brightness / AppConstants.maxBrightness;
    return Colors.amber.withOpacity(opacity);
  }

  /// Validates BLE UUID format
  static bool isValidUuid(String uuid) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(uuid);
  }

  /// Converts string to UUID format
  static String formatUuid(String uuid) {
    // Remove any non-hex characters and format as UUID
    final cleanUuid = uuid.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleanUuid.length != 32) return uuid;

    return '${cleanUuid.substring(0, 8)}-'
        '${cleanUuid.substring(8, 12)}-'
        '${cleanUuid.substring(12, 16)}-'
        '${cleanUuid.substring(16, 20)}-'
        '${cleanUuid.substring(20, 32)}';
  }

  /// Debounce function for repeated calls
  static Function debounce(Function func, Duration wait) {
    Timer? timer;
    return (List<dynamic> args) {
      timer?.cancel();
      timer = Timer(wait, () => func(args));
    };
  }
}
