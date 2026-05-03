# Phase 4: IBM Cloud Integration

**Goal:** Integrate watsonx.ai, Cloud Functions, and push notifications.

---

## 4.1 IBM watsonx.ai Client

### Create Watsonx Client (lib/core/ibm/watsonx_client.dart)

**Tasks:**
- [ ] Implement IAM authentication
- [ ] Create text generation wrapper
- [ ] Support multiple models (Granite, Llama 3)
- [ ] Add token counting
- [ ] Implement error handling and retries
- [ ] Add request/response logging

**Client Implementation:**
```dart
class WatsonxClient {
  final String apiKey;
  final String projectId;
  final String region = 'us-south';
  
  Future<String> generateText({
    required String modelId,
    required String input,
    Map<String, dynamic>? parameters,
  }) async {
    final token = await getIAMToken();
    
    final response = await dio.post(
      'https://$region.ml.cloud.ibm.com/ml/v1/text/generation',
      queryParameters: {'version': '2023-05-29'},
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      data: {
        'model_id': modelId,
        'input': input,
        'parameters': parameters ?? {
          'max_new_tokens': 500,
          'temperature': 0.7,
        },
        'project_id': projectId,
      },
    );
    
    return response.data['results'][0]['generated_text'];
  }
  
  Future<String> getIAMToken() async {
    // Implement IAM token retrieval
  }
}
```

**Available Models:**
- `ibm/granite-13b-chat-v2` - Fast, general purpose
- `meta-llama/llama-3-70b-instruct` - Complex reasoning
- `ibm/granite-20b-code-instruct` - Code analysis

---

## 4.2 IBM Cloud Functions (Push Relay)

### Create Cloud Function (cloud-functions/push-relay.js)

**Tasks:**
- [ ] Create Node.js function for push relay
- [ ] Configure Firebase Admin SDK
- [ ] Deploy to IBM Cloud Functions
- [ ] Test with curl
- [ ] Get function URL

**Function Code:**
```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  })
});

async function main(params) {
  const { serverId, serverName, alertType, message, deviceToken } = params;
  
  if (!deviceToken || !message) {
    return { statusCode: 400, body: { error: 'Missing parameters' } };
  }
  
  const notification = {
    notification: {
      title: `⚠️ ${serverName || 'Server'} Alert`,
      body: message
    },
    data: {
      serverId: serverId || '',
      alertType: alertType || 'threshold',
      timestamp: new Date().toISOString()
    },
    token: deviceToken
  };
  
  try {
    const response = await admin.messaging().send(notification);
    return { statusCode: 200, body: { success: true, messageId: response } };
  } catch (error) {
    return { statusCode: 500, body: { error: error.message } };
  }
}

exports.main = main;
```

**Deploy:**
```bash
ibmcloud fn action create orbiter-push-relay push-relay.js \
  --kind nodejs:18 \
  --web true \
  --param FIREBASE_PROJECT_ID "your-project-id" \
  --param FIREBASE_CLIENT_EMAIL "your-email" \
  --param FIREBASE_PRIVATE_KEY "your-key"

# Get URL
ibmcloud fn action get orbiter-push-relay --url
```

---

## 4.3 Push Notifications Setup

### Configure FCM (lib/core/notifications/notification_service.dart)

**Tasks:**
- [ ] Add Firebase to Flutter app
- [ ] Configure FCM in Android (google-services.json)
- [ ] Configure FCM in iOS (GoogleService-Info.plist)
- [ ] Request notification permissions
- [ ] Get FCM device token
- [ ] Store token securely
- [ ] Handle foreground notifications
- [ ] Handle background notifications
- [ ] Implement notification tap handling (deep link)

**Notification Service:**
```dart
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission();
    
    // Get token
    final token = await _messaging.getToken();
    await saveDeviceToken(token);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(message);
    });
    
    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleNotificationTap(message);
    });
  }
  
  void handleNotificationTap(RemoteMessage message) {
    final serverId = message.data['serverId'];
    // Navigate to server dashboard
    navigateToServer(serverId);
  }
}
```

---

## 4.4 Alert Configuration UI

### Create Alert Settings Screen (lib/features/alerts/alert_settings_screen.dart)

**Tasks:**
- [ ] Create alert configuration form
- [ ] Set thresholds per server (CPU, RAM, disk)
- [ ] Enable/disable alerts per metric
- [ ] Add "Silence alerts" for X hours
- [ ] Show alert history
- [ ] Test alert button

**Alert Settings UI:**
```dart
AlertSettings(
  server: currentServer,
  cpuThreshold: 85.0,
  ramThreshold: 90.0,
  diskThreshold: 80.0,
  onSave: (settings) => saveAlertSettings(settings),
  onTest: () => sendTestAlert(),
)
```

**Alert History:**
```dart
AlertHistory(
  alerts: alertHistory,
  onTap: (alert) => showAlertDetails(alert),
)
```

---

## 4.5 Object Storage Integration

### Create Object Storage Client (lib/core/ibm/object_storage_client.dart)

**Tasks:**
- [ ] Implement binary download from Object Storage
- [ ] Add checksum verification
- [ ] Implement version checking
- [ ] Add caching to avoid redundant downloads
- [ ] Show download progress

**Object Storage Client:**
```dart
class ObjectStorageClient {
  final String bucketUrl = 'https://orbiter-agent-binaries.s3.us-south.cloud-object-storage.appdomain.cloud';
  
  Future<AgentBinary> downloadAgent(String architecture) async {
    // Get latest version
    final versionResponse = await dio.get('$bucketUrl/version.json');
    final version = versionResponse.data['version'];
    
    // Download binary
    final binaryUrl = '$bucketUrl/agent-$architecture-v$version';
    final response = await dio.get(
      binaryUrl,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        updateProgress(received / total);
      },
    );
    
    // Verify checksum
    final checksumResponse = await dio.get('$bucketUrl/checksums.sha256');
    final expectedChecksum = parseChecksum(checksumResponse.data, architecture, version);
    final actualChecksum = sha256.convert(response.data).toString();
    
    if (actualChecksum != expectedChecksum) {
      throw Exception('Checksum verification failed');
    }
    
    return AgentBinary(
      data: response.data,
      version: version,
      architecture: architecture,
    );
  }
}
```

---

## 4.6 End-to-End Alert Flow

### Test Alert Flow

**Flow:**
1. Agent detects threshold breach (e.g., CPU > 85%)
2. Agent POSTs to IBM Cloud Functions endpoint
3. Cloud Function sends push via FCM
4. User receives notification on device
5. User taps notification → opens Orbiter to affected server

**Test:**
```dart
Future<void> testAlertFlow() async {
  // Trigger test alert from app
  await agentApi.triggerTestAlert(
    serverId: currentServer.id,
    serverName: currentServer.nickname,
    alertType: 'test',
    message: 'This is a test alert',
    deviceToken: await getDeviceToken(),
  );
  
  // Should receive notification within 2 seconds
}
```

---

## Phase 4 Checklist

- [ ] watsonx.ai client working
- [ ] Can call Granite and Llama 3 models
- [ ] Cloud Functions deployed
- [ ] Push notifications configured (Android + iOS)
- [ ] Can receive alerts on device
- [ ] Alert configuration UI complete
- [ ] Alert history visible
- [ ] Object Storage downloading binaries
- [ ] Checksum verification working
- [ ] End-to-end alert flow tested

**Demo:** Configure CPU alert at 85%, trigger alert, receive push notification, tap to open server.

**Next:** Phase 5 - Build AI features (natural language commands, log analysis, MigrationPilot).