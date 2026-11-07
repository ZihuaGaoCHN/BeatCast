import 'package:flutter/widgets.dart';

import '../core/models/broadcast_models.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode == 'zh';

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

  String get appName => 'BeatCast';
  String get wordmark => 'BEATCAST';

  String get bpm => 'BPM';
  String get waiting => isZh ? '等待读数' : 'WAITING';
  String get streaming => isZh ? '正在广播' : 'STREAMING';
  String get readyToPair => isZh ? '等待配对' : 'READY TO PAIR';
  String get starting => isZh ? '正在启动…' : 'STARTING…';
  String get connected => isZh ? '已连接' : 'CONNECTED';
  String get noContact => isZh ? '请戴紧手表' : 'WEAR IT SNUGGLY';

  String get startBroadcast => isZh ? '开始广播' : 'Start broadcast';
  String get stopBroadcast => isZh ? '停止广播' : 'Stop broadcast';
  String get setUpAndStart => isZh ? '完成设置并开始' : 'Set up & start';
  String get startingService => isZh ? '正在启动…' : 'Starting…';
  String get stoppingService => isZh ? '正在停止…' : 'Stopping…';

  String get settings => isZh ? '设置' : 'Settings';
  String get back => isZh ? '返回' : 'Back';
  String get close => isZh ? '关闭' : 'Close';
  String get done => isZh ? '完成' : 'Done';
  String get retry => isZh ? '重试' : 'Try again';
  String get openSettings => isZh ? '打开设置' : 'Open settings';
  String get openAppSettings => isZh ? '打开系统应用设置' : 'Open app settings';
  String get turnOnBluetooth => isZh ? '打开蓝牙' : 'Turn on Bluetooth';

  String connectedCount(int count) {
    if (isZh) return '已连接 $count 台设备';
    return count == 1 ? '1 device connected' : '$count devices connected';
  }

  String battery(int percent) => isZh ? '电量 $percent%' : 'Battery $percent%';

  String get tapToPair =>
      isZh ? '在健身设备上添加心率传感器' : 'Add a heart-rate sensor on your equipment';
  String get screenCanSleep =>
      isZh ? '屏幕可熄灭' : 'Screen can sleep';
  String get standardHr =>
      isZh ? '标准 BLE 心率传感器 · 无需手机' : 'Standard BLE heart rate · No phone needed';
  String get watchNameFallback => isZh ? 'Wear OS 手表' : 'Wear OS watch';

  String get permissionsTitle => isZh ? '权限' : 'Permissions';
  String get bluetoothOff => isZh ? '蓝牙已关闭。' : 'Bluetooth is off.';
  String get bluetoothOffHint =>
      isZh ? '打开蓝牙后即可开始广播。' : 'Turn it on to start broadcasting.';

  String get settingsTitle => isZh ? '设置' : 'Settings';
  String get powerSection => isZh ? '功耗' : 'POWER';
  String get broadcastSection => isZh ? '广播' : 'BROADCAST';
  String get aboutSection => isZh ? '关于' : 'ABOUT';
  String get autoStopTitle => isZh ? '空闲自动停止' : 'Auto-stop when idle';
  String get autoStopShort => isZh ? '无设备时停止' : 'Stop when idle';
  String get autoStopSubtitle =>
      isZh ? '空闲时自动省电。' : 'Save power when idle.';
  String autoStopLabel(int minutes) {
    if (minutes <= 0) return isZh ? '从不' : 'Never';
    return isZh ? '$minutes 分钟' : '$minutes min';
  }

  String get sessionTitle => isZh ? '总时长上限' : 'Max duration';
  String get sessionLimitHint => isZh
      ? '「无设备时停止」在最后一个设备断开后开始计时；「总时长上限」从开始广播起计时，到时强制停止。'
      : '“Stop when idle” starts after the last device disconnects; “Max duration” counts from broadcast start and stops at the limit.';
  String get sessionShort => isZh ? '最长时长' : 'Session limit';
  String get sessionSubtitle =>
      isZh ? '到时自动停止。' : 'Auto-stop after the limit.';
  String sessionLabel(int minutes) {
    if (minutes <= 0) return isZh ? '不限制' : 'No limit';
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return isZh ? '$hours 小时' : '$hours h';
    }
    return isZh ? '$minutes 分钟' : '$minutes min';
  }

  String get advertisingTitle => isZh ? '广播模式' : 'Advertising mode';
  String get advertisingShort => isZh ? '广播模式' : 'Advertising';
  String get advertisingSubtitle =>
      isZh ? '速度与续航的平衡。' : 'Speed vs. battery life.';
  String get balanced => isZh ? '均衡' : 'Balanced';
  String get balancedBody =>
      isZh ? '更快被设备发现，推荐日常使用。' : 'Faster discovery. Recommended.';
  String get lowPower => isZh ? '低功耗' : 'Low power';
  String get lowPowerBody =>
      isZh ? '广播间隔更长，更省电。' : 'Longer advertising interval, less drain.';
  String advertisingModeLabel(AdvertisingMode mode) =>
      mode == AdvertisingMode.lowPower ? lowPower : balanced;

  String get broadcastNameTitle => isZh ? '广播名称' : 'Broadcast name';
  String get broadcastNameSubtitle => isZh
      ? '使用手表当前的蓝牙名称。'
      : 'Uses your watch’s current Bluetooth name.';
  String get systemSettings => isZh ? '系统应用设置' : 'System app settings';
  String get systemSettingsSubtitle =>
      isZh ? '权限、通知与电池优化。' : 'Permissions, notifications and battery.';
  String get aboutTitle => isZh ? '关于 BeatCast' : 'About BeatCast';
  String get aboutSubtitle =>
      isZh ? '本地运行，不上传任何健康数据。' : 'Runs locally. No health data leaves the watch.';
  String get aboutBody => isZh
      ? 'BeatCast 把手表变成标准 BLE 心率传感器。数据只在手表与健身设备之间传输。'
      : 'BeatCast turns your watch into a standard BLE heart-rate sensor. Data only travels between the watch and your equipment.';
  String versionLabel(String version) => isZh ? '版本 $version' : 'Version $version';
  String get powerNote => isZh
      ? '设备连接后才启动传感器，断开后休眠。'
      : 'Sensor starts only after a device connects.';

  String get errorTitle => isZh ? '出了点问题' : 'Something went wrong';
  String get errorGeneric =>
      isZh ? '操作没有完成，请重试。' : 'That did not complete. Please try again.';
  String get errorPlatform => isZh
      ? '手表的原生服务不可用，请重新打开 BeatCast。'
      : 'The watch service is unavailable. Reopen BeatCast.';
  String get errorPermissions =>
      isZh ? '权限不完整，无法开始广播。' : 'Permissions are incomplete, so broadcasting cannot start.';
  String get errorBackgroundPermission => isZh
      ? '请把传感器权限设为“始终允许”，否则熄屏后会停止。'
      : 'Allow sensor access all the time, otherwise streaming stops when the screen sleeps.';
  String get errorBluetoothOff => isZh ? '蓝牙已关闭。' : 'Bluetooth is turned off.';
  String get errorBluetoothUnavailable =>
      isZh ? '这台手表没有可用的蓝牙。' : 'Bluetooth is unavailable on this watch.';
  String get errorAdvertisingUnsupported => isZh
      ? '这台手表不支持 BLE 外设广播。'
      : 'This watch does not support Bluetooth LE peripheral advertising.';
  String get errorAdvertisingFailed => isZh
      ? '手表无法开始广播。请关闭蓝牙再打开，然后重试。'
      : 'The watch could not start advertising. Toggle Bluetooth and try again.';
  String get errorSensorUnavailable =>
      isZh ? '没有找到心率传感器。' : 'No heart-rate sensor was found.';
  String get errorSensorPermission =>
      isZh ? '心率传感器权限被拒绝。' : 'Heart-rate sensor permission was denied.';
  String get errorSensorRegister =>
      isZh ? '心率传感器无法启动。' : 'The heart-rate sensor could not start.';
  String get errorServiceStart => isZh
      ? 'Android 阻止了广播服务启动，请从应用内重试。'
      : 'Android blocked the broadcast service. Try again from the app.';
  String get errorServiceAdd =>
      isZh ? '蓝牙心率服务注册失败。' : 'The Bluetooth Heart Rate Service failed to register.';
  String get errorGatt =>
      isZh ? '无法创建蓝牙服务。' : 'Could not create the Bluetooth GATT server.';
  String get errorPermissionDenied => isZh ? '权限被拒绝。' : 'Permission was denied.';
  String get errorBusy =>
      isZh ? '另一个权限请求正在进行。' : 'Another permission request is already open.';

  String errorFor(String? code) {
    if (code == null) return errorGeneric;
    if (code.startsWith('advertising_failed')) return errorAdvertisingFailed;
    return switch (code) {
      'platform_unavailable' ||
      'invalid_platform_response' ||
      'empty_platform_response' =>
        errorPlatform,
      'permissions_missing' || 'permissions_revoked' => errorPermissions,
      'background_permission' => errorBackgroundPermission,
      'bluetooth_off' => errorBluetoothOff,
      'bluetooth_unavailable' => errorBluetoothUnavailable,
      'advertising_unsupported' => errorAdvertisingUnsupported,
      'sensor_unavailable' => errorSensorUnavailable,
      'sensor_permission' => errorSensorPermission,
      'sensor_register_failed' => errorSensorRegister,
      'gatt_server_failed' => errorGatt,
      'service_add_failed' => errorServiceAdd,
      'service_start_failed' ||
      'permission_denied' ||
      'foreground_start_failed' => errorServiceStart,
      'permission_request_busy' => errorBusy,
      _ => errorGeneric,
    };
  }
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
