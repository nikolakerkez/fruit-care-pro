import 'package:flutter/material.dart';

class FruitType {
  String id;
  final String name;
  final int? numberOfTreesPerAre;
  TextEditingController controller;

  FruitType({required this.id, required this.name, this.numberOfTreesPerAre}) : controller = TextEditingController(text: numberOfTreesPerAre.toString());

  factory FruitType.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return FruitType(
        id: documentId,
        name: data['name'] ?? '',
        numberOfTreesPerAre: data['numberOfTreesPerAre']);
  }
}
