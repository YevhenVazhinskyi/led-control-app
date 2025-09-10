import 'package:flutter/material.dart';
import '../models/motor_device.dart';

class MotorSelectorWidget extends StatelessWidget {
  final MotorId selectedMotor;
  final Function(MotorId) onMotorSelected;
  final bool hasMotor1;
  final bool hasMotor2;
  final bool hasSystem;

  const MotorSelectorWidget({
    super.key,
    required this.selectedMotor,
    required this.onMotorSelected,
    this.hasMotor1 = false,
    this.hasMotor2 = false,
    this.hasSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motor Selection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMotorOption(
                    context,
                    MotorId.motor1,
                    'Motor 1',
                    hasMotor1,
                    Icons.precision_manufacturing,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMotorOption(
                    context,
                    MotorId.motor2,
                    'Motor 2',
                    hasMotor2,
                    Icons.precision_manufacturing,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasSystem) 
              _buildDualControlInfo()
            else if (hasMotor1 && !hasMotor2)
              _buildSingleMotorInfo()
            else if (!hasMotor1 && !hasMotor2)
              _buildNoMotorInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildMotorOption(
    BuildContext context,
    MotorId motorId,
    String label,
    bool isAvailable,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedMotor == motorId;
    
    return GestureDetector(
      onTap: isAvailable ? () => onMotorSelected(motorId) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable
              ? (isSelected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1))
              : Colors.grey.withOpacity(0.05),
          border: Border.all(
            color: isAvailable
                ? (isSelected ? color : Colors.grey.withOpacity(0.3))
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isAvailable
                  ? (isSelected ? color : Colors.grey[600])
                  : Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isAvailable
                    ? (isSelected ? color : Colors.grey[700])
                    : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualControlInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.sync,
            color: Colors.orange,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'Dual motor commands available',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMotorInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: 16,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Single motor mode - Motor 2 requires firmware upgrade',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMotorInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 16,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'No motor services found - check ESP32 connection',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
