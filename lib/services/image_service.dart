import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageService {
  static const Map<String, String> _webHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
  };

  /// Check if an image URL is accessible on mobile web
  static Future<bool> isImageAccessible(String imageUrl) async {
    if (!kIsWeb) return true; // Always accessible on mobile/desktop apps

    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: _webHeaders,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get image headers for web compatibility
  static Map<String, String>? getWebHeaders() {
    return kIsWeb ? _webHeaders : null;
  }

  /// Convert image to base64 for web compatibility
  static Future<String?> convertImageToBase64(String imageUrl) async {
    if (!kIsWeb) return null; // Only needed for web

    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: _webHeaders,
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = base64Encode(bytes);

        // Determine MIME type from URL or response headers
        String mimeType = 'image/jpeg'; // default
        if (imageUrl.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageUrl.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (imageUrl.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        return 'data:$mimeType;base64,$base64String';
      }
    } catch (e) {
      print('Error converting image to base64: $e');
    }

    return null;
  }

  /// Get fallback image URL for mobile web
  static String getFallbackImageUrl(String originalUrl) {
    // You can implement a proxy service or CDN here
    // For now, return the original URL
    return originalUrl;
  }

  /// Check if running on mobile web browser
  static bool get isMobileWeb {
    if (!kIsWeb) return false;

    // This is a simplified check - you might want to use a more sophisticated approach
    return true; // Assume mobile web for now
  }
}
