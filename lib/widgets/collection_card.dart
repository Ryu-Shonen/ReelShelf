import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import '../state/app_state.dart';
import 'movie_poster.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onPurchased,
  });

  final CollectionItem item;
  final VoidCallback onTap;
  final VoidCallback? onPurchased;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final imdb = state.imdbRatingForTmdbId(item.tmdbId);
    final posterUrl = item.posterUrl ??
        (item.releaseId == null
            ? null
            : state.componentsForRelease(item.releaseId!).isEmpty
                ? null
                : state
                    .componentsForRelease(item.releaseId!)
                    .first
                    .posterUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag:
                      'poster-${item.id ?? item.title.hashCode}',
                  child: MoviePoster(url: posterUrl),
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: _Badge(label: item.mediaFormat),
                ),
                if (imdb?.rating != null ||
                    item.userRating != null)
                  Positioned(
                    bottom: 9,
                    left: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.userRating != null) ...[
                          _RatingBadge(
                            label:
                                'Meine ${item.userRating!.toStringAsFixed(1)}',
                            personal: true,
                          ),
                          if (imdb?.rating != null)
                            const SizedBox(height: 5),
                        ],
                        if (imdb?.rating != null)
                          _RatingBadge(
                            label:
                                'IMDb ${imdb!.rating!.toStringAsFixed(1)}',
                          ),
                      ],
                    ),
                  ),
                if (onPurchased != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _PurchasedButton(
                      onPressed: onPurchased!,
                    ),
                  ),
                if (item.favorite)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: _FavoriteBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (item.year != null) item.year.toString(),
              if (item.edition.isNotEmpty) item.edition,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.label,
    this.personal = false,
  });

  final String label;
  final bool personal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            personal
                ? Icons.person_rounded
                : Icons.star_rounded,
            size: 13,
            color: personal
                ? const Color(0xFFE7B95E)
                : const Color(0xFFF5C518),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasedButton extends StatelessWidget {
  const _PurchasedButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.76),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Gekauft – abhaken',
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: const Icon(
          Icons.check_rounded,
          size: 19,
          color: Color(0xFF7AD9A5),
        ),
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 17,
        color: Color(0xFFFF6B7A),
      ),
    );
  }
}
