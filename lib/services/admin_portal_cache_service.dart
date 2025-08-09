import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminPortalCacheService {
  static const String _categoriesCacheKey = 'admin_categories_cache';
  static const String _examsCacheKey = 'admin_exams_cache';
  static const String _importedExamsCacheKey = 'admin_imported_exams_cache';
  static const String _jobsCacheKey = 'admin_jobs_cache';
  static const Duration _cacheValidity = Duration(minutes: 15);
  static const Duration _jobsCacheValidity = Duration(minutes: 5);

  // Cache categories
  static Future<void> cacheCategories(Map<String, String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': categories,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_categoriesCacheKey, jsonEncode(cacheData));
      print('📚 Admin categories cached');
    } catch (e) {
      print('Error caching categories: $e');
    }
  }

  // Get cached categories
  static Future<Map<String, String>?> getCachedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_categoriesCacheKey);
      
      if (cacheData == null) return null;
      
      final data = jsonDecode(cacheData);
      final timestamp = DateTime.parse(data['timestamp']);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _cacheValidity) {
        return null; // Cache expired
      }
      
      print('📚 Admin categories loaded from cache');
      return Map<String, String>.from(data['data']);
    } catch (e) {
      print('Error reading categories cache: $e');
      return null;
    }
  }

  // Cache exams for category
  static Future<void> cacheExamsForCategory(String category, List<String> exams) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_examsCacheKey}_$category';
      final cacheData = {
        'data': exams,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      print('📚 Admin exams cached for category: $category');
    } catch (e) {
      print('Error caching exams: $e');
    }
  }

  // Get cached exams for category
  static Future<List<String>?> getCachedExamsForCategory(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_examsCacheKey}_$category';
      final cacheData = prefs.getString(cacheKey);
      
      if (cacheData == null) return null;
      
      final data = jsonDecode(cacheData);
      final timestamp = DateTime.parse(data['timestamp']);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _cacheValidity) {
        return null; // Cache expired
      }
      
      print('📚 Admin exams loaded from cache for category: $category');
      return List<String>.from(data['data']);
    } catch (e) {
      print('Error reading exams cache: $e');
      return null;
    }
  }

  // Cache imported exams
  static Future<void> cacheImportedExams(List<Map<String, dynamic>> exams) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': exams,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_importedExamsCacheKey, jsonEncode(cacheData));
      print('📚 Admin imported exams cached');
    } catch (e) {
      print('Error caching imported exams: $e');
    }
  }

  // Get cached imported exams
  static Future<List<Map<String, dynamic>>?> getCachedImportedExams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_importedExamsCacheKey);
      
      if (cacheData == null) return null;
      
      final data = jsonDecode(cacheData);
      final timestamp = DateTime.parse(data['timestamp']);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _cacheValidity) {
        return null; // Cache expired
      }
      
      print('📚 Admin imported exams loaded from cache');
      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      print('Error reading imported exams cache: $e');
      return null;
    }
  }

  // Cache jobs
  static Future<void> cacheJobs(List<Map<String, dynamic>> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': jobs,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_jobsCacheKey, jsonEncode(cacheData));
      print('📚 Admin jobs cached');
    } catch (e) {
      print('Error caching jobs: $e');
    }
  }

  // Get cached jobs
  static Future<List<Map<String, dynamic>>?> getCachedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_jobsCacheKey);
      
      if (cacheData == null) return null;
      
      final data = jsonDecode(cacheData);
      final timestamp = DateTime.parse(data['timestamp']);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _jobsCacheValidity) {
        return null; // Cache expired
      }
      
      print('📚 Admin jobs loaded from cache');
      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      print('Error reading jobs cache: $e');
      return null;
    }
  }

  // Clear all caches
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('admin_')) {
          await prefs.remove(key);
        }
      }
      
      print('🗑️ All admin portal caches cleared');
    } catch (e) {
      print('Error clearing admin caches: $e');
    }
  }

  // Get cache status
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int cacheCount = 0;
      for (final key in keys) {
        if (key.startsWith('admin_')) {
          cacheCount++;
        }
      }
      
      return {
        'cacheCount': cacheCount,
        'hasCategories': prefs.containsKey(_categoriesCacheKey),
        'hasImportedExams': prefs.containsKey(_importedExamsCacheKey),
        'hasJobs': prefs.containsKey(_jobsCacheKey),
      };
    } catch (e) {
      return {
        'cacheCount': 0,
        'hasCategories': false,
        'hasImportedExams': false,
        'hasJobs': false,
      };
    }
  }
} 