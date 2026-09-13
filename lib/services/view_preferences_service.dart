import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_view_mode.dart';

class ViewPreferencesService {
  static const _libraryViewModeKey = 'library_view_mode';
  static const _wishlistViewModeKey = 'wishlist_view_mode';

  Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  Future<CollectionViewMode> getLibraryViewMode() async {
    final prefs = await _prefs;
    return CollectionViewModeValue.fromStorage(
      prefs.getString(_libraryViewModeKey),
    );
  }

  Future<void> setLibraryViewMode(
    CollectionViewMode mode,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _libraryViewModeKey,
      mode.storageValue,
    );
  }

  Future<CollectionViewMode> getWishlistViewMode() async {
    final prefs = await _prefs;
    return CollectionViewModeValue.fromStorage(
      prefs.getString(_wishlistViewModeKey),
    );
  }

  Future<void> setWishlistViewMode(
    CollectionViewMode mode,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _wishlistViewModeKey,
      mode.storageValue,
    );
  }
}
