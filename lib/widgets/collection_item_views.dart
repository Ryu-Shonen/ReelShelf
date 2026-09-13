import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../state/app_state.dart';
import 'movie_poster.dart';

class CompactSquareCollectionCard extends StatelessWidget {
  const CompactSquareCollectionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final CollectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final imdb = state.imdbRatingForTmdbId(item.tmdbId);
    final posterUrl = _posterUrlForItem(state, item);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'poster-${item.id ?? item.title.hashCode}',
              child: MoviePoster(
                url: posterUrl,
                borderRadius: 16,
                fit: BoxFit.cover,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.86),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 7,
              left: 7,
              child: _SmallBadge(
                text: item.mediaFormat,
              ),
            ),
            if (item.favorite)
              const Positioned(
                top: 7,
                right: 7,
                child: _MiniFavorite(),
              ),
            Positioned(
              left: 9,
              right: 9,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.year != null) '${item.year}',
                      if (imdb?.rating != null)
                        'IMDb ${imdb!.rating!.toStringAsFixed(1)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CollectionListRow extends StatelessWidget {
  const CollectionListRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  final CollectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final imdb = state.imdbRatingForTmdbId(item.tmdbId);
    final posterUrl = _posterUrlForItem(state, item);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'poster-${item.id ?? item.title.hashCode}',
                child: SizedBox(
                  width: 72,
                  height: 106,
                  child: MoviePoster(
                    url: posterUrl,
                    borderRadius: 10,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: SizedBox(
                  height: 106,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (item.favorite) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.favorite_rounded,
                              size: 17,
                              color: Color(0xFFFF6B7A),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (item.year != null) '${item.year}',
                          if (item.runtime != null)
                            '${item.runtime} Min.',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(
                            alpha: 0.52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _InfoChip(item.mediaFormat),
                          if (item.edition.isNotEmpty)
                            _InfoChip(item.edition),
                          if (item.voteAverage != null)
                            _InfoChip(
                              'TMDB ${item.voteAverage!.toStringAsFixed(1)}',
                            ),
                          if (imdb?.rating != null)
                            _InfoChip(
                              'IMDb ${imdb!.rating!.toStringAsFixed(1)}',
                              highlighted: true,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.wishlist
                            ? 'Wunschliste · ${item.condition}'
                            : item.location.isNotEmpty
                                ? '${item.condition} · ${item.location}'
                                : item.condition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const SizedBox(
                height: 106,
                child: Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _posterUrlForItem(
  AppState state,
  CollectionItem item,
) {
  if (item.posterUrl != null) return item.posterUrl;

  final releaseId = item.releaseId;
  if (releaseId == null) return null;

  final components = state.componentsForRelease(releaseId);
  if (components.isEmpty) return null;

  return components.first.posterUrl;
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 86),
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniFavorite extends StatelessWidget {
  const _MiniFavorite();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 14,
        color: Color(0xFFFF6B7A),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
    this.text, {
    this.highlighted = false,
  });

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFF5C518).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: highlighted
              ? const Color(0xFFF5C518)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
