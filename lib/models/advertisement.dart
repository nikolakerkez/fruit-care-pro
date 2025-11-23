import 'package:bb_agro_portal/models/user_fruit_type.dart';

class Advertisement {
  final String id;
  final String name;
  final String description;
  final String url;
  final String imageUrl;
  final String thumbUrl;
  final String imagePath;
  final String thumbPath;
  final String localImagePath;
  Advertisement(
      {required this.id,
      required this.name,
      required this.description,
      required this.url,
      required this.thumbUrl,
      required this.imageUrl,
      required this.localImagePath,
      required this.thumbPath,
      required this.imagePath});

  factory Advertisement.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Advertisement(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      url: data['url'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbUrl: data['thumbUrl'] ?? '',
      imagePath: data['imagePath'] ?? '',
      thumbPath: data['thumbPath'] ?? '',
      localImagePath: data['localImagePath'] ?? ''
    );
  }
}
