import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LedControlWidget extends StatelessWidget {
  final String ledName;
  final bool state;
  final BluetoothCharacteristic? characteristic;
  final int ledNumber;
  final Function(BluetoothCharacteristic?, bool, int) onLedToggle;

  const LedControlWidget({
    super.key,
    required this.ledName,
    required this.state,
    required this.characteristic,
    required this.ledNumber,
    required this.onLedToggle,
  });

  @override
  Widget build(BuildContext context) {
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
                          color: Colors.red.withValues(alpha: 0.5),
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
                onLedToggle(characteristic, value, ledNumber);
              },
            ),
          ],
        ),
      ),
    );
  }
}