# Phase 0 Setup Guide - Orbiter Project

This guide walks you through setting up your development environment and IBM Cloud services for the Orbiter project.

## ✅ Completed Setup

### Development Environment
- ✅ **Flutter SDK**: Version 3.41.2 installed and working
- ✅ **Go**: Version 1.25.4 installed (exceeds requirement of 1.21+)
- ✅ **Git**: Version 2.44.0 installed
- ⚠️ **IBM Cloud CLI**: Not installed (see installation instructions below)

### Project Structure
- ✅ **Flutter Project**: Created at `./orbiter/`
- ✅ **Flutter Directory Structure**: All required directories created
- ✅ **Go Agent Project**: Created at `./agent/`
- ✅ **Go Module**: Initialized as `orbiter-agent`

### Dependencies
- ✅ **Flutter Dependencies**: Added to pubspec.yaml
  - dartssh2, xterm, fl_chart, flutter_secure_storage
  - riverpod, dio, web_socket_channel
  - firebase_messaging, file_picker
- ✅ **Go Dependencies**: Being installed
  - gorilla/websocket, shirou/gopsutil
  - docker/docker, coreos/go-systemd

### Theme System
- ✅ **Color System**: Created at `lib/shared/theme/colors.dart`
- ✅ **Theme Configuration**: Created at `lib/shared/theme/theme.dart`

### Testing Setup
- ✅ **Test Directories**: unit, integration, widget
- ✅ **Test Dependencies**: mockito, build_runner
- ✅ **Sample Test**: Created at `test/unit/sample_test.dart`

### Agent API Structure
- ✅ **Main Server**: `agent/main.go`
- ✅ **WebSocket Hub**: `agent/websocket/hub.go`
- ✅ **API Endpoints**: All 8 endpoints created
  - metrics.go, logs.go, services.go, exec.go
  - files.go, processes.go, cron.go, alerts.go
- ✅ **Build Script**: `agent/build.sh`

---

## 🔧 Remaining Setup Tasks

### 1. Install IBM Cloud CLI

**Windows - Option A: Direct Download (Recommended)**
1. Visit: https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases/latest
2. Download: `IBM_Cloud_CLI_x.x.x_windows_amd64.exe`
3. Run the installer and follow the wizard

**Windows - Option B: PowerShell Script**
```powershell
iex (New-Object Net.WebClient).DownloadString('https://clis.cloud.ibm.com/install/powershell')
```

**Windows - Option C: Chocolatey**
```powershell
choco install ibmcloud-cli
```

**Verify Installation:**
Restart your terminal, then run:
```bash
ibmcloud --version
```

### 2. IBM Cloud Account Setup

1. **Create Account**
   - Visit: https://cloud.ibm.com
   - Sign up for free tier (no credit card required for lite services)
   - Verify your email address

2. **Login via CLI**
   ```bash
   ibmcloud login
   # Or with SSO:
   ibmcloud login --sso
   ```

### 3. Provision watsonx.ai

**Region Selection for Philippines:**
- **Recommended**: `jp-tok` (Tokyo, Japan) - Closest to Philippines, ~3000km
- **Alternative**: `au-syd` (Sydney, Australia) - Also close, ~6000km
- **Fallback**: `us-south` (Dallas, USA) - If Tokyo/Sydney unavailable

1. **Create watsonx.ai Instance**
   ```bash
   # Set target region (Tokyo recommended for Philippines)
   ibmcloud target -r jp-tok
   
   # Create resource group (if needed)
   ibmcloud resource group-create orbiter-rg
   
   # Create watsonx.ai instance (use jp-tok for Philippines)
   ibmcloud resource service-instance-create orbiter-watsonx \
     pm-20 lite jp-tok -g orbiter-rg
   ```

2. **Generate API Key**
   ```bash
   # Create API key
   ibmcloud iam api-key-create orbiter-api-key \
     -d "API key for Orbiter project" \
     --file orbiter-api-key.json
   ```

3. **Get Project ID**
   - Visit: https://dataplatform.cloud.ibm.com/wx/home
   - Create a new project or use existing
   - Copy the Project ID from project settings

4. **Test API Connection**
   ```bash
   # First, get IAM token
   ibmcloud iam oauth-tokens
   
   # Test with curl (replace YOUR_IAM_TOKEN and YOUR_PROJECT_ID)
   # Use jp-tok endpoint for Philippines
   curl -X POST "https://jp-tok.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29" \
     -H "Authorization: Bearer YOUR_IAM_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "model_id": "ibm/granite-13b-chat-v2",
       "input": "Hello, how are you?",
       "parameters": {
         "max_new_tokens": 100
       },
       "project_id": "YOUR_PROJECT_ID"
     }'
   ```

5. **Save Credentials Securely**
   Create `.env` file in project root:
   ```env
   IBM_CLOUD_API_KEY=your_api_key_here
   WATSONX_PROJECT_ID=your_project_id_here
   WATSONX_URL=https://jp-tok.ml.cloud.ibm.com
   ```
   
   **Important:** Add `.env` to `.gitignore`!

### 4. Set Up IBM Cloud Object Storage

1. **Create Object Storage Instance**
   ```bash
   ibmcloud resource service-instance-create orbiter-storage \
     cloud-object-storage lite global -g orbiter-rg
   ```

2. **Create Service Credentials**
   ```bash
   ibmcloud resource service-key-create orbiter-storage-key \
     Writer --instance-name orbiter-storage
   ```

3. **Create Bucket via Web Console**
   - Visit: https://cloud.ibm.com/objectstorage
   - Select your instance
   - Click "Create bucket"
   - Name: `orbiter-agent-binaries`
   - Resiliency: Regional
   - Location: jp-tok (Tokyo - closest to Philippines)
   - Storage class: Standard

4. **Set Public Access**
   - Go to bucket settings
   - Access policies → Public access
   - Enable "Public access" for read operations
   - Note the public endpoint URL

5. **Save Bucket Details**
   Add to `.env`:
   ```env
   COS_ENDPOINT=https://s3.jp-tok.cloud-object-storage.appdomain.cloud
   COS_BUCKET_NAME=orbiter-agent-binaries
   COS_API_KEY=your_cos_api_key_here
   ```

### 5. Set Up Firebase

1. **Create Firebase Project**
   - Visit: https://console.firebase.google.com
   - Click "Add project"
   - Name: "Orbiter"
   - Disable Google Analytics (optional)

2. **Add Android App**
   - Click "Add app" → Android
   - Package name: `com.orbiter.app`
   - Download `google-services.json`
   - Place in: `orbiter/android/app/google-services.json`

3. **Add iOS App**
   - Click "Add app" → iOS
   - Bundle ID: `com.orbiter.app`
   - Download `GoogleService-Info.plist`
   - Place in: `orbiter/ios/Runner/GoogleService-Info.plist`

4. **Enable Cloud Messaging**
   - Go to Project Settings → Cloud Messaging
   - Enable Cloud Messaging API
   - Copy Server Key

5. **Generate Admin SDK Credentials**
   - Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `firebase-admin-key.json`
   - Store securely (DO NOT commit to git!)

6. **Update .env**
   ```env
   FIREBASE_SERVER_KEY=your_server_key_here
   FIREBASE_PROJECT_ID=your_project_id_here
   ```

---

## 🧪 Verification Steps

### 1. Test Flutter Setup
```bash
cd orbiter
flutter doctor
flutter pub get
flutter test
```

### 2. Test Go Agent
```bash
cd agent
go mod tidy
go build -o bin/orbiter-agent main.go
./bin/orbiter-agent
```

### 3. Test IBM Cloud CLI
```bash
ibmcloud target
ibmcloud resource service-instances
```

### 4. Verify Project Structure
```bash
# From project root
tree -L 3
```

Expected structure:
```
.
├── orbiter/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   ├── test/
│   │   ├── unit/
│   │   ├── integration/
│   │   └── widget/
│   └── pubspec.yaml
├── agent/
│   ├── api/
│   ├── websocket/
│   ├── main.go
│   ├── go.mod
│   └── build.sh
└── .env (create this)
```

---

## 📋 Phase 0 Completion Checklist

- [x] Flutter SDK installed and working
- [x] Go 1.21+ installed
- [ ] IBM Cloud CLI installed
- [x] Git installed
- [ ] IBM Cloud account created
- [ ] watsonx.ai instance provisioned
- [ ] watsonx.ai API tested
- [ ] Object Storage bucket created
- [ ] Firebase project set up
- [x] Flutter project created
- [x] Flutter directory structure complete
- [x] Go agent project initialized
- [x] All dependencies added
- [x] Theme system implemented
- [x] Test structure created
- [x] Sample test passing

---

## 🚀 Next Steps

Once all items are checked:
1. Commit your code (excluding `.env` and credentials!)
2. Proceed to **Phase 1: SSH Connectivity**
3. Start implementing SSH connection features

---

## 📝 Notes

- Keep all API keys and credentials secure
- Never commit `.env` or credential files to git
- Use environment variables for sensitive data
- Test each service independently before integration
- Document any issues or deviations from this guide

---

## 🆘 Troubleshooting

### Flutter Issues
- Run `flutter doctor` to diagnose
- Clear cache: `flutter clean && flutter pub get`

### Go Issues
- Run `go mod tidy` to fix dependencies
- Check Go version: `go version`

### IBM Cloud Issues
- Verify login: `ibmcloud target`
- Check region: `ibmcloud regions`
- View resources: `ibmcloud resource service-instances`

### Firebase Issues
- Verify project exists in console
- Check package names match exactly
- Ensure config files are in correct locations

---

**Last Updated:** Phase 0 Implementation
**Status:** Foundation Complete - Cloud Services Pending