import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'add_movie_screen.dart';
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

  Future<void> _openAdd({
    bool wishlist = false,
    bool autoScanCover = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMovieScreen(
          initialWishlist: wishlist,
          autoScanCover: autoScanCover,
        ),
      ),
    );
  }

  Future<void> _openCollectionAdd() {
    return _openAdd(wishlist: false);
  }

  Future<void> _openWishlistAdd() {
    return _openAdd(wishlist: true);
  }

  Future<void> _scanCover() {
    return _openAdd(
      wishlist: _index == 1,
      autoScanCover: true,
    );
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
              tooltip: _index == 0 ? 'Film hinzufügen' : 'Film zur Wunschliste',
              onPressed: () => _openAdd(wishlist: _index == 1),
              icon: const Icon(Icons.add_rounded),
            ),
          if (_index != 2)
            IconButton(
              tooltip: 'Filmcover scannen',
              onPressed: _scanCover,
              icon: const Icon(Icons.photo_camera_rounded),
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
                LibraryView(onAdd: _openCollectionAdd),
                WishlistView(onAdd: _openWishlistAdd),
                const StatsView(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
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
