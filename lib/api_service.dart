import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'meme_model.dart';

class ApiService {
  Future<List<Meme>> fetchMemes(int page) async {
    final url = await ApiConfig.getUrl();
    final token = await ApiConfig.getToken();

    if (url == null || token == null) {
      throw Exception('API configuration missing');
    }

    final response = await http.get(
      Uri.parse('$url/memes?page=$page'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Meme.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load memes: ${response.statusCode}');
    }
  }
}
