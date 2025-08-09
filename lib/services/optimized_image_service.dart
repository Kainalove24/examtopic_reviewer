import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'exam_info_cache_service.dart';
import '../config/server_config.dart';
import 'dart:convert'; // Added for jsonEncode and jsonDecode

class OptimizedImageService {
  static final Map<String, String> _memoryCache = {};
  static final Map<String, Completer<String?>> _loadingCompleters = {};
  static const int _maxMemoryCacheSize = 100;
  static bool _serverHealthChecked = false;
  static bool _serverHealthy = false;

  // Check server health before processing images
  static Future<bool> _checkServerHealth() async {
    if (_serverHealthChecked) {
      return _serverHealthy;
    }

    try {
      print('🏥 Checking server health...');
      final response = await http
          .get(Uri.parse(ServerConfig.healthCheckUrl))
          .timeout(const Duration(seconds: 10));

      _serverHealthy = response.statusCode == 200;
      _serverHealthChecked = true;

      print(
        _serverHealthy
            ? '✅ Server is healthy'
            : '❌ Server health check failed: ${response.statusCode}',
      );

      return _serverHealthy;
    } catch (e) {
      print('❌ Server health check error: $e');
      _serverHealthy = false;
      _serverHealthChecked = true;
      return false;
    }
  }

  // Reset server health check (useful for retry scenarios)
  static void _resetServerHealthCheck() {
    _serverHealthChecked = false;
    _serverHealthy = false;
  }

  // Preload images for better performance
  static Future<void> preloadImages(List<String> imageUrls) async {
    for (final imageUrl in imageUrls) {
      if (imageUrl.isNotEmpty) {
        _loadImageAsync(imageUrl);
      }
    }
  }

  // NEW: Pre-download all images from an exam for offline access
  static Future<void> preDownloadExamImages(
    List<Map<String, dynamic>> questions,
  ) async {
    print('🔄 Starting pre-download of exam images...');
    final allImageUrls = <String>{};

    // Collect all image URLs from the exam
    for (final question in questions) {
      // Add question images
      if (question['question_images'] != null) {
        final questionImages = question['question_images'] as List?;
        if (questionImages != null) {
          for (final image in questionImages) {
            if (image is String &&
                image.isNotEmpty &&
                image.startsWith('http')) {
              allImageUrls.add(image);
            }
          }
        }
      }

      // Add answer images
      if (question['answer_images'] != null) {
        final answerImages = question['answer_images'] as List?;
        if (answerImages != null) {
          for (final image in answerImages) {
            if (image is String &&
                image.isNotEmpty &&
                image.startsWith('http')) {
              allImageUrls.add(image);
            }
          }
        }
      }
    }

    print('📥 Found ${allImageUrls.length} images to pre-download');

    // Download all images in parallel
    final futures = allImageUrls.map((url) => _downloadImageForOffline(url));
    final results = await Future.wait(futures, eagerError: false);

    final successCount = results.where((result) => result != null).length;
    print(
      '✅ Pre-download complete: $successCount/${allImageUrls.length} images downloaded',
    );
  }

  // NEW: Download a single image for offline storage
  static Future<String?> _downloadImageForOffline(String imageUrl) async {
    try {
      // Check if already cached
      final cachedPath = await ExamInfoCacheService.getCachedImageData(
        imageUrl,
      );
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          print('📋 Image already cached: ${path.basename(imageUrl)}');
          return cachedPath;
        }
      }

      print('⬇️ Downloading: ${path.basename(imageUrl)}');

      // Try to create images directory, but handle path_provider errors gracefully
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        // Generate unique filename
        final fileName =
            'offline_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageUrl)}';
        final filePath = path.join(imagesDir.path, fileName);

        // Download the image
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          final relativePath = 'images/$fileName';

          // Cache the local path
          await ExamInfoCacheService.cacheImageData(imageUrl, relativePath);

          print('✅ Downloaded: ${path.basename(imageUrl)}');
          return relativePath;
        } else {
          print(
            '❌ Failed to download: ${path.basename(imageUrl)} (HTTP ${response.statusCode})',
          );
          return null;
        }
      } catch (pathError) {
        print('⚠️ Path provider error during offline download: $pathError');
        print('📡 Using server URL directly for offline access');
        // Cache the server URL instead of local path
        await ExamInfoCacheService.cacheImageData(imageUrl, imageUrl);
        return imageUrl;
      }
    } catch (e) {
      print('❌ Error downloading ${path.basename(imageUrl)}: $e');
      return null;
    }
  }

  // Load image with caching
  static Future<String?> loadImage(String imagePath) async {
    // Check memory cache first
    if (_memoryCache.containsKey(imagePath)) {
      return _memoryCache[imagePath];
    }

    // Check if already loading
    if (_loadingCompleters.containsKey(imagePath)) {
      return await _loadingCompleters[imagePath]!.future;
    }

    // Start loading
    final completer = Completer<String?>();
    _loadingCompleters[imagePath] = completer;

    try {
      String? result;

      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        result = await _loadNetworkImage(imagePath);
      } else if (imagePath.startsWith('images/')) {
        result = await _loadLocalImage(imagePath);
      } else {
        result = imagePath; // Asset image
      }

      // Add to memory cache
      if (result != null) {
        _addToMemoryCache(imagePath, result);
      }

      completer.complete(result);
      _loadingCompleters.remove(imagePath);
      return result;
    } catch (e) {
      completer.complete(null);
      _loadingCompleters.remove(imagePath);
      return null;
    }
  }

  // Load network image using hosted image processing server
  static Future<String?> _loadNetworkImage(String imageUrl) async {
    try {
      // Check if URL is already processed (from our server)
      if (imageUrl.contains('image-processing-server') &&
          imageUrl.contains('onrender.com')) {
        print('🔄 Loading already processed image: ${path.basename(imageUrl)}');

        // Check if we have a local cached version of this processed image
        final cachedPath = await ExamInfoCacheService.getCachedImageData(
          imageUrl,
        );
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            print('✅ Found cached version of processed image');
            return cachedPath;
          }
        }

        // If no local cache, return the processed URL directly
        print('📡 Using processed image URL directly');
        return imageUrl;
      }

      // For external URLs, check cache first
      final cachedPath = await ExamInfoCacheService.getCachedImageData(
        imageUrl,
      );
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          print('✅ Found cached version of external image');
          return cachedPath;
        }
      }

      // Check server health first
      final isServerHealthy = await _checkServerHealth();
      if (!isServerHealthy) {
        print('⚠️ Server is not healthy, falling back to direct URL');
        return imageUrl;
      }

      // For Render free tier, add extra delay to allow server to wake up
      if (ServerConfig.imageProcessingServerUrl.contains('onrender.com')) {
        print('⏰ Render free tier detected, adding wake-up delay...');
        await Future.delayed(const Duration(seconds: 2));
      }

      // Retry logic for server processing
      for (int attempt = 1; attempt <= ServerConfig.maxRetries; attempt++) {
        try {
          print(
            '🔄 Attempting to process image (attempt $attempt): ${path.basename(imageUrl)}',
          );

          // Use hosted image processing server
          final response = await http
              .post(
                Uri.parse(ServerConfig.processImagesUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'imageUrls': [imageUrl],
                }),
              )
              .timeout(ServerConfig.requestTimeout);

          if (response.statusCode == 200) {
            final result = jsonDecode(response.body) as Map<String, dynamic>;

            if (result['success'] == true &&
                result['processedImages'] != null) {
              final processedImages = result['processedImages'] as List;
              if (processedImages.isNotEmpty) {
                final processedUrl = ServerConfig.getProcessedImageUrl(
                  processedImages.first,
                );

                // Cache the processed URL
                await ExamInfoCacheService.cacheImageData(
                  imageUrl,
                  processedUrl,
                );
                print(
                  '✅ Successfully processed image: ${path.basename(imageUrl)}',
                );
                return processedUrl;
              }
            }

            // Check for errors in the response
            if (result['errors'] != null &&
                (result['errors'] as List).isNotEmpty) {
              print('⚠️ Server reported errors: ${result['errors']}');
            }
          } else {
            print(
              '⚠️ Server returned status ${response.statusCode} for image: ${path.basename(imageUrl)}',
            );

            // For 502 errors, this might be a Render free tier issue
            if (response.statusCode == 502) {
              print('🔄 502 error detected - Render server might be sleeping');
            }
          }
        } catch (e) {
          print(
            '❌ Attempt $attempt failed for image ${path.basename(imageUrl)}: $e',
          );
          if (attempt < ServerConfig.maxRetries) {
            await Future.delayed(ServerConfig.retryDelay);
            // Reset server health check on failure to allow retry
            if (attempt == 1) {
              _resetServerHealthCheck();
            }
          }
        }
      }

      // Fallback to direct URL if server processing fails
      print('🔄 Falling back to direct URL for: ${path.basename(imageUrl)}');

      // Try direct download as final fallback
      try {
        print('⬇️ Attempting direct download: ${path.basename(imageUrl)}');
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          // Try to save to local cache, but don't fail if path_provider is unavailable
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final imagesDir = Directory(path.join(appDir.path, 'images'));
            if (!await imagesDir.exists()) {
              await imagesDir.create(recursive: true);
            }

            final fileName =
                'direct_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageUrl)}';
            final filePath = path.join(imagesDir.path, fileName);
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            final relativePath = 'images/$fileName';
            await ExamInfoCacheService.cacheImageData(imageUrl, relativePath);

            print('✅ Direct download successful: ${path.basename(imageUrl)}');
            return relativePath;
          } catch (pathError) {
            print(
              '⚠️ Path provider error, using server URL directly: $pathError',
            );
            // Cache the server URL instead of local path
            await ExamInfoCacheService.cacheImageData(imageUrl, imageUrl);
            return imageUrl;
          }
        } else {
          print(
            '❌ Direct download failed with status ${response.statusCode}: ${path.basename(imageUrl)}',
          );
          // Return null to indicate image is not available
          return null;
        }
      } catch (e) {
        print('❌ Direct download failed: $e');
        // Return null to indicate image is not available
        return null;
      }
    } catch (e) {
      print('❌ Error processing image through server: $e');
      // Fallback to direct URL
      return imageUrl;
    }
  }

  // Load local image
  static Future<String?> _loadLocalImage(String relativePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = path.join(appDir.path, relativePath);
      final file = File(fullPath);

      if (await file.exists()) {
        return fullPath;
      }

      // Try alternative paths
      final altPaths = [
        path.join(appDir.path, 'images', path.basename(relativePath)),
        path.join(appDir.path, 'assets', relativePath),
        relativePath,
      ];

      for (final altPath in altPaths) {
        final altFile = File(altPath);
        if (await altFile.exists()) {
          return altPath;
        }
      }
    } catch (e) {
      print('Error loading local image: $e');
    }
    return null;
  }

  // Load image asynchronously (for preloading)
  static void _loadImageAsync(String imagePath) {
    loadImage(imagePath).catchError((e) {
      print('Error preloading image: $e');
    });
  }

  // Add to memory cache with size limit
  static void _addToMemoryCache(String key, String value) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = value;
  }

  // Clear memory cache
  static void clearMemoryCache() {
    _memoryCache.clear();
    _loadingCompleters.clear();
  }

  // Get memory cache stats
  static Map<String, dynamic> getMemoryCacheStats() {
    return {
      'size': _memoryCache.length,
      'maxSize': _maxMemoryCacheSize,
      'loadingCount': _loadingCompleters.length,
    };
  }

  // Preload images for a list of questions
  static Future<void> preloadQuestionImages(
    List<Map<String, dynamic>> questions,
  ) async {
    final imageUrls = <String>[];

    for (final question in questions) {
      // Add question images
      if (question['question_images'] != null) {
        final images = question['question_images'] as List?;
        if (images != null) {
          for (final image in images) {
            if (image is String && image.isNotEmpty) {
              imageUrls.add(image);
            }
          }
        }
      }

      // Add answer images
      if (question['answer_images'] != null) {
        final images = question['answer_images'] as List?;
        if (images != null) {
          for (final image in images) {
            if (image is String && image.isNotEmpty) {
              imageUrls.add(image);
            }
          }
        }
      }
    }

    // Preload unique images
    final uniqueImages = imageUrls.toSet();
    await preloadImages(uniqueImages.toList());
  }
}
