# Quick Start Guide for Philippines 🇵🇭

This is your personalized quick start guide for setting up Orbiter from the Philippines.

## ✅ What's Already Done (by Bob)

I've already set up the foundation for you:
- ✅ Flutter project created with all directories
- ✅ Go agent project with API endpoints
- ✅ All dependencies configured
- ✅ Theme system implemented
- ✅ Tests created and passing
- ✅ Documentation written

## 🎯 What YOU Need to Do Next

Follow these steps in order. Each should take 5-15 minutes.

### Step 1: Install IBM Cloud CLI (5 minutes)

**Option A: Direct Download (Recommended)**
1. Go to: https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases/latest
2. Download: `IBM_Cloud_CLI_x.x.x_windows_amd64.exe` (latest version)
3. Run the installer
4. Follow the installation wizard

**Option B: Using PowerShell**
```powershell
# Download the latest installer script
iex (New-Object Net.WebClient).DownloadString('https://clis.cloud.ibm.com/install/powershell')
```

**Option C: Using Chocolatey (if you have it)**
```powershell
choco install ibmcloud-cli
```

After installation, **restart your terminal** and verify:
```bash
ibmcloud --version
```

You should see something like: `ibmcloud version 2.x.x`

### Step 2: Create IBM Cloud Account (10 minutes)

1. Go to: https://cloud.ibm.com
2. Click "Create an account" (FREE - no credit card needed for lite tier)
3. Use your email
4. Verify your email
5. Complete profile setup

### Step 3: Login to IBM Cloud (2 minutes)

```bash
ibmcloud login
# Enter your email and password when prompted
```

### Step 4: Set Up watsonx.ai (10 minutes)

**Important: Use Tokyo (jp-tok) region - it's closest to Philippines!**

```bash
# Target Tokyo region (closest to Philippines)
ibmcloud target -r jp-tok

# Create resource group
ibmcloud resource group-create orbiter-rg

# Create watsonx.ai instance
ibmcloud resource service-instance-create orbiter-watsonx pm-20 lite jp-tok -g orbiter-rg

# Create API key
ibmcloud iam api-key-create orbiter-api-key -d "Orbiter API Key" --file orbiter-api-key.json
```

**Save your API key!** Open `orbiter-api-key.json` and copy the `apikey` value.

### Step 5: Get watsonx Project ID (5 minutes)

1. Go to: https://dataplatform.cloud.ibm.com/wx/home
2. Click "Create a project" or use existing
3. Go to project settings (gear icon)
4. Copy the **Project ID** (you'll need this!)

### Step 6: Create .env File (3 minutes)

In your project root (`d:/ibm-bob-day/`), create a file named `.env`:

```env
# IBM Cloud Configuration (Tokyo region for Philippines)
IBM_CLOUD_API_KEY=paste_your_api_key_here
WATSONX_PROJECT_ID=paste_your_project_id_here
WATSONX_URL=https://jp-tok.ml.cloud.ibm.com

# Object Storage (will set up later)
COS_ENDPOINT=https://s3.jp-tok.cloud-object-storage.appdomain.cloud
COS_BUCKET_NAME=orbiter-agent-binaries
COS_API_KEY=will_add_later

# Firebase (will set up later)
FIREBASE_SERVER_KEY=will_add_later
FIREBASE_PROJECT_ID=will_add_later

# Agent Configuration
AGENT_PORT=8080
AGENT_LOG_LEVEL=info
APP_ENV=development
```

### Step 7: Test watsonx.ai Connection (5 minutes)

```bash
# Get your IAM token
ibmcloud iam oauth-tokens

# Copy the Bearer token (the long string after "Bearer")
# Then test the API (replace YOUR_TOKEN and YOUR_PROJECT_ID):

curl -X POST "https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29" -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"model_id\":\"ibm/granite-13b-chat-v2\",\"input\":\"Hello from Philippines!\",\"parameters\":{\"max_new_tokens\":50},\"project_id\":\"YOUR_PROJECT_ID\"}"
```

If you see a response with generated text, **SUCCESS!** 🎉

### Step 8: Set Up Firebase (Optional - 10 minutes)

**Note:** Firebase is for push notifications. You can skip this for now and add it later.

1. Go to: https://console.firebase.google.com
2. Click "Add project"
3. Name: "Orbiter"
4. Follow the wizard (disable Analytics if you want)
5. Add Android app:
   - Package name: `com.orbiter.app`
   - Download `google-services.json`
   - Place in: `orbiter/android/app/google-services.json`

### Step 9: Set Up Object Storage (Optional - 10 minutes)

**Note:** This is for storing agent binaries. You can skip for now.

```bash
# Create Object Storage instance
ibmcloud resource service-instance-create orbiter-storage cloud-object-storage lite global -g orbiter-rg

# Create credentials
ibmcloud resource service-key-create orbiter-storage-key Writer --instance-name orbiter-storage
```

Then create bucket via web console at: https://cloud.ibm.com/objectstorage

---

## 🧪 Verify Everything Works

### Test Flutter App:
```bash
cd orbiter
flutter doctor
flutter test
```

### Test Go Agent:
```bash
cd agent
go run main.go
```

You should see: "Orbiter Agent starting on port :8080"

---

## 📊 Summary of Regions for Philippines

| Service | Region | Location | Distance from Manila |
|---------|--------|----------|---------------------|
| watsonx.ai | `jp-tok` | Tokyo, Japan | ~3,000 km |
| Object Storage | `jp-tok` | Tokyo, Japan | ~3,000 km |
| Alternative | `au-syd` | Sydney, Australia | ~6,000 km |
| Fallback | `us-south` | Dallas, USA | ~13,000 km |

**Always use `jp-tok` (Tokyo) for best performance from Philippines!**

---

## ❓ What If Something Goes Wrong?

### IBM Cloud CLI won't install
- Try running PowerShell as Administrator
- Check Windows Defender isn't blocking it

### Can't login to IBM Cloud
- Make sure you verified your email
- Try `ibmcloud login --sso` for SSO login

### watsonx.ai creation fails
- Check if you're in the right region: `ibmcloud target`
- Try the web console: https://cloud.ibm.com/catalog/services/watsonx-ai

### API test fails
- Make sure your token is fresh (tokens expire)
- Check your Project ID is correct
- Verify you're using jp-tok endpoint

---

## 🎯 What's Next?

Once you complete these steps:

1. ✅ You'll have IBM Cloud set up
2. ✅ watsonx.ai will be ready to use
3. ✅ Your .env file will be configured
4. ✅ You can start building features!

**Next Phase:** Phase 1 - SSH Connectivity
- We'll implement SSH connections to servers
- Add server management features
- Build the terminal interface

---

## 💡 Pro Tips for Philippines

1. **Use Tokyo region** - Always choose `jp-tok` for lowest latency
2. **Test during off-peak hours** - Internet is faster late night/early morning
3. **Keep credentials safe** - Never commit `.env` to git
4. **Use mobile hotspot** - If home internet is slow, mobile data might be faster for API calls
5. **Check IBM Cloud status** - Visit https://cloud.ibm.com/status if services seem down

---

## 📞 Need Help?

- IBM Cloud Docs: https://cloud.ibm.com/docs
- watsonx.ai Docs: https://dataplatform.cloud.ibm.com/docs/content/wsj/getting-started/welcome-main.html
- Check `PHASE0_SETUP_GUIDE.md` for detailed troubleshooting

---

**Good luck! You're doing great! 🚀**

*Estimated total time: 45-60 minutes*
*Most important: Steps 1-7 (about 40 minutes)*