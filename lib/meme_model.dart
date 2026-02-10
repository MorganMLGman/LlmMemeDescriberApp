enum MediaType { image, video }

class Meme {
  final String id;
  final String title;
  final String? description;
  final String previewUrl;
  final String mediaUrl;
  final MediaType type;

  Meme({
    required this.id,
    required this.title,
    this.description,
    required this.previewUrl,
    required this.mediaUrl,
    required this.type,
  });

  factory Meme.fromJson(Map<String, dynamic> json) {
    return Meme(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      previewUrl: json['preview_url'] as String,
      mediaUrl: json['media_url'] as String,
      type: json['type'] == 'video' ? MediaType.video : MediaType.image,
    );
  }
}
