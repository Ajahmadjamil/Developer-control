import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/app_controller.dart';
import '../../../controllers/developer_settings_controller.dart';
import '../../../controllers/lock_widget_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeveloperSettingsController>().init();
      context.read<LockWidgetController>().init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DeveloperSettingsController>().refreshStatus();
      context.read<LockWidgetController>().refreshStatus();
    }
  }

  void _showMessage(String? message, VoidCallback clear) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    clear();
  }

  String _formatMinutes(int total) {
    final h = (total ~/ 60).toString().padLeft(2, '0');
    final m = (total % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickScheduleTime(
    BuildContext context,
    DeveloperSettingsController controller, {
    required bool isStart,
  }) async {
    final initial = TimeOfDay(
      hour: isStart ? controller.schedule.startHour : controller.schedule.endHour,
      minute: isStart
          ? controller.schedule.startMinute
          : controller.schedule.endMinute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyan,
              surface: AppColors.panelSolid,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    if (isStart) {
      await controller.setScheduleStart(picked);
    } else {
      await controller.setScheduleEnd(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeveloperSettingsController, LockWidgetController>(
      builder: (context, controller, lock, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMessage(controller.message, controller.clearMessage);
          _showMessage(lock.message, lock.clearMessage);
        });

        final scheduleOn = controller.schedule.enabled;
        final modeOn = controller.combineToggles
            ? controller.combinedActive
            : (controller.developerOptionsEnabled &&
                controller.usbDebuggingEnabled);

        return GlassBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(AppConstants.appName),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: controller.loading || controller.busy
                      ? null
                      : controller.refreshStatus,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Setup / ADB grant',
                  onPressed: () =>
                      context.read<AppController>().openSetupAgain(),
                  icon: const Icon(Icons.terminal_rounded),
                ),
              ],
            ),
            body: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: AppColors.cyan,
                    backgroundColor: AppColors.panelSolid,
                    onRefresh: controller.refreshStatus,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                      children: [
                        _HeroHeader(
                          hasPermission: controller.hasSecurePermission,
                        ),
                        const SizedBox(height: 22),

                        // ═══ FEATURE 1: Developer Mode (toggle + schedule + QS) ═══
                        _FeatureShell(
                          icon: Icons.developer_mode_rounded,
                          title: 'Developer Mode',
                          blurb:
                              'Turn Developer Options & USB Debugging on or off. '
                              'Schedule it for later, or add a tile in the notification shade.',
                          statusLabel: modeOn ? 'CURRENTLY ON' : 'CURRENTLY OFF',
                          statusActive: modeOn,
                          highlighted: modeOn || scheduleOn,
                          children: [
                            _StepHeader(
                              step: '1',
                              title: 'Control now',
                              caption: 'Flip settings from this app',
                            ),
                            _InsetBox(
                              child: Column(
                                children: [
                                  _SwitchLine(
                                    title: 'One switch for both',
                                    subtitle:
                                        'Developer Options + USB Debugging together',
                                    value: controller.combineToggles,
                                    onChanged: controller.busy
                                        ? null
                                        : controller.setCombineToggles,
                                  ),
                                  const _Hairline(),
                                  if (controller.combineToggles)
                                    _StatusSwitchLine(
                                      title: 'Developer Mode',
                                      subtitle: 'Both settings at once',
                                      value: controller.combinedActive,
                                      onChanged: controller.busy
                                          ? null
                                          : controller.setCombinedMode,
                                    )
                                  else ...[
                                    _StatusSwitchLine(
                                      title: 'Developer Options',
                                      subtitle: 'Android developer tools menu',
                                      value:
                                          controller.developerOptionsEnabled,
                                      onChanged: controller.busy
                                          ? null
                                          : controller.setDeveloperOptions,
                                    ),
                                    const _Hairline(),
                                    _StatusSwitchLine(
                                      title: 'USB Debugging',
                                      subtitle: 'PC can connect over USB / ADB',
                                      value: controller.usbDebuggingEnabled,
                                      onChanged: controller.busy
                                          ? null
                                          : controller.setUsbDebugging,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StepHeader(
                              step: '2',
                              title: 'Daily schedule',
                              caption:
                                  'Auto on/off by time — your manual flips still work until the next alarm',
                            ),
                            _InsetBox(
                              child: Column(
                                children: [
                                  _SwitchLine(
                                    title: 'Use daily schedule',
                                    subtitle: controller.hasSecurePermission
                                        ? 'Runs on this phone only'
                                        : 'Needs 1-click ADB permission first',
                                    value: scheduleOn,
                                    onChanged: controller.busy
                                        ? null
                                        : controller.setScheduleEnabled,
                                  ),
                                  if (scheduleOn) ...[
                                    const _Hairline(),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        12,
                                        4,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _TimeButton(
                                              label: 'ON at',
                                              time: _formatMinutes(
                                                controller
                                                    .schedule.startMinutes,
                                              ),
                                              onTap: controller.busy
                                                  ? null
                                                  : () => _pickScheduleTime(
                                                        context,
                                                        controller,
                                                        isStart: true,
                                                      ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: AppColors.textMuted
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                          Expanded(
                                            child: _TimeButton(
                                              label: 'OFF at',
                                              time: _formatMinutes(
                                                controller.schedule.endMinutes,
                                              ),
                                              onTap: controller.busy
                                                  ? null
                                                  : () => _pickScheduleTime(
                                                        context,
                                                        controller,
                                                        isStart: false,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 4,
                                        right: 4,
                                        bottom: 8,
                                      ),
                                      child: _SoftTip(
                                        'Overnight is fine — e.g. ON 22:00, OFF 08:00.',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StepHeader(
                              step: '3',
                              title: 'Notification shade',
                              caption:
                                  'Same Dev Mode control from the quick tiles (swipe down)',
                            ),
                            _InsetBox(
                              child: _LinkLine(
                                title: 'Add Dev Mode tile',
                                subtitle:
                                    'Shows next to Wi‑Fi / Bluetooth on Android 13+',
                                onTap: controller.busy
                                    ? null
                                    : controller.addQuickSettingsTile,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ═══ FEATURE 2: Tap to Lock ═══
                        _FeatureShell(
                          icon: Icons.lock_rounded,
                          title: 'Tap to Lock',
                          blurb:
                              'A separate home-screen widget. Tap the grey lock icon to lock your phone — works even when this app is closed.',
                          statusLabel:
                              lock.enabled ? 'WIDGET ON' : 'WIDGET OFF',
                          statusActive: lock.enabled,
                          highlighted: lock.enabled,
                          children: [
                            _InsetBox(
                              child: Column(
                                children: [
                                  _SwitchLine(
                                    title: 'Show lock on home screen',
                                    subtitle: lock.hasPermission
                                        ? 'Device Admin ready — pin the widget if asked'
                                        : 'Asks for Device Admin, then pins the widget',
                                    value: lock.enabled,
                                    onChanged:
                                        lock.busy ? null : lock.setEnabled,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      left: 4,
                                      right: 4,
                                      bottom: 10,
                                    ),
                                    child: _SoftTip(
                                      'Transparent widget · grey lock icon · no Accessibility button.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (controller.busy || lock.busy) ...[
                          const SizedBox(height: 28),
                          const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// ─── Feature shell ───────────────────────────────────────────────────────────

class _FeatureShell extends StatelessWidget {
  const _FeatureShell({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.statusLabel,
    required this.statusActive,
    required this.children,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String blurb;
  final String statusLabel;
  final bool statusActive;
  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: highlighted,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.cyanBright, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      blurb,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusActive
                  ? AppColors.cyan.withValues(alpha: 0.14)
                  : AppColors.border.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusActive ? AppColors.cyan : AppColors.border,
              ),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusActive
                    ? AppColors.cyanBright
                    : AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.caption,
  });

  final String step;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.cyanBright,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsetBox extends StatelessWidget {
  const _InsetBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.voidBlack.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: child,
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StatusSwitchLine extends StatelessWidget {
  const _StatusSwitchLine({
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: value ? AppColors.cyan : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: value ? AppColors.cyanBright : AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    this.onTap,
  });

  final String label;
  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelSolid.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.cyanBright,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkLine extends StatelessWidget {
  const _LinkLine({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftTip extends StatelessWidget {
  const _SoftTip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: AppColors.textMuted.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.hasPermission});

  final bool hasPermission;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: hasPermission,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasPermission
                  ? AppColors.cyan.withValues(alpha: 0.16)
                  : AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasPermission ? AppColors.cyan : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasPermission ? Icons.bolt_rounded : Icons.link_off_rounded,
                  size: 14,
                  color: hasPermission
                      ? AppColors.cyanBright
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  hasPermission ? 'READY' : 'SETUP NEEDED',
                  style: TextStyle(
                    color: hasPermission
                        ? AppColors.cyanBright
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasPermission
                ? 'Two features below: Developer Mode (toggle, schedule, shade tile) and Tap to Lock.'
                : 'Without the ADB grant, Developer Mode opens Settings pages instead of switching instantly.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
