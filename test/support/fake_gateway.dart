import 'dart:async';

import 'package:beatcast/core/models/broadcast_models.dart';
import 'package:beatcast/core/platform/beatcast_gateway.dart';

class FakeGateway implements BeatCastGateway {
  FakeGateway({Bootstrap? bootstrap})
      : boot = bootstrap ?? _readyBootstrap();

  Bootstrap boot;
  final StreamController<Bootstrap> _events =
      StreamController<Bootstrap>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  int coreRequests = 0;
  int backgroundRequests = 0;
  int settingsUpdates = 0;
  int appSettingsOpened = 0;
  int permissionsPromptedCalls = 0;
  bool closeStream = true;

  String? startError;
  bool grantCore = true;
  bool grantBackground = true;

  static Bootstrap _readyBootstrap() {
    const permissions = PermissionState(
      sensorGranted: true,
      backgroundSensorGranted: true,
      bluetoothGranted: true,
      notificationsGranted: true,
    );
    return const Bootstrap(
      snapshot: BroadcastSnapshot(
        deviceName: 'Galaxy Watch Test',
        batteryPercent: 82,
      ),
      permissions: permissions,
      settings: BroadcastSettings.defaults,
      bluetoothEnabled: true,
      advertisingSupported: true,
      appVersion: '1.0.0',
    );
  }

  void emit() => _events.add(boot);

  @override
  Stream<Bootstrap> get events => _events.stream;

  @override
  Future<Bootstrap> bootstrap() async => boot;

  @override
  Future<StartResult> startBroadcast() async {
    startCalls += 1;
    final error = startError;
    if (error != null) {
      return StartResult(ok: false, error: error);
    }
    boot = boot.copyWith(
      snapshot: BroadcastSnapshot(
        phase: BroadcastPhase.advertising,
        serviceRunning: true,
        deviceName: boot.snapshot.deviceName,
        batteryPercent: boot.snapshot.batteryPercent,
        startedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        advertising: true,
      ),
    );
    emit();
    return const StartResult(ok: true);
  }

  @override
  Future<void> stopBroadcast() async {
    stopCalls += 1;
    boot = boot.copyWith(snapshot: BroadcastSnapshot.idle);
    emit();
  }

  @override
  Future<Bootstrap> requestCorePermissions() async {
    coreRequests += 1;
    boot = boot.copyWith(
      permissions: PermissionState(
        sensorGranted: grantCore,
        backgroundSensorGranted: boot.permissions.backgroundSensorGranted,
        bluetoothGranted: grantCore,
        notificationsGranted: grantCore,
      ),
    );
    emit();
    return boot;
  }

  @override
  Future<Bootstrap> requestBackgroundPermission() async {
    backgroundRequests += 1;
    boot = boot.copyWith(
      permissions: PermissionState(
        sensorGranted: boot.permissions.sensorGranted,
        backgroundSensorGranted: grantBackground,
        bluetoothGranted: boot.permissions.bluetoothGranted,
        notificationsGranted: boot.permissions.notificationsGranted,
      ),
    );
    emit();
    return boot;
  }

  @override
  Future<void> markPermissionsPrompted() async {
    permissionsPromptedCalls += 1;
  }

  @override
  Future<BroadcastSettings> updateSettings(BroadcastSettings settings) async {
    settingsUpdates += 1;
    boot = boot.copyWith(settings: settings);
    emit();
    return settings;
  }

  @override
  Future<void> openAppSettings() async {
    appSettingsOpened += 1;
  }

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestEnableBluetooth() async {
    boot = boot.copyWith(bluetoothEnabled: true);
    emit();
    return true;
  }

  @override
  Future<void> dispose() async {
    if (closeStream) await _events.close();
  }
}
