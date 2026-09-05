import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/collection_card.dart';
import '../widgets/empty_state.dart';
import 'movie_detail_screen.dart';

class WishlistView extends StatelessWidget {
  const WishlistView({super.key, required this.onAdd});

  final Future<void> Function({String? barcode}) onAdd;

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
        onPrimary: () => onAdd(),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
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
    );
  }
}
