import 'package:flutter/material.dart';

import 'app.dart';
import 'features/health_records/data/repositories/in_memory_health_record_repository.dart';
import 'features/settings/data/settings_repository.dart';

/// Entry point.
///
/// The repositories are created here and injected into the app. This build
/// keeps data in memory (frontend only). To add SQLite later, create a
/// sqflite repository that implements `HealthRecordRepository` and pass it
/// here instead – no screen or view model needs to change.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    HealthMateApp(
      recordRepository: InMemoryHealthRecordRepository(),
      settingsRepository: InMemorySettingsRepository(),
    ),
  );
}
