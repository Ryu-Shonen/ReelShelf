import 'package:flutter/material.dart';

class MoviePoster extends StatelessWidget {
  const MoviePoster({
    super.key,
    this.url,
    this.borderRadius = 18,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: const Color(0xFF20232C),
        child: url == null
            ? const _PosterPlaceholder()
            : Image.network(
                url!,
                fit: fit,
                errorBuilder: (_, __, ___) => const _PosterPlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 42,
        color: Colors.white.withValues(alpha: 0.28),
      ),
    );
  }
}
