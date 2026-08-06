import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _copyCommand(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.adbGrantCommand),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ADB command copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        if (app.message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final msg = app.message;
            if (msg == null) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(msg)));
            app.clearMessage();
          });
        }

        return GlassBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.cyan.withValues(alpha: 0.3),
                          AppColors.cyanDim.withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.developer_mode_rounded,
                      size: 34,
                      color: AppColors.cyanBright,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enable Developer Options and toggle USB Debugging '
                    'instantly on non-rooted Android.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassPanel(
                    highlighted: app.hasSecurePermission,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          app.hasSecurePermission
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          color: app.hasSecurePermission
                              ? AppColors.cyanBright
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            app.hasSecurePermission
                                ? 'WRITE_SECURE_SETTINGS granted. 1-click toggles are ready.'
                                : 'Permission not granted yet. Run the ADB command below once.',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.4,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'UNLOCK 1-CLICK',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Grant WRITE_SECURE_SETTINGS once from a PC with USB Debugging on.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(
                            AppConstants.adbGrantCommand,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              height: 1.45,
                              color: AppColors.cyanBright,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: () => _copyCommand(context),
                          icon: const Icon(Icons.copy_rounded),
                          color: AppColors.cyan,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Without this permission, the app still works via Settings shortcuts.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed:
                        app.checkingPermission ? null : app.recheckPermission,
                    icon: app.checkingPermission
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      app.checkingPermission
                          ? 'Checking…'
                          : 'I ran the command — recheck',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: app.finishOnboarding,
                    child: Text(
                      app.hasSecurePermission
                          ? 'Continue to dashboard'
                          : 'Continue with shortcuts',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
