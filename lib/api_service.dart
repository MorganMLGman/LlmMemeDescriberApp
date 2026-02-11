import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'meme_model.dart';

class ApiService {
  /// Fetches a paginated list of memes using offset-based pagination.
  Future<MemeResponse> fetchMemes({required int offset, int limit = 10}) async {
    final baseUrl = await ApiConfig.getUrl();
    final token = await ApiConfig.getToken();

    if (baseUrl == null || token == null) {
      throw Exception('API configuration missing. Please check your settings.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/memes?offset=$offset&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final dynamic decodedData = json.decode(response.body);
      // We pass baseUrl so Meme.fromJson can construct the download URL
      return MemeResponse.fromJson(decodedData, baseUrl);
    } else {
      String errorMsg = 'Failed to load memes (${response.statusCode})';
      try {
        final body = json.decode(response.body);
        if (body['detail'] != null) errorMsg = body['detail'];
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
