
class AdvertisementCategory {
  final String id;
  final String name;
  final int? numberOfAdvertisements;
  AdvertisementCategory(
      {required this.id,
      required this.name,
      this.numberOfAdvertisements});

  factory AdvertisementCategory.fromFirestore(Map<String, dynamic> data, String documentId, int numberOfAdvertisements) {
    return AdvertisementCategory(
      id: documentId,
      name: data['name'] ?? '',
      numberOfAdvertisements:  numberOfAdvertisements
    );
  }
}
