import 'package:bb_agro_portal/models/user_fruit_type.dart';

class CreateUserParam {
  final String id;
  final String name;
  final String email;
  final String password;
  final String city;
  final String phone;
  final List<UserFruitType> fruitTypes;

  CreateUserParam(
      {required this.id,
      required this.name,
      required this.email,
      required this.password,
      required this.city,
      required this.phone,
      required this.fruitTypes});

  // factory CreateUserParam.fromFirestore(Map<String, dynamic> data, String documentId) {
  //   return CreateUserParam(
  //     id: documentId,
  //     name: data['username'] ?? '',
  //     email: data['email'] ?? '',
  //     pa: data['isActive'] ?? false,
  //     fruitTypes: []
  //   );
  // }
}
