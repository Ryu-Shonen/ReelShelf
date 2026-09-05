import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../state/app_state.dart';
import '../widgets/collection_card.dart';
import '../widgets/empty_state.dart';
import 'movie_detail_screen.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key, required this.onAdd});

  final Future<void> Function({String? barcode}) onAdd;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  String _query = '';
  String _format = 'Alle';
  String _sort = 'Titel';

  List<CollectionItem> _filtered(List<CollectionItem> source) {
    var result = source.where((item) {
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          (item.originalTitle?.toLowerCase().contains(q) ?? false) ||
          item.edition.toLowerCase().contains(q) ||
          item.ean.toLowerCase().contains(q);
      final matchesFormat = _format == 'Alle' || item.mediaFormat == _format;
      return matchesQuery && matchesFormat;
    }).toList();

    switch (_sort) {
      case 'Jahr':
        result.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
      case 'Neu hinzugefügt':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      default:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return result;
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
    final formats = <String>{'Alle', ...owned.map((e) => e.mediaFormat)}.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Titel, Edition oder EAN suchen …',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: formats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final format = formats[index];
              return FilterChip(
                label: Text(format),
                selected: _format == format,
                onSelected: (_) => setState(() => _format = format),
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
              PopupMenuButton<String>(
                tooltip: 'Sortieren',
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Titel', child: Text('Nach Titel')),
                  PopupMenuItem(value: 'Jahr', child: Text('Nach Jahr')),
                  PopupMenuItem(
                    value: 'Neu hinzugefügt',
                    child: Text('Neu hinzugefügt'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded, size: 20),
                      const SizedBox(width: 5),
                      Text(_sort, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 6
                        : constraints.maxWidth >= 650
                            ? 4
                            : constraints.maxWidth >= 430
                                ? 3
                                : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MovieDetailScreen(itemId: item.id!),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
