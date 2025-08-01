# OpenAI API Key Setup Guide

## 🔑 How to Configure Your OpenAI API Key

### Step 1: Get Your OpenAI API Key

1. **Visit OpenAI Platform**: Go to [https://platform.openai.com/account/api-keys](https://platform.openai.com/account/api-keys)
2. **Sign In**: Log in to your OpenAI account
3. **Create New Key**: Click "Create new secret key"
4. **Copy the Key**: Copy the generated API key (it starts with `sk-`)

### Step 2: Update the Configuration

1. **Open the config file**: Navigate to `lib/config/api_config.dart`
2. **Replace the placeholder**: Find this line:
   ```dart
   static const String openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
   ```
3. **Add your key**: Replace `YOUR_OPENAI_API_KEY_HERE` with your actual API key:
   ```dart
   static const String openaiApiKey = 'sk-your-actual-api-key-here';
   ```

### Step 3: Test the Configuration

1. **Save the file**
2. **Restart your Flutter app**
3. **Try generating an AI explanation** - it should work now!

## ⚠️ Important Notes

### Security
- **Never commit your API key to version control**
- **Keep your API key private and secure**
- **Don't share your API key publicly**

### Usage & Costs
- **Monitor your usage** at [https://platform.openai.com/usage](https://platform.openai.com/usage)
- **Set up billing** if you haven't already
- **The app uses minimal tokens** to keep costs low

### Troubleshooting

#### Error: "OpenAI API key not configured"
- Make sure you've replaced the placeholder in `api_config.dart`
- Ensure the key starts with `sk-`
- Restart the app after making changes

#### Error: "401 Unauthorized" or "Invalid API key"
- Your API key may be invalid or revoked
- Generate a new API key from OpenAI
- Check your OpenAI account for any issues

#### Error: "Rate limit exceeded"
- You've hit OpenAI's rate limits
- Wait a moment and try again
- Consider upgrading your OpenAI plan

## 🔧 Alternative Solutions

If you don't want to use OpenAI:

1. **Disable AI Explanations**: Turn off the feature in app settings
2. **Use a Different Provider**: Modify the code to use another AI service
3. **Local Explanations**: Create a database of pre-written explanations

## 📞 Support

If you continue having issues:
1. Check your OpenAI account status
2. Verify your API key is active
3. Ensure you have sufficient credits/billing set up 