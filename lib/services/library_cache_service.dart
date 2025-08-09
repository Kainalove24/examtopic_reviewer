import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryCacheService {
  static const String _cacheKey = 'library_cache';
  static const String _cacheTimestampKey = 'library_cache_timestamp';
  static const Duration _cacheValidity = Duration(minutes: 30);

  // Cache structure
  static Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheTime;

  // Get cached library data
  static Future<Map<String, dynamic>?> getCachedLibraryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      final timestampStr = prefs.getString(_cacheTimestampKey);

      if (cacheData == null || timestampStr == null) {
        return null;
      }

      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();

      // Check if cache is still valid
      if (now.difference(timestamp) > _cacheValidity) {
        return null; // Cache expired
      }

      _cache = Map<String, dynamic>.from(jsonDecode(cacheData));
      _lastCacheTime = timestamp;
      return _cache;
    } catch (e) {
      print('Error reading cache: $e');
      return null;
    }
  }

  // Cache library data
  static Future<void> cacheLibraryData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      _cache = data;
      _lastCacheTime = now;

      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setString(_cacheTimestampKey, now.toIso8601String());

      print('Library data cached successfully');
    } catch (e) {
      print('Error caching library data: $e');
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      _cache.clear();
      _lastCacheTime = null;
      print('Library cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Check if cache is valid
  static bool isCacheValid() {
    if (_lastCacheTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastCacheTime!) <= _cacheValidity;
  }

  // Get cache age
  static Duration? getCacheAge() {
    if (_lastCacheTime == null) return null;
    return DateTime.now().difference(_lastCacheTime!);
  }

  // Invalidate cache (force refresh)
  static Future<void> invalidateCache() async {
    await clearCache();
  }
}
