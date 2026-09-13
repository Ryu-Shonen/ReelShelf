import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/collection_view_mode.dart';
import '../services/view_preferences_service.dart';
import '../state/app_state.dart';
import '../widgets/collection_card.dart';
import '../widgets/collection_item_views.dart';
import '../widgets/collection_view_mode_toggle.dart';
import '../widgets/empty_state.dart';
import 'movie_detail_screen.dart';

class WishlistView extends StatefulWidget {
  const WishlistView({
    super.key,
    required this.onAdd,
  });

  final Future<void> Function() onAdd;

  @override
  State<WishlistView> createState() =>
      _WishlistViewState();
}

class _WishlistViewState extends State<WishlistView> {
  final _viewPreferences = ViewPreferencesService();

  CollectionViewMode _viewMode =
      CollectionViewMode.posterGrid;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final mode =
        await _viewPreferences.getWishlistViewMode();
    if (!mounted) return;
    setState(() => _viewMode = mode);
  }

  Future<void> _setViewMode(
    CollectionViewMode mode,
  ) async {
    setState(() => _viewMode = mode);
    await _viewPreferences.setWishlistViewMode(mode);
  }

  Future<void> _markPurchased(
    CollectionItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Als gekauft markieren?'),
        content: Text(
          '„${item.title}“ wird aus der Wunschliste entfernt und automatisch deiner Sammlung hinzugefügt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Abhaken'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final state = AppStateScope.of(context);
    await state.moveWishlistItemToCollection(item);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '„${item.title}“ wurde in die Sammlung verschoben.',
        ),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            await state.updateItem(item);
          },
        ),
      ),
    );
  }

  void _openItem(
    BuildContext context,
    CollectionItem item,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MovieDetailScreen(itemId: item.id!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = state.wishlistItems;

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_add_outlined,
        title: 'Noch keine Wünsche',
        message:
            'Speichere Filme und Editionen, die du noch suchst. Beim Bearbeiten kannst du sie später mit einem Tipp in deine Sammlung übernehmen.',
        primaryLabel: 'Film zur Wunschliste',
        onPrimary: () => widget.onAdd(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
          child: Row(
            children: [
              Text(
                '${items.length} ${items.length == 1 ? 'Wunsch' : 'Wünsche'}',
                style: TextStyle(
                  color:
                      Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CollectionViewModeToggle(
                value: _viewMode,
                onChanged: _setViewMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _WishlistItemsView(
              key: ValueKey(_viewMode),
              mode: _viewMode,
              items: items,
              onTap: (item) =>
                  _openItem(context, item),
              onPurchased: _markPurchased,
            ),
          ),
        ),
      ],
    );
  }
}

class _WishlistItemsView extends StatelessWidget {
  const _WishlistItemsView({
    super.key,
    required this.mode,
    required this.items,
    required this.onTap,
    required this.onPurchased,
  });

  final CollectionViewMode mode;
  final List<CollectionItem> items;
  final ValueChanged<CollectionItem> onTap;
  final ValueChanged<CollectionItem> onPurchased;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CollectionViewMode.compactSquare:
        return LayoutBuilder(
          builder: (context, constraints) {
            const columns = 2;

            return GridView.builder(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 110),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return CompactSquareCollectionCard(
                  item: item,
                  onTap: () => onTap(item),
                  onPurchased: () => onPurchased(item),
                );
              },
            );
          },
        );

      case CollectionViewMode.posterGrid:
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 6
                : constraints.maxWidth >= 650
                    ? 4
                    : constraints.maxWidth >= 430
                        ? 3
                        : 2;

            return GridView.builder(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 110),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.56,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return CollectionCard(
                  item: item,
                  onTap: () => onTap(item),
                  onPurchased: () => onPurchased(item),
                );
              },
            );
          },
        );

      case CollectionViewMode.list:
        return ListView.separated(
          padding:
              const EdgeInsets.fromLTRB(12, 6, 12, 110),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 5),
          itemBuilder: (context, index) {
            final item = items[index];
            return CollectionListRow(
              item: item,
              onTap: () => onTap(item),
              onPurchased: () => onPurchased(item),
            );
          },
        );
    }
  }
}
