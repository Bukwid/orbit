# CORS Issue Solution for watsonx.ai

## 🚨 The Problem

The error `Failed to fetch, uri=https://iam.cloud.ibm.com/identity/token` means:

**You're running the Flutter app in a web browser**, and browsers block direct API calls to IBM Cloud due to CORS (Cross-Origin Resource Sharing) security restrictions.

## ✅ Solutions (Choose One)

### Solution 1: Run on Mobile/Desktop (RECOMMENDED for Demo)

**This is the easiest fix!** CORS only affects web browsers.

#### For Android:
```bash
cd orbiter
flutter run -d android
```

#### For Windows:
```bash
cd orbiter
flutter run -d windows
```

#### For iOS (Mac only):
```bash
cd orbiter
flutter run -d ios
```

**Why this works**: Mobile and desktop apps don't have CORS restrictions!

### Solution 2: Use Chrome with CORS Disabled (Quick Test)

**For testing only** - close all Chrome windows first:

#### Windows:
```bash
"C:\Program Files\Google\Chrome\Application\chrome.exe" --disable-web-security --user-data-dir="C:\temp\chrome_dev"
```

#### Mac:
```bash
open -n -a "Google Chrome" --args --disable-web-security --user-data-dir="/tmp/chrome_dev"
```

#### Linux:
```bash
google-chrome --disable-web-security --user-data-dir="/tmp/chrome_dev"
```

Then run:
```bash
cd orbiter
flutter run -d chrome
```

**⚠️ Warning**: Only use this for testing! Don't browse other sites with CORS disabled.

### Solution 3: Create a Proxy Backend (Production Solution)

Create a simple backend that proxies requests to IBM Cloud:

#### Option A: Use IBM Cloud Functions

1. Go to https://cloud.ibm.com/functions
2. Create a new action: "watsonx-proxy"
3. Use this code:

```javascript
async function main(params) {
  const fetch = require('node-fetch');
  
  // Get IAM token
  const tokenResponse = await fetch('https://iam.cloud.ibm.com/identity/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${params.apiKey}`
  });
  
  const tokenData = await tokenResponse.json();
  const token = tokenData.access_token;
  
  // Call watsonx.ai
  const response = await fetch('https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model_id: params.model_id,
      input: params.input,
      parameters: params.parameters,
      project_id: params.project_id
    })
  });
  
  return await response.json();
}
```

4. Enable as Web Action
5. Get the URL
6. Update Flutter code to call this URL instead

#### Option B: Simple Node.js Proxy

Create `proxy-server.js`:

```javascript
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
app.use(cors());
app.use(express.json());

app.post('/analyze', async (req, res) => {
  try {
    // Get token
    const tokenResponse = await fetch('https://iam.cloud.ibm.com/identity/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${req.body.apiKey}`
    });
    
    const tokenData = await tokenResponse.json();
    
    // Call watsonx.ai
    const response = await fetch('https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${tokenData.access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(req.body.payload)
    });
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => console.log('Proxy running on http://localhost:3000'));
```

Run:
```bash
npm install express cors node-fetch
node proxy-server.js
```

Update Flutter to call `http://localhost:3000/analyze`

### Solution 4: Add Agent Endpoint (BEST for Your Setup!)

Since you already have a Go agent, add a watsonx.ai proxy endpoint there!

Add to `agent/api/watsonx.go`:

```go
package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

type WatsonXRequest struct {
	APIKey    string   `json:"apiKey"`
	ProjectID string   `json:"projectId"`
	LogLines  []string `json:"logLines"`
}

func AnalyzeLogsWithWatsonX(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req WatsonXRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Get IAM token
	tokenReq := fmt.Sprintf("grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=%s", req.APIKey)
	tokenResp, err := http.Post(
		"https://iam.cloud.ibm.com/identity/token",
		"application/x-www-form-urlencoded",
		bytes.NewBufferString(tokenReq),
	)
	if err != nil {
		http.Error(w, "Failed to get token", http.StatusInternalServerError)
		return
	}
	defer tokenResp.Body.Close()

	var tokenData map[string]interface{}
	json.NewDecoder(tokenResp.Body).Decode(&tokenData)
	token := tokenData["access_token"].(string)

	// Call watsonx.ai
	prompt := "Analyze these nginx logs:\n"
	for _, line := range req.LogLines {
		prompt += line + "\n"
	}

	payload := map[string]interface{}{
		"model_id": "ibm/granite-13b-chat-v2",
		"input":    prompt,
		"parameters": map[string]interface{}{
			"max_new_tokens": 500,
		},
		"project_id": req.ProjectID,
	}

	payloadBytes, _ := json.Marshal(payload)
	watsonReq, _ := http.NewRequest(
		"POST",
		"https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29",
		bytes.NewBuffer(payloadBytes),
	)
	watsonReq.Header.Set("Authorization", "Bearer "+token)
	watsonReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	watsonResp, err := client.Do(watsonReq)
	if err != nil {
		http.Error(w, "Failed to call watsonx.ai", http.StatusInternalServerError)
		return
	}
	defer watsonResp.Body.Close()

	// Forward response
	w.Header().Set("Content-Type", "application/json")
	io.Copy(w, watsonResp.Body)
}
```

Add to `agent/main.go`:
```go
mux.HandleFunc("/api/watsonx/analyze", authMiddleware(api.AnalyzeLogsWithWatsonX))
```

Then update Flutter to call your agent instead!

## 🎯 Recommended for Hackathon Demo

**Use Solution 1: Run on Windows Desktop**

```bash
cd orbiter
flutter run -d windows
```

This will:
- ✅ Work immediately (no CORS issues)
- ✅ Look professional (native app)
- ✅ Be faster than web
- ✅ No proxy needed

## 📱 Quick Test

1. Close the web browser version
2. Run: `flutter run -d windows` (or android/ios)
3. Click "Analyze Nginx Logs with AI"
4. It should work! 🎉

## Why This Happens

- **Web browsers**: Block cross-origin requests for security
- **Mobile/Desktop apps**: No such restrictions
- **Solution**: Either run native app OR use a proxy

---

**For your hackathon demo, just use Windows/Android app instead of web!**

**Made with Bob** 🤖