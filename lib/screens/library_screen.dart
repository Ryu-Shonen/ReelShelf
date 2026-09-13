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

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.onAdd,
  });

  final Future<void> Function() onAdd;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final _viewPreferences = ViewPreferencesService();

  String _query = '';
  String _format = 'Alle';
  String _sort = 'Titel';
  CollectionViewMode _viewMode =
      CollectionViewMode.posterGrid;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final mode =
        await _viewPreferences.getLibraryViewMode();
    if (!mounted) return;
    setState(() => _viewMode = mode);
  }

  Future<void> _setViewMode(
    CollectionViewMode mode,
  ) async {
    setState(() => _viewMode = mode);
    await _viewPreferences.setLibraryViewMode(mode);
  }

  List<CollectionItem> _filtered(
    List<CollectionItem> source,
  ) {
    var result = source.where((item) {
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          (item.originalTitle
                  ?.toLowerCase()
                  .contains(q) ??
              false) ||
          item.edition.toLowerCase().contains(q) ||
          item.ean.toLowerCase().contains(q);

      final matchesFormat =
          _format == 'Alle' || item.mediaFormat == _format;

      return matchesQuery && matchesFormat;
    }).toList();

    switch (_sort) {
      case 'Jahr':
        result.sort(
          (a, b) =>
              (b.year ?? 0).compareTo(a.year ?? 0),
        );
        break;
      case 'Neu hinzugefügt':
        result.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
        break;
      default:
        result.sort(
          (a, b) => a.title
              .toLowerCase()
              .compareTo(b.title.toLowerCase()),
        );
    }

    return result;
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
    final owned = state.ownedItems;

    if (owned.isEmpty) {
      return EmptyState(
        icon: Icons.local_movies_outlined,
        title: 'Dein Filmregal ist noch leer',
        message:
            'Füge deine erste Blu-ray, 4K UHD oder Sonderedition hinzu. Mit TMDB werden Cover und Filmdaten automatisch geladen.',
        primaryLabel: 'Ersten Film hinzufügen',
        onPrimary: () => widget.onAdd(),
        secondaryLabel: 'Demo-Sammlung ansehen',
        onSecondary: () async {
          await state.seedDemoData();
        },
      );
    }

    final items = _filtered(owned);
    final formats = <String>{
      'Alle',
      ...owned.map((item) => item.mediaFormat),
    }.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value),
            decoration: const InputDecoration(
              hintText:
                  'Titel, Edition oder EAN suchen …',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: formats.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final format = formats[index];
              return FilterChip(
                label: Text(format),
                selected: _format == format,
                onSelected: (_) =>
                    setState(() => _format = format),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 10, 6),
          child: Row(
            children: [
              Text(
                '${items.length} ${items.length == 1 ? 'Film' : 'Filme'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CollectionViewModeToggle(
                value: _viewMode,
                onChanged: _setViewMode,
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                tooltip: 'Sortieren',
                initialValue: _sort,
                onSelected: (value) =>
                    setState(() => _sort = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'Titel',
                    child: Text('Nach Titel'),
                  ),
                  PopupMenuItem(
                    value: 'Jahr',
                    child: Text('Nach Jahr'),
                  ),
                  PopupMenuItem(
                    value: 'Neu hinzugefügt',
                    child: Text('Neu hinzugefügt'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    children: [
                      Text(
                        _sort,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'Keine passenden Filme gefunden.',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                )
              : AnimatedSwitcher(
                  duration:
                      const Duration(milliseconds: 180),
                  child: _LibraryItemsView(
                    key: ValueKey(_viewMode),
                    mode: _viewMode,
                    items: items,
                    onTap: (item) =>
                        _openItem(context, item),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LibraryItemsView extends StatelessWidget {
  const _LibraryItemsView({
    super.key,
    required this.mode,
    required this.items,
    required this.onTap,
  });

  final CollectionViewMode mode;
  final List<CollectionItem> items;
  final ValueChanged<CollectionItem> onTap;

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
            );
          },
        );
    }
  }
}
