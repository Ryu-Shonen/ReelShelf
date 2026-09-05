import 'package:flutter_test/flutter_test.dart';
import 'package:reelshelf/models/collection_item.dart';

void main() {
  test('CollectionItem survives JSON/DB roundtrip', () {
    final now = DateTime.utc(2026, 9, 4, 12);
    final item = CollectionItem(
      id: 7,
      tmdbId: 129,
      title: 'Testfilm',
      year: 2026,
      mediaFormat: '4K UHD',
      edition: 'Steelbook',
      ean: '1234567890123',
      purchasePrice: 19.99,
      favorite: true,
      createdAt: now,
      updatedAt: now,
    );

    final restored = CollectionItem.fromJson(
      Map<String, dynamic>.from(item.toJson()),
    );

    expect(restored.id, 7);
    expect(restored.title, 'Testfilm');
    expect(restored.mediaFormat, '4K UHD');
    expect(restored.favorite, isTrue);
    expect(restored.purchasePrice, 19.99);
  });
}
