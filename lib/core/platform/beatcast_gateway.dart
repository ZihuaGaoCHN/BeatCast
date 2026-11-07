import '../models/broadcast_models.dart';

abstract interface class BeatCastGateway {
  Stream<Bootstrap> get events;

  Future<Bootstrap> bootstrap();

  Future<StartResult> startBroadcast();

  Future<void> stopBroadcast();

  Future<Bootstrap> requestCorePermissions();

  Future<Bootstrap> requestBackgroundPermission();

  Future<void> markPermissionsPrompted();

  Future<BroadcastSettings> updateSettings(BroadcastSettings settings);

  Future<void> openAppSettings();

  Future<void> openBluetoothSettings();

  Future<bool> requestEnableBluetooth();

  Future<void> dispose();
}
