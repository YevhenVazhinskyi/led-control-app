import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ble_service.dart';
import '../models/motor_device.dart';
import '../constants/ble_constants.dart';

class MotorControlWidget extends StatefulWidget {
  final BleService bleService;

  const MotorControlWidget({
    super.key,
    required this.bleService,
  });

  @override
  State<MotorControlWidget> createState() => _MotorControlWidgetState();
}

class _MotorControlWidgetState extends State<MotorControlWidget> {
  final TextEditingController _positionController = TextEditingController();
  int _targetPosition = 0;
  double _speed = BleConstants.defaultSpeed.toDouble();
  
  @override
  void initState() {
    super.initState();
    // No status updates - just send commands
  }

  Future<void> _sendCommand(MotorCommand command, {String? action}) async {
    try {
      // SIMPLE COMMAND SEND - DEBUG ON ESP32 SIDE
      await widget.bleService.sendBasicMotorCommand(command);
      if (action != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent: $action'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Send Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // SIMPLE MOTOR COMMAND SENDER - DEBUG ON ESP32

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text('Basic Stepper Motor Commands', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Simple Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Commands sent to ESP32 - Check ESP32 debug logs for response',
                style: TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Enable/Disable Row - ALWAYS ENABLED
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand(MotorCommand.enable(), action: 'ENABLE cmd'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enable'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand(MotorCommand.disable(), action: 'DISABLE cmd'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Disable'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Basic Movement Controls
            const Text('Basic Movement:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand(MotorCommand.moveRelative(-100), action: 'MOVE -100 cmd'),
                    child: const Text('-100'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand(MotorCommand.home(), action: 'HOME cmd'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('HOME'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand(MotorCommand.moveRelative(100), action: 'MOVE +100 cmd'),
                    child: const Text('+100'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Position Control
            const Text('Position Control:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: 'Target Position',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    onChanged: (value) {
                      _targetPosition = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendCommand(MotorCommand.moveAbsolute(_targetPosition), 
                      action: 'MOVE TO $_targetPosition cmd'),
                  child: const Text('GO'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Speed Control
            const Text('Speed Control:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Fast', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: BleConstants.minSpeed.toDouble(),
                    max: BleConstants.maxSpeed.toDouble(),
                    divisions: 19,
                    label: '${_speed.round()}ms',
                    onChanged: (value) {
                      setState(() {
                        _speed = value;
                      });
                    },
                    onChangeEnd: (value) async {
                      _sendCommand(MotorCommand.setSpeed(value.round()), action: 'SPEED ${value.round()}ms cmd');
                    },
                  ),
                ),
                const Text('Slow', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // Emergency Stop
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _sendCommand(MotorCommand.stop(), action: 'STOP cmd'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('🛑 EMERGENCY STOP', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }
}
