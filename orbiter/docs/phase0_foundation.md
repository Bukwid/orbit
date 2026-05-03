# Phase 0: Foundation & Setup

**Goal:** Get your development environment ready and IBM Cloud services provisioned.

---

## 0.1 Development Environment

### Install Required Tools
- [ ] Flutter SDK (stable channel) - `flutter doctor` should pass
- [ ] Go 1.21+ - `go version` should work
- [ ] IBM Cloud CLI - `ibmcloud --version`
- [ ] Android Studio or Xcode for mobile development
- [ ] VS Code with Flutter and Go extensions
- [ ] Git for version control

---

## 0.2 IBM Cloud Services Setup

### Create IBM Cloud Account
- [ ] Sign up at https://cloud.ibm.com (free tier available)
- [ ] Verify email and complete account setup

### Provision watsonx.ai
- [ ] Create watsonx.ai instance (us-south region recommended)
- [ ] Generate IAM API key with watsonx.ai access
- [ ] Test API connection:
```bash
curl -X POST "https://us-south.ml.cloud.ibm.com/ml/v1/text/generation?version=2023-05-29" \
  -H "Authorization: Bearer YOUR_IAM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model_id":"ibm/granite-13b-chat-v2","input":"Hello"}'
```
- [ ] Save API key and project ID securely

### Set Up Object Storage
- [ ] Create IBM Cloud Object Storage instance
- [ ] Create bucket: `orbiter-agent-binaries`
- [ ] Set bucket to public read access
- [ ] Note bucket URL for later

### Set Up Firebase (for push notifications)
- [ ] Create Firebase project at https://console.firebase.google.com
- [ ] Add Android and iOS apps
- [ ] Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- [ ] Generate Firebase Admin SDK credentials (for Cloud Functions)

---

## 0.3 Project Structure

### Create Flutter Project
```bash
flutter create orbiter
cd orbiter
```

### Create Directory Structure
```
orbiter/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── ssh/
│   │   ├── agent/
│   │   ├── websocket/
│   │   ├── storage/
│   │   └── ibm/
│   ├── features/
│   │   ├── servers/
│   │   ├── dashboard/
│   │   ├── terminal/
│   │   ├── services/
│   │   ├── logs/
│   │   ├── alerts/
│   │   ├── cron/
│   │   ├── migration/
│   │   └── ai/
│   └── shared/
│       ├── widgets/
│       └── theme/
```

### Create Go Agent Project
```bash
mkdir agent
cd agent
go mod init orbiter-agent
```

### Create Agent Directory Structure
```
agent/
├── main.go
├── api/
│   ├── metrics.go
│   ├── logs.go
│   ├── services.go
│   ├── exec.go
│   ├── files.go
│   ├── processes.go
│   ├── cron.go
│   └── alerts.go
├── websocket/
│   └── hub.go
└── build.sh
```

---

## 0.4 Dependencies

### Flutter Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  dartssh2: ^2.12.0
  xterm: ^3.5.0
  fl_chart: ^0.65.0
  flutter_secure_storage: ^9.0.0
  riverpod: ^2.4.9
  dio: ^5.4.0
  web_socket_channel: ^2.4.0
  firebase_messaging: ^14.7.9
  file_picker: ^6.1.1
```

Run: `flutter pub get`

### Go Dependencies
```bash
go get github.com/gorilla/websocket
go get github.com/shirou/gopsutil/v3
go get github.com/docker/docker
go get github.com/coreos/go-systemd/v22
```

---

## 0.5 Theme Setup

### Create Color System (lib/shared/theme/colors.dart)
```dart
import 'package:flutter/material.dart';

class OrbiterColors {
  // Status colors
  static const healthy = Color(0xFF22C55E);      // Green
  static const warning = Color(0xFFF59E0B);      // Amber
  static const critical = Color(0xFFEF4444);     // Red
  static const interactive = Color(0xFF0F62FE);  // IBM Blue
  
  // Surfaces
  static const surfaceDark = Color(0xFF0F172A);
  static const surfaceLight = Color(0xFFF8FAFC);
}
```

### Create Theme (lib/shared/theme/theme.dart)
```dart
import 'package:flutter/material.dart';
import 'colors.dart';

class OrbiterTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: OrbiterColors.interactive,
      scaffoldBackgroundColor: OrbiterColors.surfaceDark,
      // Add more theme properties
    );
  }
  
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: OrbiterColors.interactive,
      scaffoldBackgroundColor: OrbiterColors.surfaceLight,
      // Add more theme properties
    );
  }
}
```

---

## 0.6 Basic Testing Setup

### Create Test Directory Structure
```
test/
├── unit/
├── integration/
└── widget/
```

### Add Test Dependencies (pubspec.yaml)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.7
```

### Create Sample Test (test/unit/sample_test.dart)
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sample test', () {
    expect(1 + 1, 2);
  });
}
```

Run: `flutter test`

---

## Phase 0 Checklist

- [ ] All development tools installed and working
- [ ] IBM Cloud account created
- [ ] watsonx.ai instance provisioned and tested
- [ ] Object Storage bucket created
- [ ] Firebase project set up
- [ ] Flutter project created with proper structure
- [ ] Go agent project initialized
- [ ] All dependencies installed
- [ ] Theme system implemented
- [ ] Sample tests passing

**Ready for Phase 1:** Once all checkboxes are complete, you're ready to start building SSH connectivity!