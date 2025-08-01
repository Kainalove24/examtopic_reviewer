// API Configuration
// IMPORTANT: Replace the placeholder below with your actual OpenAI API key
// Get your API key from: https://platform.openai.com/account/api-keys
class ApiConfig {
  // OpenAI API Configuration
  // TODO: Replace this placeholder with your valid OpenAI API key
  static const String openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';

  // Other API configurations can be added here
  static const String openaiBaseUrl = 'https://api.openai.com/v1';

  // Model configurations
  static const String gpt4oModel = 'gpt-4o';
  static const String gpt4MiniModel = 'gpt-4o-mini';

  // Feature flags
  static const bool enableAiExplanations = true;
  static const bool enableImageProcessing =
      true; // Image processing is now implemented

  // Rate limiting and cost management
  static const int maxTokensPerRequest = 500;
  static const double temperature = 0.7;

  // Validation
  static bool get isApiKeyConfigured {
    return openaiApiKey.isNotEmpty &&
        openaiApiKey != 'YOUR_OPENAI_API_KEY_HERE' &&
        openaiApiKey.startsWith('sk-');
  }
}
