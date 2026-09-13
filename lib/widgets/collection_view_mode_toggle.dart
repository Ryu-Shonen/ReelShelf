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

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CollectionViewMode>(
      showSelectedIcon: false,
      selected: {value},
      segments: const [
        ButtonSegment<CollectionViewMode>(
          value: CollectionViewMode.compactSquare,
          icon: Icon(Icons.grid_view_rounded, size: 18),
          tooltip: 'Kompakte Quadratansicht',
        ),
        ButtonSegment<CollectionViewMode>(
          value: CollectionViewMode.posterGrid,
          icon: Icon(Icons.view_module_rounded, size: 18),
          tooltip: 'Normale Coveransicht',
        ),
        ButtonSegment<CollectionViewMode>(
          value: CollectionViewMode.list,
          icon: Icon(Icons.view_list_rounded, size: 19),
          tooltip: 'Listenansicht',
        ),
      ],
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(38, 36),
        ),
      ),
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}
