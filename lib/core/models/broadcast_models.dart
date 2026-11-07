import 'package:flutter/foundation.dart';

enum BroadcastPhase {
  idle,
  starting,
  advertising,
  live,
  error;

  static BroadcastPhase parse(Object? value) {
    return switch (value) {
      'starting' => BroadcastPhase.starting,
      'advertising' => BroadcastPhase.advertising,
      'live' => BroadcastPhase.live,
      'error' => BroadcastPhase.error,
      _ => BroadcastPhase.idle,
    };
  }

  String get wire => switch (this) {
        BroadcastPhase.idle => 'idle',
        BroadcastPhase.starting => 'starting',
        BroadcastPhase.advertising => 'advertising',
        BroadcastPhase.live => 'live',
        BroadcastPhase.error => 'error',
      };
}

@immutable
class BroadcastSnapshot {
  const BroadcastSnapshot({
    this.phase = BroadcastPhase.idle,
    this.serviceRunning = false,
    this.bpm,
    this.contact = false,
    this.clients = 0,
    this.advertising = false,
    this.errorCode,
    this.errorDetail,
    this.deviceName = 'Wear OS watch',
    this.batteryPercent,
    this.startedAtEpochMs,
    this.lastSampleAtEpochMs,
    this.sensorSource,
  });

  static const idle = BroadcastSnapshot();

  final BroadcastPhase phase;
  final bool serviceRunning;
  final int? bpm;
  final bool contact;
  final int clients;
  final bool advertising;
  final String? errorCode;
  final String? errorDetail;
  final String deviceName;
  final int? batteryPercent;
  final int? startedAtEpochMs;
  final int? lastSampleAtEpochMs;
  final String? sensorSource;

  bool get hasError => errorCode != null;
  bool get isRunning => serviceRunning;

  Duration get uptime {
    final started = startedAtEpochMs;
    if (started == null || !serviceRunning) return Duration.zero;
    final elapsed = DateTime.now().millisecondsSinceEpoch - started;
    return Duration(milliseconds: elapsed < 0 ? 0 : elapsed);
  }

  DateTime? get lastSampleAt => lastSampleAtEpochMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastSampleAtEpochMs!);

  factory BroadcastSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return idle;
    return BroadcastSnapshot(
      phase: BroadcastPhase.parse(map['phase']),
      serviceRunning: map['serviceRunning'] == true,
      bpm: _asInt(map['bpm']),
      contact: map['contact'] == true,
      clients: _asInt(map['clients']) ?? 0,
      advertising: map['advertising'] == true,
      errorCode: map['errorCode'] as String?,
      errorDetail: map['errorDetail'] as String?,
      deviceName: (map['deviceName'] as String?)?.trim().isNotEmpty == true
          ? map['deviceName'] as String
          : idle.deviceName,
      batteryPercent: _asInt(map['batteryPercent']),
      startedAtEpochMs: _asInt(map['startedAtEpochMs']),
      lastSampleAtEpochMs: _asInt(map['lastSampleAtEpochMs']),
      sensorSource: map['sensorSource'] as String?,
    );
  }

  BroadcastSnapshot copyWith({
    BroadcastPhase? phase,
    bool? serviceRunning,
    int? bpm,
    bool clearBpm = false,
    bool? contact,
    int? clients,
    bool? advertising,
    String? errorCode,
    String? errorDetail,
    bool clearError = false,
    String? deviceName,
    int? batteryPercent,
    int? startedAtEpochMs,
    int? lastSampleAtEpochMs,
    String? sensorSource,
  }) {
    return BroadcastSnapshot(
      phase: phase ?? this.phase,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      bpm: clearBpm ? null : (bpm ?? this.bpm),
      contact: contact ?? this.contact,
      clients: clients ?? this.clients,
      advertising: advertising ?? this.advertising,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      deviceName: deviceName ?? this.deviceName,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
      lastSampleAtEpochMs: lastSampleAtEpochMs ?? this.lastSampleAtEpochMs,
      sensorSource: sensorSource ?? this.sensorSource,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

@immutable
class PermissionState {
  const PermissionState({
    this.sensorGranted = false,
    this.backgroundSensorGranted = false,
    this.bluetoothGranted = false,
    this.notificationsGranted = false,
    this.backgroundSupported = true,
  });

  static const unknown = PermissionState();

  final bool sensorGranted;
  final bool backgroundSensorGranted;
  final bool bluetoothGranted;
  final bool notificationsGranted;
  final bool backgroundSupported;

  /// Notifications are useful but not required to keep a foreground service
  /// alive, so they do not block broadcasting.
  bool get coreGranted => sensorGranted && bluetoothGranted;

  bool get ready => coreGranted && backgroundSensorGranted;

  bool get needsBackgroundSettings =>
      backgroundSupported && !backgroundSensorGranted;

  factory PermissionState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return unknown;
    return PermissionState(
      sensorGranted: map['sensorGranted'] == true,
      backgroundSensorGranted: map['backgroundSensorGranted'] == true,
      bluetoothGranted: map['bluetoothGranted'] == true,
      notificationsGranted: map['notificationsGranted'] == true,
      backgroundSupported: map['backgroundSupported'] != false,
    );
  }
}

enum AdvertisingMode {
  balanced,
  lowPower;

  String get wire => this == AdvertisingMode.lowPower ? 'low_power' : 'balanced';

  static AdvertisingMode parse(Object? value) =>
      value == 'low_power' ? AdvertisingMode.lowPower : AdvertisingMode.balanced;
}

@immutable
class BroadcastSettings {
  const BroadcastSettings({
    this.advertisingMode = AdvertisingMode.balanced,
    this.autoStopMinutes = 15,
    this.maxSessionMinutes = 0,
  });

  static const defaults = BroadcastSettings();

  static const autoStopOptions = <int>[0, 5, 15, 30];
  static const sessionOptions = <int>[0, 60, 120, 240];

  final AdvertisingMode advertisingMode;
  final int autoStopMinutes;
  final int maxSessionMinutes;

  factory BroadcastSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;
    final autoStop = _asInt(map['autoStopMinutes']);
    final session = _asInt(map['maxSessionMinutes']);
    return BroadcastSettings(
      advertisingMode: AdvertisingMode.parse(map['advertisingMode']),
      autoStopMinutes:
          autoStopOptions.contains(autoStop) ? autoStop! : defaults.autoStopMinutes,
      maxSessionMinutes: sessionOptions.contains(session)
          ? session!
          : defaults.maxSessionMinutes,
    );
  }

  BroadcastSettings copyWith({
    AdvertisingMode? advertisingMode,
    int? autoStopMinutes,
    int? maxSessionMinutes,
  }) =>
      BroadcastSettings(
        advertisingMode: advertisingMode ?? this.advertisingMode,
        autoStopMinutes: autoStopMinutes ?? this.autoStopMinutes,
        maxSessionMinutes: maxSessionMinutes ?? this.maxSessionMinutes,
      );

  Map<String, Object> toMap() => {
        'advertisingMode': advertisingMode.wire,
        'autoStopMinutes': autoStopMinutes,
        'maxSessionMinutes': maxSessionMinutes,
      };

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

@immutable
class Bootstrap {
  const Bootstrap({
    this.snapshot = BroadcastSnapshot.idle,
    this.permissions = PermissionState.unknown,
    this.settings = BroadcastSettings.defaults,
    this.bluetoothEnabled = false,
    this.advertisingSupported = true,
    this.firstPermissionRun = false,
    this.appVersion = '1.0.0',
  });

  final BroadcastSnapshot snapshot;
  final PermissionState permissions;
  final BroadcastSettings settings;
  final bool bluetoothEnabled;
  final bool advertisingSupported;
  final bool firstPermissionRun;
  final String appVersion;

  factory Bootstrap.fromMap(Map<dynamic, dynamic> map) {
    return Bootstrap(
      snapshot: BroadcastSnapshot.fromMap(
        map['broadcast'] as Map<dynamic, dynamic>?,
      ),
      permissions: PermissionState.fromMap(
        map['permissions'] as Map<dynamic, dynamic>?,
      ),
      settings: BroadcastSettings.fromMap(
        map['settings'] as Map<dynamic, dynamic>?,
      ),
      bluetoothEnabled: map['bluetoothEnabled'] == true,
      advertisingSupported: map['advertisingSupported'] != false,
      firstPermissionRun: map['firstPermissionRun'] == true,
      appVersion: (map['appVersion'] as String?) ?? '1.0.0',
    );
  }

  Bootstrap copyWith({
    BroadcastSnapshot? snapshot,
    PermissionState? permissions,
    BroadcastSettings? settings,
    bool? bluetoothEnabled,
    bool? advertisingSupported,
    bool? firstPermissionRun,
    String? appVersion,
  }) =>
      Bootstrap(
        snapshot: snapshot ?? this.snapshot,
        permissions: permissions ?? this.permissions,
        settings: settings ?? this.settings,
        bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
        advertisingSupported: advertisingSupported ?? this.advertisingSupported,
        firstPermissionRun: firstPermissionRun ?? this.firstPermissionRun,
        appVersion: appVersion ?? this.appVersion,
      );
}

@immutable
class StartResult {
  const StartResult({required this.ok, this.error, this.detail, this.bootstrap});

  final bool ok;
  final String? error;
  final String? detail;
  final Bootstrap? bootstrap;
}

class BeatCastException implements Exception {
  const BeatCastException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => 'BeatCastException($code${detail == null ? '' : ': $detail'})';
}
