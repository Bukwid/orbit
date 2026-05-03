# Solution for Hackathon Shared Account

## 🎯 The Situation

You're using a **shared hackathon account** (3005602 - watsonx) and you're already IN the project "watsonx Hackathon Sandbox".

The issue is that your personal API key (`kennethleonardbuquid@gmail.com`) doesn't have access to the shared hackathon project.

## ✅ Solution: Use the Hackathon Account's API Key

### Option 1: Get API Key from Hackathon Organizers

Ask the hackathon organizers for:
- The API key for account `3005602`
- Or permission to create an API key in that account

### Option 2: Create API Key in the Hackathon Account

If you have permission:

1. **Make sure you're logged into the hackathon account**
   - Top-right should show: `3005602 - watsonx`
   - NOT your personal email

2. **Go to API Keys**:
   https://cloud.ibm.com/iam/apikeys

3. **Create new API key**:
   - Name: `Orbiter Demo Key`
   - Click "Create"
   - **Copy the key immediately**

4. **Update your code** (line 439 in `orbiter/lib/main.dart`):
   ```dart
   apiKey: 'THE_HACKATHON_ACCOUNT_API_KEY',
   ```

### Option 3: Create Your Own Project (RECOMMENDED)

Since you can't modify the shared project, create your own:

1. **Switch to your personal IBM Cloud account**
   - Click account dropdown (top-right)
   - Select your personal account (kennethleonardbuquid@gmail.com)

2. **Create new project**:
   - Go to: https://dataplatform.cloud.ibm.com/wx/home
   - Click "Create a project"
   - Choose "Create an empty project"
   - Name: `Orbiter Demo`
   - Click "Create"

3. **Associate Watson Machine Learning**:
   - Go to "Services" tab in your new project
   - Click "Associate service"
   - Select "Watson Machine Learning"
   - If you don't have one, create it (Lite/Free plan)

4. **Get your new Project ID**:
   - Go to "Manage" → "General"
   - Copy the Project ID

5. **Use your personal API key**:
   - You already have one that works!
   - The one that gave Token response: 200

6. **Update code** (line 440 in `orbiter/lib/main.dart`):
   ```dart
   projectId: 'YOUR_NEW_PROJECT_ID',  // From step 4
   ```

## 🎯 Recommended Approach for Hackathon

### Quick Fix: Use Your Own Account

This is the fastest way to get it working:

1. **Create your own free IBM Cloud account** (if you haven't):
   - Go to: https://cloud.ibm.com/registration
   - Use your personal email
   - Free tier is enough!

2. **Create watsonx.ai project** in YOUR account:
   - Go to: https://dataplatform.cloud.ibm.com/wx/home
   - Create project
   - Associate Watson Machine Learning (free)

3. **Use your own API key and Project ID**:
   ```dart
   apiKey: 'YOUR_PERSONAL_API_KEY',      // Already works!
   projectId: 'YOUR_NEW_PROJECT_ID',     // From your project
   ```

4. **Test** - it will work! ✅

### Why This Works

- ✅ You have full control
- ✅ No permission issues
- ✅ Free tier is enough for demo
- ✅ Can show it in hackathon
- ✅ Works immediately

## 📋 Step-by-Step: Create Your Own Setup

### Step 1: Verify Your Personal Account

1. Go to: https://cloud.ibm.com
2. Check if you're logged in with `kennethleonardbuquid@gmail.com`
3. If not, create account: https://cloud.ibm.com/registration

### Step 2: Create Watson Machine Learning Service

1. Go to: https://cloud.ibm.com/catalog/services/watson-machine-learning
2. Select **Lite (Free)** plan
3. Region: **Tokyo (jp-tok)**
4. Click "Create"

### Step 3: Create watsonx.ai Project

1. Go to: https://dataplatform.cloud.ibm.com/wx/home
2. Click "Create a project"
3. Choose "Create an empty project"
4. Name: `Orbiter Hackathon Demo`
5. Select the Cloud Object Storage (or create new one - free)
6. Click "Create"

### Step 4: Associate Service

1. In your new project, go to "Services" tab
2. Click "Associate service"
3. Select "Watson Machine Learning"
4. Choose the service you created in Step 2
5. Click "Associate"

### Step 5: Get Project ID

1. Go to "Manage" tab
2. Look for "General" section
3. Copy the **Project ID**
4. Save it!

### Step 6: Create API Key

1. Go to: https://cloud.ibm.com/iam/apikeys
2. Click "Create"
3. Name: `Orbiter Demo`
4. Click "Create"
5. **Copy the API key immediately!**

### Step 7: Update Code

Edit `orbiter/lib/main.dart` line 439-440:

```dart
final watsonx = WatsonXService(
  apiKey: 'YOUR_NEW_API_KEY_FROM_STEP_6',
  projectId: 'YOUR_NEW_PROJECT_ID_FROM_STEP_5',
  url: 'https://jp-tok.ml.cloud.ibm.com',
);
```

### Step 8: Test

```bash
# Hot reload
r
```

Click "Analyze Nginx Logs with AI" - it should work! ✅

## 🆘 Alternative: Mock the AI Response

If you can't get watsonx.ai working in time for the demo, you can mock it:

Edit `orbiter/lib/core/ai/watsonx_service.dart`:

```dart
Future<String> analyzeLogs(List<String> logLines) async {
  // TEMPORARY: Mock response for demo
  await Future.delayed(Duration(seconds: 2)); // Simulate API call
  
  return '''
📊 Nginx Log Analysis Summary:

1. Total Requests: ${logLines.length}
2. Status Codes: Mostly 200 (successful)
3. No critical errors detected
4. Top Paths: /api/health, /api/metrics
5. Security: No suspicious activity detected

All systems operating normally. ✅
''';
}
```

This gives you a working demo while you sort out the real API!

## 🎯 Summary

**Best option for hackathon**: Create your own free IBM Cloud account and project (Steps 1-8 above).

**Time estimate**: 10-15 minutes

**Cost**: $0 (Free tier)

**Result**: Working AI integration! ✅

---

**Made with Bob** 🤖