# IBM watsonx.ai Setup Guide for Orbiter POC

## ✅ Good News!
Based on your screenshot, you already have:
- ✅ A watsonx.ai project created
- ✅ watsonx.ai Runtime service associated ("watsonx Challenge WML")

## What You Need Now

### 1. Get Your Project ID

**From the screenshot location (Services tab):**
1. You're already in your project
2. Click on the **"Manage"** tab (next to Services)
3. Look for **"General"** section
4. Find and copy the **Project ID** (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

**Alternative way:**
1. Look at your browser URL - it should contain the project ID
2. Format: `https://dataplatform.cloud.ibm.com/projects/YOUR-PROJECT-ID-HERE/...`

### 2. Get Your IBM Cloud API Key

**If you already have one:**
- Use the existing API key from your `.env` file: `cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12`

**If you need a new one:**
1. Click your **profile icon** (top-right corner)
2. Select **"Profile and settings"** or **"Manage"** → **"Access (IAM)"**
3. Go to **"API keys"** section
4. Click **"Create"** or **"Create an IBM Cloud API key"**
5. Name it: `Orbiter watsonx API Key`
6. Click **"Create"**
7. **IMPORTANT**: Copy the API key immediately!

### 3. Update Your Flutter Code

Open `orbiter/lib/main.dart` and find line ~408 where it says:

```dart
final watsonx = WatsonXService(
  apiKey: 'cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12',
  projectId: 'e33f9d2e-aaef-493f-9363-b4720c98ddbe',  // ← CHANGE THIS
  url: 'https://jp-tok.ml.cloud.ibm.com',
);
```

**Replace the `projectId` with YOUR actual Project ID from Step 1.**

### 4. Verify the API Key Works

Test if your current API key is valid:

```bash
# Test getting IAM token
curl -X POST 'https://iam.cloud.ibm.com/identity/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12'
```

If you get a token back, the API key is valid! ✅

### 5. Test in Your App

1. Update the Project ID in code (Step 3)
2. Run: `flutter run`
3. Connect to your agent
4. Click **"Analyze Nginx Logs with AI"**
5. Watch the Flutter console for any errors

## Common Errors & Solutions

### Error: "Failed to get access token"
**Cause**: API key is invalid or expired

**Solution**:
1. Create a new API key (see Step 2)
2. Update it in `orbiter/lib/main.dart` line 408

### Error: "Project not found" or 403 Forbidden
**Cause**: Wrong Project ID or API key doesn't have access

**Solution**:
1. Double-check your Project ID (Step 1)
2. Make sure the API key belongs to the same IBM Cloud account as the project
3. Verify the watsonx.ai Runtime service is associated (you already have this ✅)

### Error: "Model not found"
**Cause**: Model ID might not be available in your region

**Solution**: Try different models in `orbiter/lib/core/ai/watsonx_service.dart` line 60:

```dart
'model_id': 'ibm/granite-13b-chat-v2',  // Current
// Try these alternatives:
// 'model_id': 'ibm/granite-13b-instruct-v2',
// 'model_id': 'meta-llama/llama-3-8b-instruct',
// 'model_id': 'google/flan-t5-xxl',
```

### Error: Rate limit exceeded
**Cause**: Free tier limits (20 requests/minute)

**Solution**: Wait 1 minute between AI analysis requests

## Debugging Steps

### 1. Add Debug Logging

Edit `orbiter/lib/core/ai/watsonx_service.dart` and add print statements:

```dart
Future<String> _getAccessToken() async {
  print('🔑 Getting IAM token...');
  print('🔑 API Key: ${apiKey.substring(0, 10)}...');
  
  final response = await http.post(...);
  
  print('🔑 Token response: ${response.statusCode}');
  if (response.statusCode != 200) {
    print('❌ Token error: ${response.body}');
  }
  // ... rest of code
}

Future<String> analyzeLogs(List<String> logLines) async {
  print('🤖 Analyzing logs with watsonx.ai...');
  print('🤖 Project ID: $projectId');
  print('🤖 URL: $url');
  print('🤖 Model: ibm/granite-13b-chat-v2');
  
  final token = await _getAccessToken();
  print('🤖 Got token, making request...');
  
  final response = await http.post(...);
  
  print('🤖 Response status: ${response.statusCode}');
  if (response.statusCode != 200) {
    print('❌ Error response: ${response.body}');
  }
  // ... rest of code
}
```

### 2. Check Flutter Console

When you click "Analyze Nginx Logs with AI", look for:
- 🔑 Token messages → Shows if API key works
- 🤖 Analysis messages → Shows if watsonx.ai call works
- ❌ Error messages → Shows what went wrong

### 3. Test API Directly

Use curl to test outside the app:

```bash
# Step 1: Get token
TOKEN=$(curl -s -X POST 'https://iam.cloud.ibm.com/identity/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=YOUR_API_KEY' \
  | jq -r '.access_token')

echo "Token: $TOKEN"

# Step 2: Test watsonx.ai
curl -X POST 'https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "model_id": "ibm/granite-13b-chat-v2",
    "input": "Analyze this nginx log: 192.168.1.1 - - [01/Jan/2024:12:00:00] GET /api/health 200",
    "parameters": {
      "max_new_tokens": 100
    },
    "project_id": "YOUR_PROJECT_ID_HERE"
  }'
```

## Quick Checklist

- [x] watsonx.ai project exists
- [x] watsonx.ai Runtime service associated
- [ ] Project ID copied from Manage tab
- [ ] API key verified (test with curl)
- [ ] Project ID updated in code (line 408 of main.dart)
- [ ] App tested - AI button clicked
- [ ] Errors checked in Flutter console

## What Your Screenshot Shows

✅ **You have:**
- Project with watsonx.ai Runtime service
- Service name: "watsonx Challenge WML"
- Service type: "watsonx.ai Runtime"

🎯 **You need:**
- The Project ID (from Manage tab)
- Update it in the code

## Region Information

Your service appears to be in the **Tokyo region** (based on your .env file).

**Endpoint**: `https://jp-tok.ml.cloud.ibm.com`

This is correct for Philippines (lowest latency).

## Support

If you still have issues after following these steps:

1. **Check the error message** in Flutter console
2. **Match it** with the "Common Errors" section above
3. **Try the debugging steps** to see where it fails
4. **Test with curl** to isolate if it's an app issue or API issue

---

**Next Step**: Get your Project ID from the Manage tab and update line 408 in `orbiter/lib/main.dart`!

**Made with Bob** 🤖