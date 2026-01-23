# Gemini API Setup

This guide explains how to obtain a Gemini API token for use with the Goals app's AI-powered features.

## Prerequisites

- A Google account
- Internet access

## Step 1: Access Google AI Studio

1. Open your web browser
2. Navigate to [Google AI Studio](https://aistudio.google.com)
3. Sign in with your Google account

## Step 2: Create an API Key

1. Once signed in, click on **Get API key** in the left sidebar
2. Click **Create API key**
3. Select a Google Cloud project:
   - Choose an existing project, or
   - Click **Create API key in new project** to create a new one
4. Your API key will be generated and displayed

## Step 3: Copy Your API Key

1. Click the **Copy** button next to your API key
2. Store the key securely—you won't be able to view it again in full
3. Keep this key private and never share it publicly

## Step 4: Configure Goals App

1. Open the Goals app
2. Go to **Settings**
3. Find the **Gemini** section
4. Paste your API key in the **API Token** field
5. The app will validate the token automatically

## API Key Security

**Important:** Treat your API key like a password.

- Never commit API keys to version control
- Don't share your key publicly or in screenshots
- Rotate your key if you suspect it has been compromised
- Use environment variables or secure storage for development

### If Your Key Is Compromised

1. Go to [Google AI Studio](https://aistudio.google.com)
2. Click **Get API key** in the sidebar
3. Find the compromised key and click the **Delete** icon
4. Create a new API key
5. Update the key in all applications using it

## Usage Limits

Google AI Studio provides a free tier with usage limits:

| Model | Free Tier Limit |
|-------|-----------------|
| Gemini 1.5 Flash | 15 RPM, 1M TPM, 1500 RPD |
| Gemini 1.5 Pro | 2 RPM, 32K TPM, 50 RPD |
| Gemini 2.0 Flash | 10 RPM, 4M TPM, 1500 RPD |

*RPM = Requests per minute, TPM = Tokens per minute, RPD = Requests per day*

For higher limits, you can enable billing in Google Cloud Console.

## Troubleshooting

### "Invalid API key"
- Verify you copied the entire key without extra spaces
- Ensure the key hasn't been deleted in Google AI Studio
- Try creating a new API key

### "Quota exceeded"
- You've reached your rate limit—wait and try again
- Consider upgrading to a paid plan for higher limits

### "API not enabled"
- The Gemini API should be auto-enabled when creating a key
- If issues persist, manually enable it in [Google Cloud Console](https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com)

## More Information

- [Google AI Studio](https://aistudio.google.com)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Gemini API Pricing](https://ai.google.dev/pricing)
