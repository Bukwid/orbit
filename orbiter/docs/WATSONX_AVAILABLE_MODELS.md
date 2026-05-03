# IBM watsonx.ai Available Models

## Overview
IBM watsonx.ai provides access to various foundation models for different use cases. Based on your project documentation and the watsonx.ai ecosystem, here are the available models:

---

## 🎯 Currently Used in Orbiter
- **Model**: `google/flan-t5-xxl`
- **Location**: `orbiter/lib/core/ai/watsonx_service.dart` (line 87)
- **Use Case**: Log analysis

---

## 📋 IBM Granite Models

### 1. **ibm/granite-13b-chat-v2**
- **Type**: Chat/Conversational
- **Size**: 13 billion parameters
- **Best For**: 
  - General purpose conversations
  - Fast responses
  - Command translation
  - Log analysis
- **Recommended Use Cases in Orbiter**:
  - Natural language command translation
  - Quick log summaries
  - Server diagnostics

### 2. **ibm/granite-13b-instruct-v2**
- **Type**: Instruction-following
- **Size**: 13 billion parameters
- **Best For**:
  - Following specific instructions
  - Structured outputs
  - Task completion
- **Recommended Use Cases in Orbiter**:
  - Generating specific commands
  - Structured analysis reports

### 3. **ibm/granite-20b-code-instruct**
- **Type**: Code-specialized
- **Size**: 20 billion parameters
- **Best For**:
  - Code analysis
  - Script generation
  - Configuration file parsing
- **Recommended Use Cases in Orbiter**:
  - Analyzing server configuration files
  - Generating deployment scripts
  - Code review for custom scripts

---

## 🦙 Meta Llama Models

### 4. **meta-llama/llama-3-70b-instruct**
- **Type**: Large instruction model
- **Size**: 70 billion parameters
- **Best For**:
  - Complex reasoning
  - Multi-step planning
  - Detailed analysis
- **Recommended Use Cases in Orbiter**:
  - **MigrationPilot** - Server migration planning
  - Complex troubleshooting
  - Architecture recommendations
- **Note**: Higher cost, slower response, but superior reasoning

### 5. **meta-llama/llama-3-8b-instruct**
- **Type**: Instruction model
- **Size**: 8 billion parameters
- **Best For**:
  - Balanced performance and cost
  - General instructions
  - Quick analysis
- **Recommended Use Cases in Orbiter**:
  - Alternative to Granite for general tasks
  - Cost-effective option

---

## 🔤 Google Models

### 6. **google/flan-t5-xxl** ✅ (Currently Used)
- **Type**: Text-to-text
- **Size**: 11 billion parameters
- **Best For**:
  - Text generation
  - Summarization
  - Question answering
- **Current Use in Orbiter**:
  - Nginx log analysis
- **Pros**: Reliable, well-tested, good for structured tasks
- **Cons**: Not as conversational as newer models

### 7. **google/flan-ul2**
- **Type**: Unified text-to-text
- **Size**: 20 billion parameters
- **Best For**:
  - Long-form text generation
  - Complex summarization
- **Recommended Use Cases in Orbiter**:
  - Detailed log analysis
  - Comprehensive server reports

---

## 🎨 Model Selection Guide for Orbiter Features

### Feature: Natural Language Command Translation
**Recommended Models** (in order):
1. `ibm/granite-13b-chat-v2` - Fast, conversational
2. `meta-llama/llama-3-8b-instruct` - Good alternative
3. `google/flan-t5-xxl` - Current fallback

### Feature: Log Analysis
**Recommended Models** (in order):
1. `ibm/granite-13b-chat-v2` - Fast analysis
2. `google/flan-t5-xxl` - Current choice ✅
3. `ibm/granite-20b-code-instruct` - For code-heavy logs

### Feature: Server Diagnostics
**Recommended Models** (in order):
1. `ibm/granite-13b-chat-v2` - Quick diagnostics
2. `meta-llama/llama-3-8b-instruct` - Deeper analysis
3. `meta-llama/llama-3-70b-instruct` - Complex issues

### Feature: MigrationPilot (Server Migration Planning)
**Recommended Models** (in order):
1. `meta-llama/llama-3-70b-instruct` - Best reasoning ⭐
2. `ibm/granite-20b-code-instruct` - Technical focus
3. `ibm/granite-13b-instruct-v2` - Faster alternative

---

## 💰 Cost Considerations

### Token Pricing (Approximate)
- **Input tokens**: ~$0.002 per 1K tokens
- **Output tokens**: ~$0.006 per 1K tokens

### Cost by Model (Relative)
1. **Cheapest**: `google/flan-t5-xxl`, `ibm/granite-13b-*`
2. **Moderate**: `meta-llama/llama-3-8b-instruct`
3. **Expensive**: `meta-llama/llama-3-70b-instruct`, `ibm/granite-20b-code-instruct`

### Estimated Costs for Orbiter POC
- **Log Analysis** (500 tokens in, 200 tokens out): ~$0.002 per request
- **Command Translation** (100 tokens in, 50 tokens out): ~$0.0005 per request
- **Migration Planning** (2000 tokens in, 1000 tokens out): ~$0.01 per request

**Total for demo**: ~$10-40 (as documented in improved_plan.md)

---

## 🚀 Recommended Model Strategy

### Phase 1: POC/Demo (Current)
```dart
// Use fast, reliable models
'model_id': 'google/flan-t5-xxl'  // Current ✅
```

### Phase 2: Production (Recommended)
```dart
// Switch to Granite for better performance
'model_id': 'ibm/granite-13b-chat-v2'
```

### Phase 3: Advanced Features
```dart
// Use specialized models per feature
if (feature == 'migration') {
  modelId = 'meta-llama/llama-3-70b-instruct';
} else if (feature == 'code_analysis') {
  modelId = 'ibm/granite-20b-code-instruct';
} else {
  modelId = 'ibm/granite-13b-chat-v2';
}
```

---

## 🔧 How to Switch Models

Edit `orbiter/lib/core/ai/watsonx_service.dart` line 87:

```dart
final requestBody = {
  'model_id': 'ibm/granite-13b-chat-v2',  // Change this line
  'input': prompt,
  'parameters': {
    'max_new_tokens': 500,
    'temperature': 0.7,
    'top_p': 0.9,
  },
  'project_id': projectId,
};
```

---

## 📊 Model Comparison Table

| Model | Size | Speed | Cost | Best For |
|-------|------|-------|------|----------|
| `google/flan-t5-xxl` | 11B | Fast | Low | General tasks ✅ |
| `ibm/granite-13b-chat-v2` | 13B | Fast | Low | Conversations |
| `ibm/granite-13b-instruct-v2` | 13B | Fast | Low | Instructions |
| `meta-llama/llama-3-8b-instruct` | 8B | Fast | Low | Balanced |
| `ibm/granite-20b-code-instruct` | 20B | Medium | Medium | Code |
| `google/flan-ul2` | 20B | Medium | Medium | Long text |
| `meta-llama/llama-3-70b-instruct` | 70B | Slow | High | Complex reasoning |

---

## 🎯 Next Steps

1. **Test current model**: Verify `google/flan-t5-xxl` works for log analysis
2. **Try Granite**: Switch to `ibm/granite-13b-chat-v2` for better conversational responses
3. **Implement model selection**: Add logic to choose models based on task
4. **Monitor costs**: Track token usage and optimize

---

## 📚 References

- IBM watsonx.ai Documentation: https://dataplatform.cloud.ibm.com/docs/content/wsj/analyze-data/fm-models.html
- Model Pricing: https://www.ibm.com/products/watsonx-ai/pricing
- API Reference: https://cloud.ibm.com/apidocs/watsonx-ai

---

**Last Updated**: 2026-05-03  
**Project**: Orbiter - IBM Hackathon 2026  
**Current Model**: `google/flan-t5-xxl`