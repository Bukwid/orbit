# Phase 5: AI Features & MigrationPilot

**Goal:** Implement watsonx.ai-powered features that differentiate Orbiter.

---

## 5.1 Natural Language Terminal

### Create Command Translator (lib/features/ai/command_translator.dart)

**Tasks:**
- [ ] Create AI command translation UI
- [ ] Implement command preview before execution
- [ ] Add dangerous command detection
- [ ] Require "CONFIRM" for dangerous commands (rm -rf, etc.)
- [ ] Include server context in prompts
- [ ] Add command history with translations

**Implementation:**
```dart
class CommandTranslator {
  final WatsonxClient watsonx;
  
  Future<String> translateCommand(
    String naturalLanguage,
    ServerContext context,
  ) async {
    final prompt = '''
You are a Linux system administrator assistant.
Convert natural language to shell commands.

Server context:
- OS: ${context.os}
- Installed services: ${context.services.join(', ')}
- Current directory: ${context.currentDir}

User request: "$naturalLanguage"

Respond with ONLY the shell command, no explanation.
''';
    
    return await watsonx.generateText(
      modelId: 'ibm/granite-13b-chat-v2',
      input: prompt,
      parameters: {
        'max_new_tokens': 100,
        'temperature': 0.3,
      },
    );
  }
  
  bool isDangerousCommand(String command) {
    final dangerous = ['rm -rf', 'format', 'mkfs', 'dd if=', 'DROP DATABASE'];
    return dangerous.any((d) => command.contains(d));
  }
}
```

**UI Flow:**
```dart
// User types: "restart nginx and show me the last 20 lines of its error log"
// App shows:
CommandPreview(
  naturalLanguage: userInput,
  translatedCommand: 'systemctl restart nginx && tail -20 /var/log/nginx/error.log',
  isDangerous: false,
  onRun: () => executeCommand(),
  onEdit: () => editCommand(),
  onCancel: () => cancel(),
)
```

---

## 5.2 AI Log Analysis

### Create Log Analyzer (lib/features/ai/log_analyzer.dart)

**Tasks:**
- [ ] Add "Analyze" button to log viewer
- [ ] Include metrics context in analysis
- [ ] Display analysis in readable format
- [ ] Implement proactive analysis on metric spikes
- [ ] Add "Apply Fix" button for suggestions
- [ ] Show analysis history

**Implementation:**
```dart
class LogAnalyzer {
  final WatsonxClient watsonx;
  
  Future<LogAnalysis> analyzeLog(
    String logContent,
    MetricsSnapshot metrics,
  ) async {
    final prompt = '''
Analyze this server log and current metrics to identify issues:

Current Metrics:
- CPU: ${metrics.cpu}%
- RAM: ${metrics.ram}% (${metrics.ramUsed}MB/${metrics.ramTotal}MB)
- Disk: ${metrics.disk}%

Recent Log Lines:
$logContent

Provide:
1. Root cause analysis
2. Specific configuration issues
3. Recommended fixes with exact commands
''';
    
    final response = await watsonx.generateText(
      modelId: 'ibm/granite-13b-chat-v2',
      input: prompt,
      parameters: {
        'max_new_tokens': 500,
        'temperature': 0.5,
      },
    );
    
    return LogAnalysis.fromText(response);
  }
}
```

**Analysis Display:**
```dart
LogAnalysisCard(
  rootCause: analysis.rootCause,
  issues: analysis.issues,
  fixes: analysis.fixes,
  onApplyFix: (fix) => applyFix(fix),
)
```

---

## 5.3 Server Diagnostics

### Create Diagnostic Tool (lib/features/ai/diagnostics.dart)

**Tasks:**
- [ ] Create "Why is my server slow?" button
- [ ] Collect full metrics snapshot + recent logs
- [ ] Generate prioritized explanation
- [ ] Suggest specific fixes with commands
- [ ] Add "Run Fix" buttons

**Implementation:**
```dart
class ServerDiagnostics {
  final WatsonxClient watsonx;
  
  Future<DiagnosticReport> diagnose(
    MetricsSnapshot metrics,
    List<LogEntry> recentLogs,
    List<Service> services,
  ) async {
    final prompt = '''
Diagnose server performance issues:

Metrics:
- CPU: ${metrics.cpu}% (Load: ${metrics.loadAverage})
- RAM: ${metrics.ram}% (${metrics.ramUsed}MB/${metrics.ramTotal}MB)
- Disk: ${metrics.disk}%
- Network: ${metrics.networkIn}/${metrics.networkOut} MB/s

Top Processes:
${formatProcesses(metrics.topProcesses)}

Recent Errors:
${formatLogs(recentLogs.where((l) => l.level == 'ERROR'))}

Provide:
1. Primary bottleneck
2. Contributing factors
3. Prioritized fixes with exact commands
''';
    
    final response = await watsonx.generateText(
      modelId: 'ibm/granite-13b-chat-v2',
      input: prompt,
      parameters: {
        'max_new_tokens': 800,
        'temperature': 0.5,
      },
    );
    
    return DiagnosticReport.fromText(response);
  }
}
```

---

## 5.4 MigrationPilot - Server Scanner

### Create Server Scanner (lib/features/migration/server_scanner.dart)

**Tasks:**
- [ ] Scan installed packages: `dpkg --get-selections` or `rpm -qa`
- [ ] Scan running services: `systemctl list-units`
- [ ] Scan Docker containers: `docker ps -a` and `docker images`
- [ ] Scan web server configs (nginx/apache/caddy)
- [ ] Scan databases (MySQL/PostgreSQL)
- [ ] Scan crontab entries
- [ ] Scan firewall rules: `ufw status` or `iptables -L`
- [ ] Scan disk usage
- [ ] Scan open ports: `ss -tlnp`

**Scanner Implementation:**
```dart
class ServerScanner {
  Future<ServerConfig> scanServer(SSHSession session) async {
    return ServerConfig(
      os: await detectOS(session),
      kernel: await getKernelVersion(session),
      packages: await scanPackages(session),
      services: await scanServices(session),
      containers: await scanDockerContainers(session),
      webConfigs: await scanWebServerConfigs(session),
      databases: await scanDatabases(session),
      cronJobs: await scanCrontab(session),
      firewallRules: await scanFirewall(session),
      diskUsage: await getDiskUsage(session),
      openPorts: await scanOpenPorts(session),
    );
  }
  
  Future<List<String>> scanPackages(SSHSession session) async {
    final result = await session.execute('dpkg --get-selections || rpm -qa');
    return parsePackages(result);
  }
  
  // Implement other scan methods...
}
```

---

## 5.5 MigrationPilot - AI Plan Generation

### Create Migration Planner (lib/features/migration/migration_planner.dart)

**Tasks:**
- [ ] Generate migration plan using Llama 3 70B
- [ ] Structure plan in 3 phases (Provision, Migrate, Cutover)
- [ ] Include exact commands for each step
- [ ] Add estimated times
- [ ] Format as interactive checklist
- [ ] Add export to Markdown

**Implementation:**
```dart
class MigrationPlanner {
  final WatsonxClient watsonx;
  
  Future<MigrationPlan> generatePlan(
    ServerConfig sourceConfig,
    String targetProvider,
  ) async {
    final prompt = '''
You are a DevOps expert. Generate a detailed server migration plan.

Source Server Configuration:
${sourceConfig.toJson()}

Target: $targetProvider

Generate a structured migration plan with:
1. Phase 1: Provision & Baseline
2. Phase 2: Migrate Services
3. Phase 3: Cutover

Include exact commands, estimated times, and validation steps.
Format as markdown with checkboxes.
''';
    
    final response = await watsonx.generateText(
      modelId: 'meta-llama/llama-3-70b-instruct',
      input: prompt,
      parameters: {
        'max_new_tokens': 2000,
        'temperature': 0.7,
      },
    );
    
    return MigrationPlan.fromMarkdown(response);
  }
}
```

**Plan Structure:**
```dart
class MigrationPlan {
  List<MigrationPhase> phases;
  
  // Phase 1: Provision & Baseline
  // Phase 2: Migrate Services
  // Phase 3: Cutover
}

class MigrationPhase {
  String name;
  List<MigrationStep> steps;
}

class MigrationStep {
  String description;
  String command;
  String targetServer; // 'source' or 'target'
  Duration estimatedTime;
  bool completed;
}
```

---

## 5.6 MigrationPilot - Interactive Execution

### Create Migration Executor (lib/features/migration/migration_executor.dart)

**Tasks:**
- [ ] Display plan as interactive checklist
- [ ] Add "Run on source" / "Run on target" buttons
- [ ] Execute commands on correct server
- [ ] Implement AI validation after each step
- [ ] Show progress indicators
- [ ] Handle errors gracefully

**UI:**
```dart
MigrationPlanView(
  plan: migrationPlan,
  sourceServer: sourceServer,
  targetServer: targetServer,
  onExecuteStep: (step) async {
    final server = step.targetServer == 'source' ? sourceServer : targetServer;
    final result = await executeOnServer(server, step.command);
    
    // AI validates result
    final isValid = await validateStepResult(step, result);
    
    if (isValid) {
      markStepComplete(step);
    } else {
      showError('Step validation failed');
    }
  },
)
```

---

## 5.7 Cron Manager UI

### Create Cron Manager (lib/features/cron/cron_manager_screen.dart)

**Tasks:**
- [ ] Fetch crontab from agent
- [ ] Display in human-readable format
- [ ] Create visual cron expression editor
- [ ] Add/edit/delete entries
- [ ] Validate expressions
- [ ] Show next execution time

**Cron Editor:**
```dart
CronEditor(
  expression: '0 3 * * *',
  command: '/usr/local/bin/backup.sh',
  onSave: (entry) => saveCronEntry(entry),
  humanReadable: 'Every day at 3:00 AM',
  nextExecution: DateTime.now().add(Duration(hours: 5)),
)
```

**Visual Editor:**
```dart
CronExpressionBuilder(
  minute: 0,
  hour: 3,
  dayOfMonth: '*',
  month: '*',
  dayOfWeek: '*',
  onChanged: (expression) => updateExpression(expression),
)
```

---

## 5.8 Incident Timeline

### Create Timeline Generator (lib/features/alerts/incident_timeline.dart)

**Tasks:**
- [ ] Detect anomalies (metric spikes, service failures)
- [ ] Correlate metrics, logs, and service states
- [ ] Generate chronological timeline
- [ ] Display as readable story
- [ ] Add export to text

**Timeline Example:**
```
01:47:03  RAM usage crossed 90% threshold
01:48:51  Swap space exhausted
01:49:12  nginx worker process OOM-killed (PID 3847)
01:49:13  Service nginx entered failed state
01:49:14  ⚠ Orbiter alert sent
```

**Implementation:**
```dart
class IncidentTimeline {
  Future<Timeline> generateTimeline(
    DateTime incidentTime,
    MetricsHistory metrics,
    List<LogEntry> logs,
    List<ServiceEvent> serviceEvents,
  ) async {
    // Collect events around incident time (±10 minutes)
    final events = correlateEvents(
      incidentTime,
      metrics,
      logs,
      serviceEvents,
    );
    
    // Sort chronologically
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return Timeline(events: events);
  }
}
```

---

## Phase 5 Checklist

- [ ] Natural language terminal working
- [ ] Can translate English to shell commands
- [ ] Dangerous commands require confirmation
- [ ] AI log analysis functional
- [ ] Can analyze logs and suggest fixes
- [ ] Server diagnostics working
- [ ] MigrationPilot can scan servers
- [ ] MigrationPilot generates migration plans
- [ ] Migration plans are executable step-by-step
- [ ] Cron manager UI complete
- [ ] Incident timelines generated automatically

**Demo:** 
1. Natural language: "restart nginx and show errors"
2. Analyze nginx logs with AI
3. Run server diagnostics
4. Scan server and generate migration plan

**Next:** Phase 6 - Testing, polish, and demo preparation.