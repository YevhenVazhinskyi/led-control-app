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
      case BleConstants.motorStatusIdle:
        return 'Idle';
      case BleConstants.motorStatusMoving:
        return 'Moving';
      case BleConstants.motorStatusError:
        return 'Error';
      case BleConstants.motorStatusDisabled:
        return 'Disabled';
      default:
        return 'Unknown';
    }
  }

  bool get isMoving => status == BleConstants.motorStatusMoving;
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
  factory MotorCommand.calibrate() => MotorCommand(command: BleConstants.motorCmdCalibrate);

  // Dual motor command factories
  factory MotorCommand.stopAll() => MotorCommand(command: BleConstants.dualCmdStopAll);
  factory MotorCommand.homeAll() => MotorCommand(command: BleConstants.dualCmdHomeAll);
  factory MotorCommand.syncMove(int position) => 
    MotorCommand(command: BleConstants.dualCmdSyncMove, parameter: position);
  factory MotorCommand.parallelMove(int steps) => 
    MotorCommand(command: BleConstants.dualCmdParallelMove, parameter: steps);
  factory MotorCommand.mirrorMove(int steps) => 
    MotorCommand(command: BleConstants.dualCmdMirrorMove, parameter: steps);
  factory MotorCommand.sequenceMove(int motorId) => 
    MotorCommand(command: BleConstants.dualCmdSequenceMove, parameter: motorId);
  factory MotorCommand.calibrateAll() => MotorCommand(command: BleConstants.dualCmdCalibrateAll);
  factory MotorCommand.enableAll() => MotorCommand(command: BleConstants.dualCmdEnableAll);
  factory MotorCommand.disableAll() => MotorCommand(command: BleConstants.dualCmdDisableAll);
}

enum MotorId {
  motor1,
  motor2,
}

class DualMotorState {
  final MotorState motor1;
  final MotorState motor2;
  final bool syncMode;
  final DateTime lastUpdate;

  DualMotorState({
    MotorState? motor1,
    MotorState? motor2,
    this.syncMode = false,
    DateTime? lastUpdate,
  }) : motor1 = motor1 ?? MotorState(),
       motor2 = motor2 ?? MotorState(),
       lastUpdate = lastUpdate ?? DateTime.now();

  DualMotorState copyWith({
    MotorState? motor1,
    MotorState? motor2,
    bool? syncMode,
  }) {
    return DualMotorState(
      motor1: motor1 ?? this.motor1,
      motor2: motor2 ?? this.motor2,
      syncMode: syncMode ?? this.syncMode,
      lastUpdate: DateTime.now(),
    );
  }

  MotorState getMotor(MotorId motorId) {
    switch (motorId) {
      case MotorId.motor1:
        return motor1;
      case MotorId.motor2:
        return motor2;
    }
  }

  bool get anyMoving => motor1.isMoving || motor2.isMoving;
  bool get anyFault => motor1.isFault || motor2.isFault;
}

enum SyncMode {
  independent,  // 0 - Motors work independently
  parallel,     // 1 - Motors move together same direction
  mirrored,     // 2 - Motors move opposite directions
  coordinated,  // 3 - Motors coordinate movements
  sequential,   // 4 - Motors move one after another
}

class SystemStatus {
  final int systemStatus;
  final SyncMode syncMode;
  final int motor1Status;
  final int motor1Position;
  final int motor2Status;
  final int motor2Position;
  final DateTime lastUpdate;

  SystemStatus({
    this.systemStatus = 0,
    this.syncMode = SyncMode.independent,
    this.motor1Status = 0,
    this.motor1Position = 0,
    this.motor2Status = 0,
    this.motor2Position = 0,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  factory SystemStatus.fromBytes(List<int> data) {
    if (data.length < 8) {
      return SystemStatus();
    }
    
    // Parse 8-byte system status: [sys_status, sync_mode, m1_status, m1_pos_low, m1_pos_high, m2_status, m2_pos_low, m2_pos_high]
    final systemStatus = data[0];
    final syncModeValue = data[1];
    final motor1Status = data[2];
    final motor1Position = (data[4] << 8) | data[3]; // Little endian
    final motor2Status = data[5];
    final motor2Position = (data[7] << 8) | data[6]; // Little endian

    SyncMode syncMode = SyncMode.independent;
    if (syncModeValue >= 0 && syncModeValue < SyncMode.values.length) {
      syncMode = SyncMode.values[syncModeValue];
    }

    return SystemStatus(
      systemStatus: systemStatus,
      syncMode: syncMode,
      motor1Status: motor1Status,
      motor1Position: motor1Position,
      motor2Status: motor2Status,
      motor2Position: motor2Position,
      lastUpdate: DateTime.now(),
    );
  }

  SystemStatus copyWith({
    int? systemStatus,
    SyncMode? syncMode,
    int? motor1Status,
    int? motor1Position,
    int? motor2Status,
    int? motor2Position,
  }) {
    return SystemStatus(
      systemStatus: systemStatus ?? this.systemStatus,
      syncMode: syncMode ?? this.syncMode,
      motor1Status: motor1Status ?? this.motor1Status,
      motor1Position: motor1Position ?? this.motor1Position,
      motor2Status: motor2Status ?? this.motor2Status,
      motor2Position: motor2Position ?? this.motor2Position,
      lastUpdate: DateTime.now(),
    );
  }

  String get statusText {
    switch (systemStatus) {
      case 0:
        return 'Initializing';
      case 1:
        return 'Ready';
      case 2:
        return 'Running';
      case 3:
        return 'Error';
      case 4:
        return 'Testing';
      default:
        return 'Unknown';
    }
  }

  String get syncModeText {
    switch (syncMode) {
      case SyncMode.independent:
        return 'Independent';
      case SyncMode.parallel:
        return 'Parallel';
      case SyncMode.mirrored:
        return 'Mirrored';
      case SyncMode.coordinated:
        return 'Coordinated';
      case SyncMode.sequential:
        return 'Sequential';
    }
  }
}

// Update DualMotorState to include SystemStatus
class DualMotorStateWithSystem {
  final MotorState motor1;
  final MotorState motor2;
  final SystemStatus systemStatus;
  final DateTime lastUpdate;

  DualMotorStateWithSystem({
    MotorState? motor1,
    MotorState? motor2,
    SystemStatus? systemStatus,
    DateTime? lastUpdate,
  }) : motor1 = motor1 ?? MotorState(),
       motor2 = motor2 ?? MotorState(),
       systemStatus = systemStatus ?? SystemStatus(),
       lastUpdate = lastUpdate ?? DateTime.now();

  DualMotorStateWithSystem copyWith({
    MotorState? motor1,
    MotorState? motor2,
    SystemStatus? systemStatus,
  }) {
    return DualMotorStateWithSystem(
      motor1: motor1 ?? this.motor1,
      motor2: motor2 ?? this.motor2,
      systemStatus: systemStatus ?? this.systemStatus,
      lastUpdate: DateTime.now(),
    );
  }

  MotorState getMotor(MotorId motorId) {
    switch (motorId) {
      case MotorId.motor1:
        return motor1;
      case MotorId.motor2:
        return motor2;
    }
  }

  bool get anyMoving => motor1.isMoving || motor2.isMoving;
  bool get anyFault => motor1.isFault || motor2.isFault;
  bool get syncMode => systemStatus.syncMode != SyncMode.independent;
}
