import '../constants/ble_constants.dart';

class MotorState {
  final int position;
  final int status;
  final bool isFault;
  final int speed;
  final bool isEnabled;
  final DateTime lastUpdate;

  MotorState({
    this.position = 0,
    this.status = BleConstants.motorStatusStopped,
    this.isFault = false,
    this.speed = BleConstants.defaultSpeed,
    this.isEnabled = false,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  factory MotorState.fromStatusBytes(List<int> data) {
    if (data.length < 4) {
      return MotorState();
    }
    
    // Parse 4-byte status: [status, pos_low, pos_high, fault]
    final status = data[0];
    final position = (data[2] << 8) | data[1]; // Little endian
    final isFault = data[3] != 0;

    return MotorState(
      position: position,
      status: status,
      isFault: isFault,
      lastUpdate: DateTime.now(),
    );
  }

  MotorState copyWith({
    int? position,
    int? status,
    bool? isFault,
    int? speed,
    bool? isEnabled,
  }) {
    return MotorState(
      position: position ?? this.position,
      status: status ?? this.status,
      isFault: isFault ?? this.isFault,
      speed: speed ?? this.speed,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdate: DateTime.now(),
    );
  }

  String get statusText {
    switch (status) {
      case BleConstants.motorStatusStopped:
        return 'Stopped';
      case BleConstants.motorStatusMoving:
        return 'Moving';
      case BleConstants.motorStatusHoming:
        return 'Homing';
      case BleConstants.motorStatusError:
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  bool get isMoving => status == BleConstants.motorStatusMoving || 
                      status == BleConstants.motorStatusHoming;
}

class MotorCommand {
  final int command;
  final int parameter;

  MotorCommand({
    required this.command,
    this.parameter = 0,
  });

  // Convert to 3-byte array for ESP32: [command, param_low, param_high]
  List<int> toBytes() {
    return [
      command,
      parameter & 0xFF,          // Low byte
      (parameter >> 8) & 0xFF,   // High byte
    ];
  }

  // Factory methods for common commands
  factory MotorCommand.stop() => MotorCommand(command: BleConstants.motorCmdStop);
  factory MotorCommand.home() => MotorCommand(command: BleConstants.motorCmdHome);
  factory MotorCommand.enable() => MotorCommand(command: BleConstants.motorCmdEnable);
  factory MotorCommand.disable() => MotorCommand(command: BleConstants.motorCmdDisable);
  factory MotorCommand.moveAbsolute(int position) => 
    MotorCommand(command: BleConstants.motorCmdMoveAbsolute, parameter: position);
  factory MotorCommand.moveRelative(int steps) => 
    MotorCommand(command: BleConstants.motorCmdMoveRelative, parameter: steps);
  factory MotorCommand.setSpeed(int speed) => 
    MotorCommand(command: BleConstants.motorCmdSetSpeed, parameter: speed);
}
