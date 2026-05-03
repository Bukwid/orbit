# How to Create a Valid IBM Cloud API Key

## 🔑 The Error You're Seeing

```
❌ Token error: "Provided API key could not be found."
```

This means the API key `ApiKey-a93c8aa5-ba91-47a5-bb35-fbc1576e3da3` doesn't exist or was deleted.

## ✅ Create a New API Key (5 Steps)

### Step 1: Go to IBM Cloud API Keys Page
Open: https://cloud.ibm.com/iam/apikeys

### Step 2: Click "Create"
- Look for the blue **"Create"** button (top-right)
- Click it

### Step 3: Fill in Details
- **Name**: `Orbiter watsonx API Key`
- **Description**: `API key for Orbiter POC watsonx.ai integration`
- Click **"Create"**

### Step 4: Copy the API Key IMMEDIATELY
- A popup will show your new API key
- **IMPORTANT**: Copy it NOW - you can't see it again!
- It will look like: `aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890AbCd`
- Save it somewhere safe

### Step 5: Update Your Code
Open `orbiter/lib/main.dart` and find line 439:

```dart
apiKey: 'ApiKey-a93c8aa5-ba91-47a5-bb35-fbc1576e3da3',  // ← REPLACE THIS
```

Replace with your NEW API key:

```dart
apiKey: 'YOUR_NEW_API_KEY_HERE',  // ← Paste the key you just copied
```

## 🎯 Quick Steps Summary

1. Go to: https://cloud.ibm.com/iam/apikeys
2. Click **"Create"**
3. Name it: `Orbiter watsonx API Key`
4. Click **"Create"**
5. **COPY THE KEY** (you only see it once!)
6. Update line 439 in `orbiter/lib/main.dart`
7. Run: `flutter run -d windows`
8. Test the AI button again

## 📸 What You Should See

### In IBM Cloud Dashboard:
```
API keys
┌─────────────────────────────────────────┐
│ Name: Orbiter watsonx API Key           │
│ Created: Just now                       │
│ [Copy] [Delete]                         │
└─────────────────────────────────────────┘
```

### When You Create It:
```
┌─────────────────────────────────────────┐
│ API key successfully created            │
│                                         │
│ aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890   │
│                                         │
│ [Copy] [Download]                       │
│                                         │
│ ⚠️ This is the only time you'll see    │
│    this API key. Copy it now!          │
└─────────────────────────────────────────┘
```

## ⚠️ Common Mistakes

### Mistake 1: Using the API Key Name
❌ **Wrong**: `ApiKey-a93c8aa5-ba91-47a5-bb35-fbc1576e3da3`
✅ **Correct**: `aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890AbCd`

The API key is a long random string, NOT the name you give it!

### Mistake 2: Not Copying Immediately
If you close the popup without copying, you'll need to:
1. Delete the old key
2. Create a new one
3. Copy it this time!

### Mistake 3: Using Someone Else's Key
API keys are tied to YOUR IBM Cloud account. You can't use keys from tutorials or examples.

## 🧪 Test Your New API Key

After updating the code, test it with curl:

### Windows PowerShell:
```powershell
$apiKey = "YOUR_NEW_API_KEY_HERE"
$response = Invoke-RestMethod -Uri "https://iam.cloud.ibm.com/identity/token" `
  -Method POST `
  -Headers @{"Content-Type"="application/x-www-form-urlencoded"} `
  -Body "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$apiKey"

Write-Host "✅ API Key works! Token: $($response.access_token.Substring(0,50))..."
```

### Linux/Mac:
```bash
curl -X POST 'https://iam.cloud.ibm.com/identity/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=YOUR_NEW_API_KEY_HERE'
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

If you see this, your API key works! ✅

## 🔄 After Updating the Code

1. **Save** `orbiter/lib/main.dart`
2. **Hot reload** in Flutter (press `r` in terminal)
   - Or restart: `R`
3. Click **"Analyze Nginx Logs with AI"** again
4. Watch for 🔑 and 🤖 messages

You should see:
```
🔑 Getting new IAM token...
🔑 Token response: 200  ← Should be 200, not 400!
✅ Token obtained successfully
🤖 Starting log analysis...
```

## 📋 Checklist

- [ ] Went to https://cloud.ibm.com/iam/apikeys
- [ ] Clicked "Create"
- [ ] Named it "Orbiter watsonx API Key"
- [ ] Clicked "Create"
- [ ] Copied the API key (long random string)
- [ ] Updated line 439 in orbiter/lib/main.dart
- [ ] Saved the file
- [ ] Hot reloaded or restarted the app
- [ ] Tested the AI button
- [ ] Saw 🔑 Token response: 200 ✅

## 🆘 Still Not Working?

If you still get errors after creating a new API key:

1. **Double-check** you copied the entire key (no spaces)
2. **Verify** you're logged into the correct IBM Cloud account
3. **Test** the key with curl (see above)
4. **Share** the error message (without the full API key!)

---

**Next Step**: Create a new API key at https://cloud.ibm.com/iam/apikeys and update line 439!

**Made with Bob** 🤖