import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const breathe = Duration(milliseconds: 2800);

  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const springy = Cubic(0.34, 1.56, 0.64, 1.0);
}

abstract final class AppDurations {
  static String clock(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}
