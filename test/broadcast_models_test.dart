import 'package:beatcast/core/models/broadcast_models.dart';
import 'package:beatcast/core/theme/app_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BroadcastSnapshot', () {
    test('parses a native payload', () {
      final snapshot = BroadcastSnapshot.fromMap(const {
        'phase': 'live',
        'serviceRunning': true,
        'bpm': 72,
        'contact': true,
        'clients': 2,
        'advertising': true,
        'deviceName': 'Galaxy Watch 7',
        'batteryPercent': 64,
        'startedAtEpochMs': 1000,
        'lastSampleAtEpochMs': 2000,
        'sensorSource': 'raw_wakeup',
      });

      expect(snapshot.phase, BroadcastPhase.live);
      expect(snapshot.serviceRunning, isTrue);
      expect(snapshot.bpm, 72);
      expect(snapshot.clients, 2);
      expect(snapshot.deviceName, 'Galaxy Watch 7');
      expect(snapshot.batteryPercent, 64);
      expect(snapshot.uptime, isNot(Duration.zero));
    });

    test('falls back safely on malformed data', () {
      final snapshot = BroadcastSnapshot.fromMap(const {
        'phase': 'nonsense',
        'bpm': 'high',
        'clients': null,
      });
      expect(snapshot.phase, BroadcastPhase.idle);
      expect(snapshot.bpm, isNull);
      expect(snapshot.clients, 0);
      expect(snapshot.deviceName, 'Wear OS watch');
    });
  });

  group('BroadcastSettings', () {
    test('sanitizes unsupported values', () {
      final settings = BroadcastSettings.fromMap(const {
        'advertisingMode': 'low_power',
        'autoStopMinutes': 17,
        'maxSessionMinutes': 999,
      });
      expect(settings.advertisingMode, AdvertisingMode.lowPower);
      expect(settings.autoStopMinutes, 15);
      expect(settings.maxSessionMinutes, 0);
      expect(settings.toMap()['advertisingMode'], 'low_power');
    });
  });

  test('clock formats minutes and hours', () {
    expect(AppDurations.clock(const Duration(seconds: 9)), '00:09');
    expect(AppDurations.clock(const Duration(minutes: 12, seconds: 3)), '12:03');
    expect(
      AppDurations.clock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
