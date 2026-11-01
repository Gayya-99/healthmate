import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/viewmodel/dashboard_view_model.dart';
import 'features/health_records/data/repositories/health_record_repository.dart';
import 'features/health_records/viewmodel/health_record_view_model.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/viewmodel/settings_view_model.dart';
import 'shared/widgets/app_shell.dart';

/// Root widget. Sets up dependency injection and state management.
///
/// Provider tree:
/// * [SettingsViewModel]      – goals + theme (ChangeNotifier)
/// * [HealthRecordViewModel]  – records, CRUD, filters (ChangeNotifier)
/// * [DashboardViewModel]     – derived from the two above (ProxyProvider2),
///   so the dashboard updates automatically after any CRUD or goal change.
class HealthMateApp extends StatelessWidget {
  const HealthMateApp({
    super.key,
    required this.recordRepository,
    required this.settingsRepository,
    this.clock,
  });

  final HealthRecordRepository recordRepository;
  final SettingsRepository settingsRepository;

  /// Optional fixed "now" (used by widget tests).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(settingsRepository)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              HealthRecordViewModel(recordRepository, clock: clock)
                ..loadRecords(),
        ),
        ProxyProvider2<HealthRecordViewModel, SettingsViewModel,
            DashboardViewModel>(
          update: (context, records, settings, previous) => DashboardViewModel(
            records: records.allRecords,
            goals: settings.goals,
            now: (clock ?? DateTime.now)(),
          ),
        ),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settings, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
