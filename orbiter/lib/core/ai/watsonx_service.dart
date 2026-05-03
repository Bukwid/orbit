import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for interacting with IBM watsonx.ai
class WatsonXService {
  final String apiKey;
  final String projectId;
  final String url;
  String? _accessToken;
  DateTime? _tokenExpiry;

  WatsonXService({
    required this.apiKey,
    required this.projectId,
    required this.url,
  });

  /// Get IBM Cloud IAM access token
  Future<String> _getAccessToken() async {
    // Return cached token if still valid
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      print('🔑 Using cached token');
      return _accessToken!;
    }

    print('🔑 Getting new IAM token...');
    print('🔑 API Key: ${apiKey.substring(0, 10)}...');

    try {
      final response = await http.post(
        Uri.parse('https://iam.cloud.ibm.com/identity/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$apiKey',
      ).timeout(const Duration(seconds: 30));

      print('🔑 Token response: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ Token error: ${response.body}');
        throw Exception('Failed to get access token (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      // Token expires in 1 hour, refresh 5 minutes early
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
      print('✅ Token obtained successfully');
      return _accessToken!;
    } catch (e) {
      print('❌ Token request failed: $e');
      rethrow;
    }
  }

  /// Analyze nginx logs using watsonx.ai
  Future<String> analyzeLogs(List<String> logLines) async {
    print('🤖 Starting log analysis...');
    print('🤖 Project ID: $projectId');
    print('🤖 URL: $url');
    print('🤖 Log lines: ${logLines.length}');


    // REAL API CODE (uncomment when you have access)
    
    try {
      final token = await _getAccessToken();
      print('🤖 Got token, preparing request...');

      // Create prompt for log analysis
      final prompt = '''Analyze these nginx access logs and provide a brief summary:

${logLines.join('\n')}

Provide:
1. Total requests
2. Most common status codes
3. Any errors or issues
4. Top requested paths
5. Brief security assessment

Keep the response concise and actionable.''';

      print('🤖 Sending request to watsonx.ai...');
      print('🤖 Model: google/flan-t5-xxl');

      final requestBody = {
        'model_id': 'ibm/granite-3-8b-instruct', 
        'input': prompt,
        'parameters': {
          'max_new_tokens': 500,
          'temperature': 0.7,
          'top_p': 0.9,
        },
        'project_id': projectId,
      };

      print('🤖 Request body: ${jsonEncode(requestBody).substring(0, 200)}...');

      final response = await http.post(
        Uri.parse('$url/ml/v1/text/generation?version=2023-05-29'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60));

      print('🤖 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ watsonx.ai error: ${response.body}');
        
        // Parse error for better message
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['errors']?[0]?['message'] ?? errorData['message'] ?? response.body;
          throw Exception('watsonx.ai error (${response.statusCode}): $errorMsg');
        } catch (e) {
          throw Exception('watsonx.ai error (${response.statusCode}): ${response.body}');
        }
      }

      print('✅ Got response from watsonx.ai');
      final data = jsonDecode(response.body);
      
      // Check if results exist
      if (data['results'] == null || (data['results'] as List).isEmpty) {
        print('❌ No results in response: ${response.body}');
        throw Exception('No results returned from watsonx.ai');
      }

      final generatedText = data['results'][0]['generated_text'] as String;
      print('✅ Analysis complete, length: ${generatedText.length} chars');
      
      return generatedText;
    } catch (e) {
      print('❌ Analysis failed: $e');
      rethrow;
    }
    
  }
}

// Made with Bob