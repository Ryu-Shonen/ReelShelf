import 'package:flutter/material.dart';

import '../models/collection_view_mode.dart';

class CollectionViewModeToggle extends StatelessWidget {
  const CollectionViewModeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CollectionViewMode value;
  final ValueChanged<CollectionViewMode> onChanged;

  IconData get _currentIcon => switch (value) {
        CollectionViewMode.compactSquare => Icons.grid_view_rounded,
        CollectionViewMode.posterGrid => Icons.view_module_rounded,
        CollectionViewMode.list => Icons.view_list_rounded,
      };

  String get _currentTooltip => switch (value) {
        CollectionViewMode.compactSquare => 'Kompakte Quadratansicht',
        CollectionViewMode.posterGrid => 'Normale Coveransicht',
        CollectionViewMode.list => 'Listenansicht',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CollectionViewMode>(
      tooltip: 'Ansicht ändern',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        _entry(
          mode: CollectionViewMode.compactSquare,
          icon: Icons.grid_view_rounded,
          label: 'Kompakt',
          subtitle: 'Quadratische Cover',
        ),
        _entry(
          mode: CollectionViewMode.posterGrid,
          icon: Icons.view_module_rounded,
          label: 'Normal',
          subtitle: 'Klassische Coveransicht',
        ),
        _entry(
          mode: CollectionViewMode.list,
          icon: Icons.view_list_rounded,
          label: 'Liste',
          subtitle: 'Cover links, Infos rechts',
        ),
      ],
      child: Tooltip(
        message: _currentTooltip,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            _currentIcon,
            size: 20,
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<CollectionViewMode> _entry({
    required CollectionViewMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = value == mode;

    return PopupMenuItem<CollectionViewMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 10),
            const Icon(
              Icons.check_rounded,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}
