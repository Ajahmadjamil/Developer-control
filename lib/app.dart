import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/app_controller.dart';
import 'controllers/developer_settings_controller.dart';
import 'controllers/lock_widget_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'data/services/lock_widget_service.dart';
import 'data/services/preferences_service.dart';
import 'data/services/secure_settings_service.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class DeveloperControlApp extends StatelessWidget {
  const DeveloperControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SecureSettingsService>(
          create: (_) => SecureSettingsService(),
        ),
        Provider<LockWidgetService>(
          create: (_) => LockWidgetService(),
        ),
        Provider<PreferencesService>(
          create: (_) => PreferencesService(),
        ),
        ChangeNotifierProvider<AppController>(
          create: (context) => AppController(
            settings: context.read<SecureSettingsService>(),
            prefs: context.read<PreferencesService>(),
          )..bootstrap(),
        ),
        ChangeNotifierProvider<DeveloperSettingsController>(
          create: (context) => DeveloperSettingsController(
            settings: context.read<SecureSettingsService>(),
            prefs: context.read<PreferencesService>(),
          ),
        ),
        ChangeNotifierProvider<LockWidgetController>(
          create: (context) => LockWidgetController(
            lockWidget: context.read<LockWidgetService>(),
            prefs: context.read<PreferencesService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const AppRoot(),
      ),
    );
  }
}

/// Routes between splash → onboarding → dashboard via [AppController].
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        if (!app.ready) {
          return const GlassSplash();
        }
        if (app.showOnboarding) {
          return const OnboardingScreen();
        }
        return const DashboardScreen();
      },
    );
  }
}

class GlassSplash extends StatelessWidget {
  const GlassSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppConstants.logoAsset,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: AppColors.cyan),
          ],
        ),
      ),
    );
  }
}
