import 'package:flutter/material.dart';

import '../models/collection_item.dart';
import 'movie_poster.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final CollectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  tag: 'poster-${item.id ?? item.title.hashCode}',
                  child: MoviePoster(url: item.posterUrl),
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: _Badge(label: item.mediaFormat),
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
            maxLines: 2,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
      child: const Icon(Icons.favorite_rounded, size: 17, color: Color(0xFFFF6B7A)),
    );
  }
}
