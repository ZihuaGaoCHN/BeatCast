import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/broadcast_models.dart';
import '../platform/beatcast_gateway.dart';

class BroadcastController extends ChangeNotifier with WidgetsBindingObserver {
  BroadcastController(this._gateway);

  final BeatCastGateway _gateway;

  Bootstrap? _bootstrap;
  StreamSubscription<Bootstrap>? _events;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _initialPromptScheduled = false;
  bool _disposed = false;
  String? _errorCode;
  String? _errorDetail;

  BroadcastSnapshot get snapshot => _bootstrap?.snapshot ?? BroadcastSnapshot.idle;
  PermissionState get permissions => _bootstrap?.permissions ?? PermissionState.unknown;
  BroadcastSettings get settings => _bootstrap?.settings ?? BroadcastSettings.defaults;
  String get appVersion => _bootstrap?.appVersion ?? '1.0.0';
  bool get bluetoothEnabled => _bootstrap?.bluetoothEnabled ?? false;
  bool get advertisingSupported => _bootstrap?.advertisingSupported ?? true;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get isRunning => snapshot.serviceRunning;
  String? get errorCode => _errorCode ?? snapshot.errorCode;
  String? get errorDetail => _errorDetail ?? snapshot.errorDetail;
  bool get needsPermissionSetup => !permissions.ready;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    Bootstrap? initialBoot;
    try {
      final boot = await _gateway.bootstrap();
      initialBoot = boot;
      _bootstrap = boot;
      _events = _gateway.events.listen(
        _onBootstrapEvent,
        onError: (Object error, StackTrace stack) {
          if (_bootstrap == null) {
            _errorCode = 'platform_unavailable';
            _errorDetail = error.toString();
            _safeNotify();
          }
        },
      );
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
    } catch (error) {
      _errorCode = 'platform_unavailable';
      _errorDetail = error.toString();
    } finally {
      _loading = false;
      _safeNotify();
    }
    final boot = initialBoot;
    if (boot != null && boot.firstPermissionRun) {
      _scheduleFirstPermissionPrompt(boot);
    }
  }

  void _scheduleFirstPermissionPrompt(Bootstrap boot) {
    if (_initialPromptScheduled) return;
    _initialPromptScheduled = true;
    if (boot.permissions.ready) {
      unawaited(_markPermissionsPrompted());
    } else {
      unawaited(_runFirstPermissionPrompt());
    }
  }

  Future<void> _runFirstPermissionPrompt() async {
    await requestPermissions();
    await _markPermissionsPrompted();
  }

  Future<void> _markPermissionsPrompted() async {
    try {
      await _gateway.markPermissionsPrompted();
    } on BeatCastException catch (_) {
      // A failed flag write should not break the permission flow.
    }
  }

  Future<void> refresh() async {
    try {
      final boot = await _gateway.bootstrap();
      _applyBootstrap(boot);
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
      _safeNotify();
    } catch (_) {
      // Keep the last known state; a transient platform error should not
      // erase the running broadcast from the UI.
    }
  }

  /// Requests core permissions, then background sensor access. Safe to call
  /// repeatedly; Android returns immediately for already-granted permissions.
  Future<bool> requestPermissions() async {
    if (_busy) return permissions.ready;
    _busy = true;
    _errorCode = null;
    _safeNotify();
    try {
      var boot = await _gateway.requestCorePermissions();
      _bootstrap = boot;
      _safeNotify();

      if (!boot.permissions.backgroundSensorGranted &&
          boot.permissions.backgroundSupported) {
        boot = await _gateway.requestBackgroundPermission();
        _bootstrap = boot;
      }
      if (!boot.permissions.ready) {
        _errorCode = boot.permissions.backgroundSensorGranted
            ? 'permissions_missing'
            : 'background_permission';
      }
      return boot.permissions.ready;
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
      return false;
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  Future<bool> requestBackgroundPermission() async {
    if (_busy) return permissions.backgroundSensorGranted;
    _busy = true;
    _errorCode = null;
    _safeNotify();
    try {
      final boot = await _gateway.requestBackgroundPermission();
      _bootstrap = boot;
      if (!boot.permissions.backgroundSensorGranted) {
        _errorCode = 'background_permission';
      }
      return boot.permissions.backgroundSensorGranted;
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
      return false;
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  Future<bool> start() async {
    if (_busy || isRunning) return isRunning;
    _busy = true;
    _errorCode = null;
    _safeNotify();
    try {
      var boot = await _gateway.bootstrap();
      _bootstrap = boot;
      _safeNotify();

      if (!boot.permissions.ready) {
        if (boot.permissions.coreGranted) {
          boot = await _gateway.requestBackgroundPermission();
        } else {
          boot = await _gateway.requestCorePermissions();
          if (!boot.permissions.backgroundSensorGranted &&
              boot.permissions.backgroundSupported) {
            boot = await _gateway.requestBackgroundPermission();
          }
        }
        _bootstrap = boot;
        _safeNotify();
      }

      if (!boot.permissions.ready) {
        _errorCode = boot.permissions.backgroundSensorGranted
            ? 'permissions_missing'
            : 'background_permission';
        return false;
      }

      if (!boot.bluetoothEnabled) {
        _errorCode = 'bluetooth_off';
        return false;
      }
      if (!boot.advertisingSupported) {
        _errorCode = 'advertising_unsupported';
        return false;
      }

      final result = await _gateway.startBroadcast();
      if (!result.ok) {
        _errorCode = result.error ?? 'service_start_failed';
        _errorDetail = result.detail;
        return false;
      }
      _errorCode = null;
      _errorDetail = null;
      return true;
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
      return false;
    } catch (error) {
      _errorCode = 'service_start_failed';
      _errorDetail = error.toString();
      return false;
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  Future<void> stop() async {
    if (_busy) return;
    _busy = true;
    _safeNotify();
    try {
      await _gateway.stopBroadcast();
      _errorCode = null;
      _errorDetail = null;
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
    } finally {
      _busy = false;
      _safeNotify();
      // The native onDestroy state event can race the method result.
      unawaited(refresh());
    }
  }

  Future<void> updateSettings(BroadcastSettings next) async {
    final previous = settings;
    _bootstrap = (_bootstrap ?? const Bootstrap()).copyWith(settings: next);
    _safeNotify();
    try {
      final saved = await _gateway.updateSettings(next);
      _bootstrap = (_bootstrap ?? const Bootstrap()).copyWith(settings: saved);
    } on BeatCastException catch (error) {
      _bootstrap = (_bootstrap ?? const Bootstrap()).copyWith(settings: previous);
      _errorCode = error.code;
      _errorDetail = error.detail;
    } finally {
      _safeNotify();
    }
  }

  Future<void> openAppSettings() async {
    await _guard(() => _gateway.openAppSettings());
  }

  Future<void> openBluetoothSettings() async {
    await _guard(() => _gateway.openBluetoothSettings());
  }

  Future<void> requestEnableBluetooth() async {
    await _guard(() async {
      await _gateway.requestEnableBluetooth();
      await refresh();
    });
  }

  void dismissError() {
    _errorCode = null;
    _errorDetail = null;
    _safeNotify();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on BeatCastException catch (error) {
      _errorCode = error.code;
      _errorDetail = error.detail;
      _safeNotify();
    }
  }

  void _onBootstrapEvent(Bootstrap boot) {
    _applyBootstrap(boot);
  }

  void _applyBootstrap(Bootstrap boot) {
    _bootstrap = boot;
    _loading = false;
    if (boot.permissions.ready &&
        (_errorCode == 'permissions_missing' ||
            _errorCode == 'background_permission' ||
            _errorCode == 'permissions_revoked')) {
      _errorCode = null;
      _errorDetail = null;
    }
    _safeNotify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
