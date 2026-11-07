import 'package:flutter/services.dart';

import '../models/broadcast_models.dart';
import 'beatcast_gateway.dart';

class BeatCastPlatform implements BeatCastGateway {
  BeatCastPlatform({
    MethodChannel methodChannel = const MethodChannel('dev.beatcast/app'),
    EventChannel eventChannel = const EventChannel('dev.beatcast/events'),
  })  : _method = methodChannel,
        _eventsChannel = eventChannel;

  final MethodChannel _method;
  final EventChannel _eventsChannel;
  Stream<Bootstrap>? _events;

  @override
  Stream<Bootstrap> get events => _events ??= _eventsChannel
      .receiveBroadcastStream()
      .map((event) => Bootstrap.fromMap(event as Map<dynamic, dynamic>));

  @override
  Future<Bootstrap> bootstrap() async =>
      _bootstrapFrom(_asMap(await _invoke('bootstrap')));

  @override
  Future<StartResult> startBroadcast() async {
    final result = _asMap(await _invoke('startBroadcast'));
    return StartResult(
      ok: result['ok'] == true,
      error: result['error'] as String?,
      detail: result['detail'] as String?,
      bootstrap: result['bootstrap'] is Map
          ? Bootstrap.fromMap(result['bootstrap'] as Map<dynamic, dynamic>)
          : null,
    );
  }

  @override
  Future<void> stopBroadcast() async {
    await _invoke('stopBroadcast');
  }

  @override
  Future<Bootstrap> requestCorePermissions() async =>
      _bootstrapFrom(_asMap(await _invoke('requestCorePermissions')));

  @override
  Future<Bootstrap> requestBackgroundPermission() async =>
      _bootstrapFrom(_asMap(await _invoke('requestBackgroundPermission')));

  @override
  Future<void> markPermissionsPrompted() async {
    await _invoke('markPermissionsPrompted');
  }

  @override
  Future<BroadcastSettings> updateSettings(BroadcastSettings settings) async {
    final result = _asMap(await _invoke('updateSettings', settings.toMap()));
    return BroadcastSettings.fromMap(result);
  }

  @override
  Future<void> openAppSettings() async {
    await _invoke('openAppSettings');
  }

  @override
  Future<void> openBluetoothSettings() async {
    await _invoke('openBluetoothSettings');
  }

  @override
  Future<bool> requestEnableBluetooth() async {
    final result = await _invoke('requestEnableBluetooth');
    if (result is bool) return result;
    if (result is Map) return result['value'] == true || result['ok'] == true;
    return false;
  }

  @override
  Future<void> dispose() async {}

  Bootstrap _bootstrapFrom(Map<dynamic, dynamic> map) => Bootstrap.fromMap(map);

  Map<dynamic, dynamic> _asMap(Object? value) {
    if (value is Map) return value;
    throw const BeatCastException('invalid_platform_response');
  }

  Future<Object?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _method.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException catch (error) {
      throw BeatCastException('platform_unavailable', error.message);
    } on PlatformException catch (error) {
      throw BeatCastException(error.code, error.message);
    }
  }
}
