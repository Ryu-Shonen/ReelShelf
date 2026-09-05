import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _tmdbTokenKey = 'tmdb_read_access_token';
  static const _languageKey = 'tmdb_language';
  static const _regionKey = 'tmdb_region';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> getTmdbToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tmdbTokenKey) ?? '';
  }

  Future<void> setTmdbToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_tmdbTokenKey, token.trim());
  }

  Future<String> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey) ?? 'de-DE';
  }

  Future<void> setLanguage(String language) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, language);
  }

  Future<String> getRegion() async {
    final prefs = await _prefs;
    return prefs.getString(_regionKey) ?? 'DE';
  }

  Future<void> setRegion(String region) async {
    final prefs = await _prefs;
    await prefs.setString(_regionKey, region);
  }
}
