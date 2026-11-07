import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/broadcast_controller.dart';
import '../../core/theme/app_motion.dart';
import '../../l10n/app_strings.dart';
import '../../shared/widgets/beat_button.dart';
import '../../shared/widgets/live_badge.dart';
import '../../shared/widgets/watch_scaffold.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.controller});

  final BroadcastController controller;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _working = false;
  String? _localError;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final s = context.strings;
        final permissions = widget.controller.permissions;
        final ready = permissions.ready;
        final compact = MediaQuery.sizeOf(context).shortestSide < 300;

        return WatchScaffold(
          child: Column(
            children: [
              PageHeader(title: s.permissionsTitle),
              const SizedBox(height: 2),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!compact) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.permissionsIntro,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 10.5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            LiveBadge(
                              label: ready
                                  ? s.permissionGranted
                                  : s.permissionNeeded,
                              tone: ready
                                  ? LiveBadgeTone.live
                                  : LiveBadgeTone.waiting,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      _PermissionRow(
                        icon: Icons.favorite_rounded,
                        title: s.sensorTitle,
                        body: s.sensorBody,
                        granted: permissions.sensorGranted,
                        compact: compact,
                      ),
                      _PermissionRow(
                        icon: Icons.bluetooth_rounded,
                        title: s.bluetoothTitle,
                        body: s.bluetoothBody,
                        granted: permissions.bluetoothGranted,
                        compact: compact,
                      ),
                      _PermissionRow(
                        icon: Icons.nightlight_round,
                        title: s.backgroundTitle,
                        body: s.backgroundBody,
                        granted: permissions.backgroundSensorGranted,
                        accent: !permissions.backgroundSensorGranted,
                        compact: compact,
                      ),
                      if (!compact)
                        _NotificationLine(
                          title: s.notificationsTitle,
                          body: s.notificationsBody,
                          granted: permissions.notificationsGranted,
                        ),
                      if (!ready &&
                          permissions.coreGranted &&
                          permissions.backgroundSupported) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.backgroundPermissionHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: 9.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.controller.openAppSettings,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              child: Text(s.openSettings),
                            ),
                          ],
                        ),
                      ],
                      if (permissions.bluetoothGranted &&
                          !widget.controller.bluetoothEnabled) ...[
                        const SizedBox(height: 6),
                        _InlineNotice(
                          icon: Icons.bluetooth_disabled_rounded,
                          text: s.bluetoothOffHint,
                          actionLabel: s.turnOnBluetooth,
                          onAction: _turnOnBluetooth,
                        ),
                      ],
                      if (!widget.controller.advertisingSupported) ...[
                        const SizedBox(height: 6),
                        _InlineNotice(
                          icon: Icons.portable_wifi_off_rounded,
                          text: s.errorAdvertisingUnsupported,
                        ),
                      ],
                      if (_localError != null && !ready) ...[
                        const SizedBox(height: 6),
                        Text(
                          s.errorFor(_localError),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 3 : 4),
              BeatButton(
                label: ready
                    ? s.startBroadcast
                    : permissions.coreGranted
                        ? s.allowBackground
                        : s.grantAccess,
                icon: ready
                    ? Icons.play_arrow_rounded
                    : permissions.coreGranted
                        ? Icons.shield_outlined
                        : Icons.lock_open_rounded,
                busy: _working || widget.controller.busy,
                onPressed: _primaryAction,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _primaryAction() async {
    if (_working || widget.controller.busy) return;
    HapticFeedback.selectionClick();
    if (widget.controller.permissions.ready) {
      setState(() => _localError = null);
      final ok = await widget.controller.start();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _localError =
            widget.controller.errorCode ?? 'service_start_failed');
      }
      return;
    }

    setState(() {
      _working = true;
      _localError = null;
    });
    try {
      if (!widget.controller.permissions.coreGranted) {
        await widget.controller.requestPermissions();
      } else {
        await widget.controller.requestBackgroundPermission();
      }
      if (!mounted) return;
      setState(() {
        _localError = widget.controller.permissions.ready
            ? null
            : widget.controller.errorCode ?? 'permissions_missing';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _turnOnBluetooth() async {
    await widget.controller.requestEnableBluetooth();
    if (!mounted) return;
    setState(() {});
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.granted,
    this.accent = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool granted;
  final bool accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = granted
        ? scheme.secondary
        : (accent ? scheme.primary : scheme.onSurfaceVariant);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppMotion.base,
            width: compact ? 22 : 27,
            height: compact ? 22 : 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 12 : 15, color: color),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 11.2 : 12.5,
                      ),
                ),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: compact ? 8.5 : 9.2,
                        height: 1.1,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            granted ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: compact ? 14 : 16,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _NotificationLine extends StatelessWidget {
  const _NotificationLine({
    required this.title,
    required this.body,
    required this.granted,
  });

  final String title;
  final String body;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = granted ? scheme.secondary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 2, 0, 2),
      child: Row(
        children: [
          Icon(
            granted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              granted ? title : '$title · ${body.toLowerCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 8.8,
                    color: color,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 8, 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.secondary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: Theme.of(context).textTheme.labelSmall,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
