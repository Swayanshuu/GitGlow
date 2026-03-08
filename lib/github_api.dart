import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubApi {
  // These will be passed from the UI or fetched via method channel if using BuildConfig
  // For Flutter, we can also use --dart-define or just hardcode for simplicity if security isn't the top priority for a local bot
  // But let's assume we want to use the ones from buildConfig via MethodChannel or similar.
  // For now, I'll provide a way to inject them.

  final String clientId;
  final String clientSecret;
  final String redirectUri;

  GitHubApi({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  Future<String> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {'Accept': 'application/json'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to exchange code for token');
    }
  }

  Future<Map<String, dynamic>> fetchContributions(String token) async {
    const query = r'''
      query {
        viewer {
          login
          contributionsCollection {
            contributionCalendar {
              totalContributions
              weeks {
                contributionDays {
                  date
                  contributionCount
                  color
                }
              }
            }
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse('https://api.github.com/graphql'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch contributions: ${response.statusCode}');
    }
  }
}
