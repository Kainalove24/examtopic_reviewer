import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExamInfoCacheService {
  static const String _cachePrefix = 'exam_info_cache_';
  static const String _imageCachePrefix = 'exam_image_cache_';
  static const Duration _cacheValidity = Duration(hours: 24);
  static const Duration _imageCacheValidity = Duration(days: 7);

  // Cache exam data
  static Future<void> cacheExamData(String examId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$examId';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
      
      print('📚 Exam info cached for $examId');
    } catch (e) {
      print('Error caching exam data: $e');
    }
  }

  // Get cached exam data
  static Future<Map<String, dynamic>?> getCachedExamData(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$examId';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cacheData = prefs.getString(cacheKey);
      final timestampStr = prefs.getString(timestampKey);
      
      if (cacheData == null || timestampStr == null) {
        return null;
      }
      
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _cacheValidity) {
        return null; // Cache expired
      }
      
      final data = jsonDecode(cacheData);
      print('📚 Exam info loaded from cache for $examId');
      return Map<String, dynamic>.from(data['data']);
    } catch (e) {
      print('Error reading exam cache: $e');
      return null;
    }
  }

  // Cache image data
  static Future<void> cacheImageData(String imageUrl, String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_imageCachePrefix${Uri.encodeComponent(imageUrl)}';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cacheData = {
        'localPath': localPath,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
      
      print('🖼️ Image cached: $imageUrl');
    } catch (e) {
      print('Error caching image: $e');
    }
  }

  // Get cached image data
  static Future<String?> getCachedImageData(String imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_imageCachePrefix${Uri.encodeComponent(imageUrl)}';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cacheData = prefs.getString(cacheKey);
      final timestampStr = prefs.getString(timestampKey);
      
      if (cacheData == null || timestampStr == null) {
        return null;
      }
      
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      if (now.difference(timestamp) > _imageCacheValidity) {
        return null; // Cache expired
      }
      
      final data = jsonDecode(cacheData);
      print('🖼️ Image loaded from cache: $imageUrl');
      return data['localPath'] as String;
    } catch (e) {
      print('Error reading image cache: $e');
      return null;
    }
  }

  // Clear cache for specific exam
  static Future<void> clearExamCache(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$examId';
      final timestampKey = '${cacheKey}_timestamp';
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
      
      print('🗑️ Exam cache cleared for $examId');
    } catch (e) {
      print('Error clearing exam cache: $e');
    }
  }

  // Clear all caches
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_imageCachePrefix)) {
          await prefs.remove(key);
        }
      }
      
      print('🗑️ All exam info caches cleared');
    } catch (e) {
      print('Error clearing all caches: $e');
    }
  }

  // Get cache status
  static Future<Map<String, dynamic>> getCacheStatus(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$examId';
      final timestampKey = '${cacheKey}_timestamp';
      
      final timestampStr = prefs.getString(timestampKey);
      if (timestampStr == null) {
        return {'hasCache': false, 'ageMinutes': 0};
      }
      
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final age = now.difference(timestamp);
      
      return {
        'hasCache': true,
        'ageMinutes': age.inMinutes,
        'isValid': age <= _cacheValidity,
      };
    } catch (e) {
      return {'hasCache': false, 'ageMinutes': 0};
    }
  }
} 