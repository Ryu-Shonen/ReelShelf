import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../models/release_component.dart';
import '../state/app_state.dart';
import '../widgets/movie_poster.dart';
import 'edit_item_screen.dart';

class MovieDetailScreen extends StatelessWidget {
  const MovieDetailScreen({
    super.key,
    required this.itemId,
  });

  final int itemId;

  CollectionItem? _findItem(AppState state) {
    for (final item in state.items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  Future<void> _edit(
    BuildContext context,
    CollectionItem item,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          item: item,
          isNew: false,
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    CollectionItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item.mediaFormat == 'Boxset'
              ? 'Boxset entfernen?'
              : 'Film entfernen?',
        ),
        content: Text(
          '„${item.title}“ wird aus ReelShelf gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AppStateScope.of(context).deleteItem(item);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final item = _findItem(state);

    if (item == null) {
      return const Scaffold(
        body: Center(
          child: Text('Dieser Eintrag existiert nicht mehr.'),
        ),
      );
    }

    final components = item.releaseId == null
        ? const <ReleaseComponent>[]
        : state.componentsForRelease(item.releaseId!);

    final imdb =
        state.imdbRatingForTmdbId(item.tmdbId);
    final hasAnyImdbRating = imdb?.rating != null ||
        components.any(
          (component) =>
              state.imdbRatingForTmdbId(component.tmdbId)?.rating != null,
        );

    final isBoxSet =
        item.mediaFormat == 'Boxset' || components.isNotEmpty;
    final fallbackPoster =
        components.isEmpty ? null : components.first.posterUrl;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            actions: [
              IconButton(
                tooltip: item.favorite
                    ? 'Favorit entfernen'
                    : 'Als Favorit markieren',
                onPressed: () => state.updateItem(
                  item.copyWith(
                    favorite: !item.favorite,
                  ),
                ),
                icon: Icon(
                  item.favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _edit(context, item);
                  } else if (value == 'delete') {
                    _delete(context, item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Bearbeiten'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded),
                        SizedBox(width: 10),
                        Text('Löschen'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DetailHero(
                item: item,
                fallbackPosterUrl: fallbackPoster,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(18, 22, 18, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style:
                        Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (item.originalTitle != null &&
                      item.originalTitle != item.title) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.originalTitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        text: item.mediaFormat,
                        icon: isBoxSet
                            ? Icons.all_inbox_rounded
                            : Icons.album_rounded,
                      ),
                      if (isBoxSet && components.isNotEmpty)
                        _Pill(
                          text: '${components.length} Filme',
                          icon: Icons.video_library_outlined,
                        ),
                      if (item.year != null)
                        _Pill(
                          text: '${item.year}',
                          icon: Icons.calendar_month_rounded,
                        ),
                      if (item.runtime != null)
                        _Pill(
                          text: '${item.runtime} Min.',
                          icon: Icons.schedule_rounded,
                        ),
                      if (item.voteAverage != null)
                        _Pill(
                          text:
                              'TMDB ${item.voteAverage!.toStringAsFixed(1)}',
                          icon: Icons.star_outline_rounded,
                        ),
                      if (imdb?.rating != null)
                        _Pill(
                          text:
                              'IMDb ${imdb!.rating!.toStringAsFixed(1)}',
                          icon: Icons.star_rounded,
                        ),
                    ],
                  ),
                  if (item.genres.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      item.genres,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  ],
                  if (item.overview?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 26),
                    Text(
                      'Zum Film',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.overview!,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ],
                  if (hasAnyImdbRating) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Information courtesy of IMDb (https://www.imdb.com). Used with permission.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.36),
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (isBoxSet) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          'Enthaltene Filme',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          '${components.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (components.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Diesem Boxset sind noch keine Filme zugeordnet. Über „Collection bearbeiten“ kannst du die enthaltenen Filme hinzufügen.',
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.58,
                                ),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...components.map(
                        (component) {
                          final componentImdb =
                              state.imdbRatingForTmdbId(
                            component.tmdbId,
                          );

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 9),
                            child: Card(
                              child: ListTile(
                                leading: SizedBox(
                                  width: 44,
                                  height: 66,
                                  child: MoviePoster(
                                    url: component.posterUrl,
                                    borderRadius: 7,
                                  ),
                                ),
                                title: Text(
                                  component.title,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                subtitle: component.year == null
                                    ? null
                                    : Text('${component.year}'),
                                trailing:
                                    componentImdb?.rating == null
                                        ? const Icon(
                                            Icons.movie_outlined,
                                          )
                                        : Text(
                                            'IMDb ${componentImdb!.rating!.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w800,
                                            ),
                                          ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        isBoxSet
                            ? 'Meine Collection'
                            : 'Meine Ausgabe',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const Spacer(),
                      if (item.wishlist)
                        const _StatusBadge(
                          label: 'Wunschliste',
                          icon: Icons.bookmark_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Format',
                          value: item.mediaFormat,
                          icon: isBoxSet
                              ? Icons.all_inbox_outlined
                              : Icons.album_outlined,
                        ),
                        if (item.edition.isNotEmpty)
                          _InfoRow(
                            label: 'Edition',
                            value: item.edition,
                            icon:
                                Icons.auto_awesome_outlined,
                          ),
                        if (item.ean.isNotEmpty)
                          _InfoRow(
                            label: 'EAN',
                            value: item.ean,
                            icon: Icons.qr_code_2_rounded,
                          ),
                        _InfoRow(
                          label: 'Zustand',
                          value: item.condition,
                          icon: Icons.verified_outlined,
                        ),
                        if (item.purchasePrice != null)
                          _InfoRow(
                            label: 'Kaufpreis',
                            value:
                                '${item.purchasePrice!.toStringAsFixed(2).replaceAll('.', ',')} €',
                            icon: Icons.euro_rounded,
                          ),
                        if (item.purchaseDate?.isNotEmpty == true)
                          _InfoRow(
                            label: 'Kaufdatum',
                            value: item.purchaseDate!,
                            icon:
                                Icons.calendar_today_outlined,
                          ),
                        if (item.location.isNotEmpty)
                          _InfoRow(
                            label: 'Standort',
                            value: item.location,
                            icon:
                                Icons.inventory_2_outlined,
                          ),
                      ],
                    ),
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Notizen',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            item.notes,
                            style:
                                const TextStyle(height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _edit(context, item),
                      icon:
                          const Icon(Icons.edit_rounded),
                      label: Text(
                        isBoxSet
                            ? 'Collection bearbeiten'
                            : 'Ausgabe bearbeiten',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.item,
    this.fallbackPosterUrl,
  });

  final CollectionItem item;
  final String? fallbackPosterUrl;

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterUrl ?? fallbackPosterUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.backdropUrl != null)
          Image.network(
            item.backdropUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(
              color: Color(0xFF171920),
            ),
          )
        else
          const ColoredBox(
            color: Color(0xFF171920),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.42),
                const Color(0xFF0B0C10),
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.55),
          child: Hero(
            tag:
                'poster-${item.id ?? item.title.hashCode}',
            child: SizedBox(
              width: 130,
              height: 194,
              child: MoviePoster(
                url: posterUrl,
                borderRadius: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B7A)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFFF6B7A),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
