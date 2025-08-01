# How to Embed Your OpenAI API Key

## Quick Setup

### 1. **Edit the Configuration File**
Open `lib/config/api_config.dart` and replace the placeholder:

```dart
// Replace this line:
static const String openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';

// With your actual API key:
static const String openaiApiKey = 'sk-your-actual-api-key-here';
```

### 2. **That's It!**
The app will now automatically use your embedded API key. No need for users to configure anything.

## File Structure

```
lib/
├── config/
│   └── api_config.dart          ← Edit this file
├── services/
│   └── ai_service.dart          ← Uses the config
└── ...
```

## Security Considerations

### ✅ **What's Secure:**
- API key is compiled into the app
- No user configuration needed
- Works offline (except for API calls)

### ⚠️ **What to Consider:**
- API key is visible in the source code
- Anyone with the app can use your API key
- Consider rate limiting and usage monitoring

## Alternative Approaches

### Option 1: Environment Variables
```bash
# Set environment variable
export OPENAI_API_KEY="sk-your-key-here"
```

### Option 2: Build-time Configuration
```dart
// In api_config.dart
static const String openaiApiKey = String.fromEnvironment(
  'OPENAI_API_KEY',
  defaultValue: 'YOUR_OPENAI_API_KEY_HERE',
);
```

Then build with:
```bash
flutter build --dart-define=OPENAI_API_KEY=sk-your-key-here
```

### Option 3: Remote Configuration
Store the key on a server and fetch it at runtime (more complex but more secure).

## Usage

Once configured, users can:
1. Open any exam question
2. Click the purple psychology icon (🧠)
3. Get instant AI explanations

No additional setup required!

## Cost Management

- Monitor usage at: https://platform.openai.com/usage
- Set up billing alerts
- Consider implementing rate limiting
- Use appropriate models (GPT-4o-mini is cheaper than GPT-4o) 