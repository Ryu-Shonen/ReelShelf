import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'add_movie_screen.dart';
import 'barcode_scanner_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'wishlist_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  Future<void> _openAdd({String? barcode}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMovieScreen(initialBarcode: barcode),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    await _openAdd(barcode: code);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final titles = ['Meine Sammlung', 'Wunschliste', 'Statistik'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          if (_index != 2)
            IconButton(
              tooltip: 'Barcode scannen',
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: state.initialized
          ? IndexedStack(
              index: _index,
              children: [
                LibraryView(onAdd: _openAdd),
                WishlistView(onAdd: _openAdd),
                const StatsView(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Film'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Sammlung',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Wunschliste',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Statistik',
          ),
        ],
      ),
    );
  }
}
