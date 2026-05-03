# watsonx.ai Troubleshooting Guide

## ✅ Your Current Setup

Based on your project URL, you have:
- **Project ID**: `e33f9d2e-aaef-493f-9363-b4720c98ddbe` ✅
- **API Key**: `cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12` ✅
- **Region**: Tokyo (jp-tok) ✅
- **Service**: watsonx.ai Runtime associated ✅

**These are already correctly configured in your code!**

## 🔍 Debug Mode Enabled

I've added detailed logging to `orbiter/lib/core/ai/watsonx_service.dart`. When you click "Analyze Nginx Logs with AI", you'll see:

- 🔑 Token acquisition steps
- 🤖 watsonx.ai request details
- ✅ Success messages
- ❌ Error messages with details

## 📋 Testing Steps

### 1. Test the App
```bash
cd orbiter
flutter run
```

### 2. Watch the Console
When you click "Analyze Nginx Logs with AI", look for these messages:

**Expected Success Flow:**
```
🔑 Getting new IAM token...
🔑 API Key: cqIi3Xpck5...
🔑 Token response: 200
✅ Token obtained successfully
🤖 Starting log analysis...
🤖 Project ID: e33f9d2e-aaef-493f-9363-b4720c98ddbe
🤖 URL: https://jp-tok.ml.cloud.ibm.com
🤖 Sending request to watsonx.ai...
🤖 Response status: 200
✅ Got response from watsonx.ai
✅ Analysis complete
```

**If You See Errors:**

#### Error 1: Token Issues (🔑 ❌)
```
❌ Token error: {"errorCode":"...","errorMessage":"..."}
```

**Possible causes:**
- API key is invalid/expired
- API key doesn't have correct permissions

**Solution:**
1. Go to https://cloud.ibm.com/iam/apikeys
2. Create a new API key
3. Update line 439 in `orbiter/lib/main.dart`

#### Error 2: Project Access (🤖 ❌ 403)
```
❌ watsonx.ai error (403): Forbidden
```

**Possible causes:**
- API key doesn't have access to the project
- Project ID is wrong

**Solution:**
1. Verify you're logged into the same IBM Cloud account
2. Check project access at: https://dataplatform.cloud.ibm.com/projects/e33f9d2e-aaef-493f-9363-b4720c98ddbe/manage/access-control
3. Ensure your user has "Admin" or "Editor" role

#### Error 3: Model Not Found (🤖 ❌ 404)
```
❌ watsonx.ai error (404): Model not found
```

**Solution:**
Try a different model. Edit `orbiter/lib/core/ai/watsonx_service.dart` line 88:

```dart
'model_id': 'ibm/granite-13b-instruct-v2',  // Try this instead
// Or try:
// 'model_id': 'meta-llama/llama-3-8b-instruct',
// 'model_id': 'google/flan-t5-xxl',
```

#### Error 4: Rate Limit (🤖 ❌ 429)
```
❌ watsonx.ai error (429): Too many requests
```

**Solution:**
- Wait 1 minute before trying again
- Free tier: 20 requests/minute

#### Error 5: Timeout
```
❌ Analysis failed: TimeoutException
```

**Solution:**
- Check your internet connection
- Try again (watsonx.ai might be slow)
- Increase timeout in code (currently 60 seconds)

### 3. Test API Key Directly

Test if your API key works:

```bash
# Windows PowerShell
$response = Invoke-RestMethod -Uri "https://iam.cloud.ibm.com/identity/token" `
  -Method POST `
  -Headers @{"Content-Type"="application/x-www-form-urlencoded"} `
  -Body "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12"

Write-Host "Token: $($response.access_token.Substring(0,50))..."
```

```bash
# Linux/Mac
curl -X POST 'https://iam.cloud.ibm.com/identity/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=cqIi3Xpck5rUngbDeUVeKa4441Mil73khj6KmFsa2L12'
```

**Expected output:**
```json
{
  "access_token": "eyJraWQiOiIyMDI0...",
  "refresh_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

If you get an error here, the API key is invalid.

### 4. Test watsonx.ai Directly

Once you have a token from step 3:

```bash
# Replace YOUR_TOKEN with the access_token from step 3
curl -X POST 'https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "model_id": "ibm/granite-13b-chat-v2",
    "input": "Hello, analyze this: 192.168.1.1 - - [01/Jan/2024:12:00:00] GET /api/health 200",
    "parameters": {
      "max_new_tokens": 100
    },
    "project_id": "e33f9d2e-aaef-493f-9363-b4720c98ddbe"
  }'
```

**Expected output:**
```json
{
  "model_id": "ibm/granite-13b-chat-v2",
  "results": [
    {
      "generated_text": "This is a successful API health check...",
      ...
    }
  ]
}
```

## 🔧 Common Fixes

### Fix 1: Regenerate API Key
1. Go to https://cloud.ibm.com/iam/apikeys
2. Find your old key → Delete it
3. Create new key: "Orbiter watsonx API Key"
4. Copy the new key
5. Update `orbiter/lib/main.dart` line 439

### Fix 2: Check Project Permissions
1. Go to your project: https://dataplatform.cloud.ibm.com/projects/e33f9d2e-aaef-493f-9363-b4720c98ddbe/manage/access-control
2. Check if your user is listed
3. Ensure role is "Admin" or "Editor"
4. If not, add yourself with Admin role

### Fix 3: Verify Service Association
1. Go to: https://dataplatform.cloud.ibm.com/projects/e33f9d2e-aaef-493f-9363-b4720c98ddbe/manage/services
2. Ensure "watsonx Challenge WML" is listed
3. If not, click "Associate service" and add Watson Machine Learning

### Fix 4: Try Different Model
Some models might not be available in your region. Edit `orbiter/lib/core/ai/watsonx_service.dart`:

```dart
// Line 88 - try these models one by one:
'model_id': 'ibm/granite-13b-instruct-v2',
// 'model_id': 'ibm/granite-13b-chat-v2',
// 'model_id': 'meta-llama/llama-3-8b-instruct',
// 'model_id': 'google/flan-t5-xxl',
```

## 📊 What to Share if Still Not Working

If it still doesn't work, share:

1. **Console output** - Copy all the 🔑 and 🤖 messages
2. **Error message** - The exact ❌ error text
3. **API key test result** - Output from step 3 above
4. **Project access screenshot** - From the access-control page

## 🎯 Quick Checklist

- [ ] API key tested with curl (step 3)
- [ ] Token obtained successfully
- [ ] Project ID matches: `e33f9d2e-aaef-493f-9363-b4720c98ddbe`
- [ ] Service associated in project
- [ ] User has Admin/Editor role
- [ ] Console shows detailed logs (🔑 🤖 messages)
- [ ] Error message identified

---

**Next Step**: Run `flutter run` and click the AI button. Watch the console for 🔑 and 🤖 messages!

**Made with Bob** 🤖