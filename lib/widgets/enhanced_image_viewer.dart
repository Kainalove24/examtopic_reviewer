import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../services/image_service.dart';
import '../config/server_config.dart';
import '../services/optimized_image_service.dart';

class EnhancedImageViewer extends StatefulWidget {
  final String imageData; // Can be base64, URL, or asset path
  final String? title;

  const EnhancedImageViewer({super.key, required this.imageData, this.title});

  @override
  State<EnhancedImageViewer> createState() => _EnhancedImageViewerState();
}

class _EnhancedImageViewerState extends State<EnhancedImageViewer> {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  double _scale = 1.0;
  final double _minScale = 1.0;
  final double _maxScale = 5.0;
  String? _processedImageUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.imageData.startsWith('http://') ||
        widget.imageData.startsWith('https://')) {
      try {
        setState(() {
          _isLoading = true;
          _error = null;
        });

        final processedUrl = await OptimizedImageService.loadImage(
          widget.imageData,
        );

        if (mounted) {
          setState(() {
            _processedImageUrl = processedUrl;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    } else {
      // For local images, no processing needed
      setState(() {
        _processedImageUrl = widget.imageData;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    if (_scale == _minScale) {
      // Zoom in to max scale
      final position = _doubleTapDetails!.localPosition;
      final x = -position.dx * (_maxScale - 1);
      final y = -position.dy * (_maxScale - 1);

      final Matrix4 zoomedMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(_maxScale);

      _transformationController.value = zoomedMatrix;
      _scale = _maxScale;
    } else {
      // Reset to original scale
      _transformationController.value = Matrix4.identity();
      _scale = _minScale;
    }
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadImage, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _minScale,
        maxScale: _maxScale,
        child: Center(child: _buildImageWidget()),
      ),
    );
  }

  Widget _buildImageWidget() {
    // Check if it's a base64 image
    if (widget.imageData.startsWith('data:image/')) {
      try {
        // Extract base64 data
        final base64Data = widget.imageData.split(',')[1];
        final imageBytes = base64Decode(base64Data);

        return Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildErrorWidget('Base64 image failed to load'),
        );
      } catch (e) {
        return _buildErrorWidget('Invalid base64 image: $e');
      }
    }

    // Use processed image URL if available, otherwise use original
    final imageUrl = _processedImageUrl ?? widget.imageData;

    // Check if it's a network URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return _buildNetworkImage(imageUrl);
    }

    // Check if it's a local file path
    if (imageUrl.startsWith('images/')) {
      return _buildLocalImage();
    }

    // Assume it's an asset path
    return Image.asset(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          _buildErrorWidget('Asset image not found'),
    );
  }

  Widget _buildNetworkImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      // Use ImageService for better mobile web compatibility
      headers: ImageService.getWebHeaders(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // For web, try alternative loading methods
        if (kIsWeb) {
          return _buildWebFallbackImage();
        }
        return _buildErrorWidget('Network image failed to load');
      },
    );
  }

  Widget _buildLocalImage() {
    // For web, try to load as asset first, then fallback to file
    if (kIsWeb) {
      return _buildWebLocalImage();
    }

    return FutureBuilder<String?>(
      future: _getLocalImagePath(widget.imageData),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('Local image failed to load');
            },
          );
        } else {
          return Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildWebLocalImage() {
    // For web, try different approaches to load local images
    return FutureBuilder<Widget>(
      future: _tryWebLocalImageLoading(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return _buildErrorWidget('Local image not available on web');
      },
    );
  }

  Future<Widget> _tryWebLocalImageLoading() async {
    // Try different approaches for web local images
    try {
      // Approach 1: Try as asset
      final assetPath = 'assets/${widget.imageData}';
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          throw Exception('Asset not found');
        },
      );
    } catch (e) {
      print('Failed to load as asset: $e');
    }

    // Approach 2: Try with different asset paths
    try {
      final assetPath = widget.imageData;
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          throw Exception('Asset not found');
        },
      );
    } catch (e) {
      print('Failed to load as direct asset: $e');
    }

    // Approach 3: Try to load from the Render server if it's a known image
    try {
      final imageName = path.basename(widget.imageData);
      final serverUrl =
          '${ServerConfig.imageProcessingServerUrl}/api/images/$imageName';

      return Image.network(
        serverUrl,
        fit: BoxFit.contain,
        headers: ImageService.getWebHeaders(),
        errorBuilder: (context, error, stackTrace) {
          throw Exception('Server image not found');
        },
      );
    } catch (e) {
      print('Failed to load from server: $e');
    }

    // Approach 4: Show a placeholder with download option
    return _buildWebLocalImagePlaceholder();
  }

  Widget _buildWebLocalImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Local image not available on web',
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Image: ${path.basename(widget.imageData)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebFallbackImage() {
    // For web, try loading with different approaches
    return FutureBuilder<Widget>(
      future: _tryAlternativeImageLoading(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return _buildErrorWidget('Image not available on mobile web');
      },
    );
  }

  Future<Widget> _tryAlternativeImageLoading() async {
    // Try different approaches for mobile web
    try {
      // Approach 1: Try converting to base64
      final base64Image = await ImageService.convertImageToBase64(
        widget.imageData,
      );
      if (base64Image != null) {
        return Image.memory(
          base64Decode(base64Image.split(',')[1]),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            throw Exception('Failed to load base64 image');
          },
        );
      }
    } catch (e) {
      print('Failed to convert image to base64: $e');
    }

    // Approach 2: Try with different headers
    try {
      return Image.network(
        widget.imageData,
        fit: BoxFit.contain,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        errorBuilder: (context, error, stackTrace) {
          throw Exception('Failed with custom headers');
        },
      );
    } catch (e) {
      // Approach 3: Try without any headers
      try {
        return Image.network(
          widget.imageData,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            throw Exception('Failed without headers');
          },
        );
      } catch (e) {
        // Approach 4: Show a placeholder with download option
        return _buildMobileWebPlaceholder();
      }
    }
  }

  Widget _buildMobileWebPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Image not available on mobile web',
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _openImageInNewTab(),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _openImageInNewTab() {
    if (kIsWeb) {
      // Open image in new tab for mobile web users
      final url = widget.imageData;
      // This will be handled by the web platform
      // You might need to implement a custom solution here
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.imageData.length > 100
                  ? '${widget.imageData.substring(0, 100)}...'
                  : widget.imageData,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the full path for local images
  Future<String?> _getLocalImagePath(String relativePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = path.join(appDir.path, relativePath);

      final file = File(fullPath);
      final exists = await file.exists();

      if (exists) {
        return fullPath;
      } else {
        // Try alternative paths
        final altPaths = [
          path.join(appDir.path, 'images', path.basename(relativePath)),
          path.join(appDir.path, 'assets', relativePath),
          relativePath, // Try as absolute path
        ];

        for (final altPath in altPaths) {
          final altFile = File(altPath);
          if (await altFile.exists()) {
            return altPath;
          }
        }

        return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.title != null
            ? Text(widget.title!, style: const TextStyle(color: Colors.white))
            : const Text('Image Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            onPressed: () {
              if (_scale < _maxScale) {
                setState(() {
                  _scale = (_scale + 0.5).clamp(_minScale, _maxScale);
                });
                _transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              }
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            onPressed: () {
              if (_scale > _minScale) {
                setState(() {
                  _scale = (_scale - 0.5).clamp(_minScale, _maxScale);
                });
                _transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              }
            },
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _scale = _minScale;
              });
              _transformationController.value = Matrix4.identity();
            },
            tooltip: 'Reset Zoom',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
      body: _buildImageContent(),
    );
  }
}

// Helper function to show the enhanced image viewer
void showEnhancedImageViewer(
  BuildContext context,
  String imageData, {
  String? title,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          EnhancedImageViewer(imageData: imageData, title: title),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}
