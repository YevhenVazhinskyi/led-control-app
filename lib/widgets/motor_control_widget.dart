import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ble_service.dart';
import '../models/motor_device.dart';
import '../constants/ble_constants.dart';
import 'motor_selector_widget.dart';

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
  MotorId _selectedMotor = MotorId.motor1;
  
  @override
  void initState() {
    super.initState();
    // No status updates - just send commands
  }

  Future<void> _sendCommand(MotorCommand command, {String? action, MotorId? motorId}) async {
    try {
      await widget.bleService.sendMotorCommand(command, motorId ?? _selectedMotor);
      if (action != null && mounted) {
        final motorName = (motorId ?? _selectedMotor).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent: $action ($motorName)'), duration: const Duration(seconds: 1)),
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
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text('Dual Stepper Motor Controller', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // Motor Selector
            MotorSelectorWidget(
              selectedMotor: _selectedMotor,
              onMotorSelected: (motorId) {
                setState(() {
                  _selectedMotor = motorId;
                });
              },
              hasMotor1: widget.bleService.hasMotor1Service,
              hasMotor2: widget.bleService.hasMotor2Service,
              hasSystem: widget.bleService.hasSystemService,
            ),
            const SizedBox(height: 12),

            // Simple Status
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Commands sent to ESP32 - Check ESP32 debug logs for response',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            // Basic Movement Controls
            const Text('Basic Movement:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            // Calibration button (30-second LEFT movement for manual home button press)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendCommand(MotorCommand.calibrate(), action: 'CALIBRATE 30s LEFT cmd'),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('CALIBRATE (30s LEFT - press home button manually)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
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

            // Dual Motor Commands (only show if system service available)
            if (widget.bleService.hasSystemService) ...[
              const Text('Dual Motor Commands:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.stopAll(), action: 'STOP ALL', motorId: null),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Stop All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.homeAll(), action: 'HOME ALL', motorId: null),
                    icon: const Icon(Icons.home, size: 16),
                    label: const Text('Home All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.enableAll(), action: 'ENABLE ALL', motorId: null),
                    icon: const Icon(Icons.power, size: 16),
                    label: const Text('Enable All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.disableAll(), action: 'DISABLE ALL', motorId: null),
                    icon: const Icon(Icons.power_off, size: 16),
                    label: const Text('Disable All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.parallelMove(1000), action: 'PARALLEL MOVE', motorId: null),
                    icon: const Icon(Icons.compare_arrows, size: 16),
                    label: const Text('Parallel +1000'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.mirrorMove(1000), action: 'MIRROR MOVE', motorId: null),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Mirror +1000'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendCommand(MotorCommand.calibrateAll(), action: 'CALIBRATE ALL 30s LEFT', motorId: null),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Calibrate All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

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
