import 'package:fruit_care_pro/models/user_fruit_type.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String city;
  final String phone;
  String? thumbUrl;
  String? imageUrl;
  bool isActive;
  bool isPremium;
  final bool isAdmin;
  final bool isPasswordChangeNeeded;
  final List<UserFruitType> fruitTypes;

  AppUser({required this.id, 
   required this.name, 
   required this.email, 
   required this.isActive,
   required this.isPremium,
   required this.city,
   required this.phone,
   required this.isPasswordChangeNeeded,
   required this.fruitTypes,
   this.isAdmin = false,
   this.imageUrl,
   this.thumbUrl});

  factory AppUser.fromFirestore(Map<String, dynamic> data, String documentId, List<UserFruitType>? fruitTypes) {
    return AppUser(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      city: data['city'] ?? '',
      phone: data['phone'] ?? '',
      isActive: data['isActive'] ?? false,
      isPremium: data['isPremium'] ?? false,
      isAdmin: data['isAdmin'] ?? false,
      thumbUrl: data['thumbUrl'],
      imageUrl: data['imageUrl'],
      isPasswordChangeNeeded: data['isPasswordChangeNeeded'] ?? false,
      fruitTypes: fruitTypes ?? []
    );
  }
}