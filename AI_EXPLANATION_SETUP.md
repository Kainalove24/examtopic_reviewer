# AI Explanation Feature Setup Guide

## Overview
The AI Explanation feature uses OpenAI's GPT models to provide intelligent explanations for exam questions. It automatically chooses between GPT-4o-mini (for text-only questions) and GPT-4o (for questions with images).

## Features
- **Smart Model Selection**: Automatically uses GPT-4o-mini for text questions and GPT-4o for image-based questions
- **Educational Explanations**: Provides detailed explanations that help students understand concepts, not just memorize answers
- **Secure API Key Storage**: API keys are stored locally and securely
- **User-Friendly Interface**: Easy-to-use settings and explanation dialogs

## Setup Instructions

### 1. Get an OpenAI API Key
1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the API key (starts with `sk-`)

### 2. Configure the API Key in the App
1. Open the app
2. Go to Settings (bottom navigation)
3. Find the "AI Explanations" section
4. Enable "Enable AI Explanations"
5. Click "Configure" next to "OpenAI API Key"
6. Enter your API key and save

### 3. Using AI Explanations
1. Navigate to any exam in the library
2. Open a question
3. Click the purple psychology icon (🧠) next to each question
4. The AI will generate an explanation for the question

## How It Works

### For Text-Only Questions
- Uses GPT-4o-mini for faster, cost-effective explanations
- Provides educational context and learning points
- Explains why answers are correct or incorrect

### For Questions with Images
- Uses GPT-4o for advanced image analysis
- Considers visual context in explanations
- Provides comprehensive explanations that reference image content

### Explanation Content
Each AI explanation includes:
- Why the correct answer is right
- Why incorrect answers are wrong (if applicable)
- Educational context and learning points
- Clear, exam-preparation focused language

## Security & Privacy
- API keys are stored locally on your device
- No question data is stored on external servers
- Explanations are generated in real-time and not cached
- Your data remains private and secure

## Troubleshooting

### "API Key Not Configured" Error
- Go to Settings → AI Explanations
- Make sure "Enable AI Explanations" is turned on
- Configure your OpenAI API key

### "Failed to Generate Explanation" Error
- Check your internet connection
- Verify your API key is correct
- Ensure you have sufficient OpenAI credits
- Try regenerating the explanation

### Slow Response Times
- GPT-4o responses may take longer than GPT-4o-mini
- Questions with images require more processing time
- Check your internet connection speed

## Cost Considerations
- GPT-4o-mini: ~$0.00015 per 1K tokens (very affordable)
- GPT-4o: ~$0.005 per 1K tokens (for image analysis)
- Typical explanations use 200-500 tokens
- Monitor your OpenAI usage at https://platform.openai.com/usage

## Future Enhancements
- Image processing for Flutter assets
- Caching of explanations for offline use
- Custom explanation styles and preferences
- Integration with study progress tracking 