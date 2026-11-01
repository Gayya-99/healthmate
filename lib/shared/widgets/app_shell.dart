import 'package:flutter/material.dart';

import '../../features/dashboard/views/screens/dashboard_screen.dart';
import '../../features/health_records/views/screens/add_edit_record_screen.dart';
import '../../features/health_records/views/screens/records_screen.dart';
import '../../features/settings/views/settings_screen.dart';

/// Main layout: app bar, bottom navigation and the "Add entry" button.
///
/// [IndexedStack] keeps each tab alive, so scroll position and filters are
/// preserved when switching tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['HealthMate', 'Health Records', 'Settings'];

  void _goTo(int index) => setState(() => _index = index);

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const AddEditRecordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _index == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(_titles[_index]),
                ],
              )
            : Text(_titles[_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSeeAllRecords: () => _goTo(1)),
          const RecordsScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
