enum MediaType { image, video }

class Meme {
  final String id;
  final String title;
  final String? description;
  final String previewUrl;
  final String mediaUrl;
  final MediaType type;
  final DateTime createdAt;
  final String? category;
  final List<String> keywords;

  Meme({
    required this.id,
    required this.title,
    this.description,
    required this.previewUrl,
    required this.mediaUrl,
    required this.type,
    required this.createdAt,
    this.category,
    this.keywords = const [],
  });

  factory Meme.fromJson(Map<String, dynamic> json, String baseUrl) {
    // 1. Determine media type
    final String filename = (json['filename'] as String?) ?? '';
    
    final bool isVideo = filename.toLowerCase().endsWith('.mp4');
    
    // 2. Construct the new download URL as specified: /memes/{filename}/download
    // We ensure baseUrl doesn't end with a slash to avoid double slashes
    final String cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final String previewUrl = "$cleanBaseUrl/memes/$filename/preview";
    final String downloadUrl = "$cleanBaseUrl/memes/$filename/download";
    
    // 3. Safely parse keywords
    List<String> keywordsList = [];
    final dynamic rawKeywords = json['keywords'];
    
    if (rawKeywords is String && rawKeywords.isNotEmpty) {
      keywordsList = rawKeywords.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    } else if (rawKeywords is List) {
      keywordsList = rawKeywords.map((k) => k.toString()).toList();
    }

    return Meme(
      id: json['id'].toString(),
      title: filename.isNotEmpty ? filename : 'Untitled',
      description: (json['description'] as String?) ?? (json['text_in_image'] as String?),
      previewUrl: previewUrl,
      mediaUrl: downloadUrl,
      type: isVideo ? MediaType.video : MediaType.image,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      category: json['category'] as String?,
      keywords: keywordsList,
    );
  }
}

class MemeResponse {
  final List<Meme> items;

  MemeResponse({required this.items});

  factory MemeResponse.fromJson(dynamic json, String baseUrl) {
    if (json is List) {
      return MemeResponse(
        items: json.map((i) => Meme.fromJson(i as Map<String, dynamic>, baseUrl)).toList(),
      );
    } else if (json is Map<String, dynamic>) {
      return MemeResponse(
        items: (json['items'] as List).map((i) => Meme.fromJson(i as Map<String, dynamic>, baseUrl)).toList(),
      );
    }
    throw Exception('Invalid JSON format for MemeResponse');
  }
}
