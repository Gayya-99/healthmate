import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/health_controller.dart';
import 'database/database_helper.dart';
import 'views/dashboard_screen.dart';
import 'views/record_form_screen.dart';
import 'views/record_list_screen.dart';

/// HealthMate – Personal Health & Wellness Tracker.
///
/// Architecture (MVC + Provider):
///   models/       -> HealthRecord (data)
///   database/     -> DatabaseHelper (storage)
///   controllers/  -> HealthController (state + logic, ChangeNotifier)
///   views/        -> screens
///   widgets/      -> reusable UI components
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HealthMateApp(database: DatabaseHelper.instance));
}

class HealthMateApp extends StatelessWidget {
  const HealthMateApp({super.key, required this.database, this.clock});

  final DatabaseHelper database;

  /// Optional fixed "now" (used by tests).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    // The controller is created once and shared with every screen.
    return ChangeNotifierProvider(
      create: (_) => HealthController(database, clock: clock)..loadData(),
      child: Consumer<HealthController>(
        builder: (context, controller, _) => MaterialApp(
          title: 'HealthMate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          // Keep layouts stable on phones that use a very large system
          // font size: text can still grow, but only up to 115%.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.15,
                ),
              ),
              child: child!,
            );
          },
          home: const HomeShell(),
        ),
      ),
    );
  }
}

/// Main layout: app bar, bottom navigation and "Add entry" button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const RecordFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = context.watch<HealthController>();

    return Scaffold(
      appBar: AppBar(
        title: _index == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('HealthMate'),
                ],
              )
            : const Text('Health Records'),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Theme',
            icon: Icon(
              switch (controller.themeMode) {
                ThemeMode.light => Icons.light_mode_rounded,
                ThemeMode.dark => Icons.dark_mode_rounded,
                ThemeMode.system => Icons.brightness_auto_rounded,
              },
            ),
            initialValue: controller.themeMode,
            onSelected: controller.setThemeMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
          if (_index == 1) const RecordsMenuButton(),
          // 8px + the 12px inside each icon button = 20px, the same side
          // margin as the page content, so icons line up with the cards.
          const SizedBox(width: 8),
        ],
      ),
      // IndexedStack keeps each tab alive (scroll position, filters).
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSeeAllRecords: () => _goTo(1)),
          const RecordListScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-entry-fab'),
        onPressed: _addEntry,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Records',
          ),
        ],
      ),
    );
  }
}

/// Material 3 light and dark themes. Teal brand colour (health/wellbeing)
/// that does not clash with the metric colours (green, red, blue).
class AppTheme {
  AppTheme._();

  static const Color brandColor = Color(0xFF00897B);

  /// Bundled in assets/fonts and registered in pubspec.yaml.
  static const String fontFamily = 'Alexandria';
  static const Color lightBackground = Color(0xFFF4F7F6);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final background = isDark ? scheme.surface : lightBackground;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        titleSpacing: 20, // same left margin as the page content
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.transparent : const Color(0xFFE6ECEA),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHighest : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: isDark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }
}
