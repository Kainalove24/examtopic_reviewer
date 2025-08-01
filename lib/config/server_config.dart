// Server Configuration
class ServerConfig {
  // Image Processing Server Configuration
  static const String imageProcessingServerUrl =
      'https://image-processing-server-0ski.onrender.com';

  // API Endpoints
  static const String processImagesEndpoint = '/api/process-images';
  static const String healthCheckEndpoint = '/api/health';
  static const String statsEndpoint = '/api/stats';

  // Full URLs
  static String get processImagesUrl =>
      '$imageProcessingServerUrl$processImagesEndpoint';
  static String get healthCheckUrl =>
      '$imageProcessingServerUrl$healthCheckEndpoint';
  static String get statsUrl => '$imageProcessingServerUrl$statsEndpoint';

  // Timeout settings
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration imageProcessingTimeout = Duration(seconds: 60);

  // Retry settings
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Validation
  static bool get isServerConfigured => imageProcessingServerUrl.isNotEmpty;

  /// Get the full URL for a processed image
  static String getProcessedImageUrl(String imagePath) {
    return '$imageProcessingServerUrl$imagePath';
  }
}
