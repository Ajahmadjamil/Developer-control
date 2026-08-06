import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/app_controller.dart';
import '../../../controllers/developer_settings_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import 'widgets/status_toggle_card.dart';

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
    }
  }

  void _showMessage(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    context.read<DeveloperSettingsController>().clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeveloperSettingsController>(
      builder: (context, controller, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMessage(controller.message);
        });

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
                        const SizedBox(height: 20),
                        const _SectionLabel('CONTROLS'),
                        const SizedBox(height: 10),
                        if (controller.combineToggles)
                          StatusToggleCard(
                            title: 'Developer Mode',
                            subtitle: 'Options + USB Debugging',
                            value: controller.combinedActive,
                            icon: Icons.developer_mode_rounded,
                            enabled: !controller.busy,
                            onChanged: controller.setCombinedMode,
                          )
                        else ...[
                          StatusToggleCard(
                            title: 'Developer Options',
                            subtitle: 'development_settings_enabled',
                            value: controller.developerOptionsEnabled,
                            icon: Icons.construction_outlined,
                            enabled: !controller.busy,
                            onChanged: controller.setDeveloperOptions,
                          ),
                          const SizedBox(height: 12),
                          StatusToggleCard(
                            title: 'USB Debugging',
                            subtitle: 'adb_enabled',
                            value: controller.usbDebuggingEnabled,
                            icon: Icons.usb_rounded,
                            enabled: !controller.busy,
                            onChanged: controller.setUsbDebugging,
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _SectionLabel('OPTIONS'),
                        const SizedBox(height: 10),
                        _OptionRow(
                          icon: Icons.merge_type_rounded,
                          title: 'Combine into one toggle',
                          subtitle: 'Single switch for both settings',
                          trailing: Switch(
                            value: controller.combineToggles,
                            onChanged: controller.busy
                                ? null
                                : controller.setCombineToggles,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _OptionRow(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Quick Settings tile',
                          subtitle: 'Add Dev Mode to the notification shade',
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                          onTap: controller.busy
                              ? null
                              : controller.addQuickSettingsTile,
                        ),
                        if (controller.busy) ...[
                          const SizedBox(height: 28),
                          const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.cyan,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
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
          Row(
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
                      hasPermission
                          ? Icons.bolt_rounded
                          : Icons.link_off_rounded,
                      size: 14,
                      color: hasPermission
                          ? AppColors.cyanBright
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPermission ? '1-CLICK ARMED' : 'SHORTCUT MODE',
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
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasPermission
                ? 'Secure settings unlocked. Flip switches for instant control.'
                : 'ADB grant missing. Switches open the exact Settings pages.',
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

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.cyanBright, size: 22),
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
          trailing,
        ],
      ),
    );
  }
}
