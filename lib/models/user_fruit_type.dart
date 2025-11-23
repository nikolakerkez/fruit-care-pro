class UserFruitType {
  final String fruitTypeId;
  final String fruitTypeName;
  int numberOfTrees;

  UserFruitType(
      {required this.fruitTypeId,
      required this.fruitTypeName,
      required this.numberOfTrees});

  factory UserFruitType.fromFirestore(Map<String, dynamic> user2Fruit, Map<String, dynamic> fruit, String documentId) {
    return UserFruitType(
      fruitTypeId: documentId,
      fruitTypeName: fruit['name'] ?? '',
      numberOfTrees: user2Fruit['numberOfTrees'] ?? ''
    );
  }
}
