enum CollectionViewMode {
  compactSquare,
  posterGrid,
  list,
}

extension CollectionViewModeValue on CollectionViewMode {
  String get storageValue => switch (this) {
        CollectionViewMode.compactSquare => 'compact_square',
        CollectionViewMode.posterGrid => 'poster_grid',
        CollectionViewMode.list => 'list',
      };

  static CollectionViewMode fromStorage(
    String? value, {
    CollectionViewMode fallback = CollectionViewMode.posterGrid,
  }) {
    return switch (value) {
      'compact_square' => CollectionViewMode.compactSquare,
      'poster_grid' => CollectionViewMode.posterGrid,
      'list' => CollectionViewMode.list,
      _ => fallback,
    };
  }
}
