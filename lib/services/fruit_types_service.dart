import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bb_agro_portal/models/fruit_type.dart';

class FruitTypesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<FruitType>> getFruitTypes(List<String> fruitTypeIds) {
    return _db
        .collection('fruit_types')
        .where(FieldPath.documentId, whereIn: fruitTypeIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FruitType.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> deleteFruitType(String id) async {
    try {
      // Brisanje dokumenta iz kolekcije 'fruit_types' na osnovu ID-a
      await _db.collection('fruit_types').doc(id).delete();
      print("Voćna vrsta uspešno obrisana.");
    } catch (e) {
      print("Greška prilikom brisanja voćne vrste: $e");
      // Možete obraditi greške i obavestiti korisnika
    }
  }

  // // Metoda za dodavanje nove voćne vrste
  Future<String> addFruitType(FruitType ft) async {
  print("Adding fruit type");

  DocumentReference docRef = await _db.collection('fruit_types').add({
    'name': ft.name,
    'numberOfTreesPerAre': ft.numberOfTreesPerAre,
  });

  return docRef.id;
}
  // Metoda za ažuriranje voćne vrste u Firestore
  Future<void> updateFruitType(FruitType fruitType) async {
    try {
      // Ažuriramo voćnu vrstu u kolekciji 'fruit_types' pomoću ID-a
      await _db.collection('fruit_types').doc(fruitType.id).update({
        'name': fruitType.name,
        'numberOfTreesPerAre': fruitType.numberOfTreesPerAre,
      });

      print("Voćna vrsta uspešno ažurirana.");
    } catch (e) {
      print("Greška prilikom ažuriranja voćne vrste: $e");
    }
  }

  Stream<List<FruitType>> retrieveAllFruitTypes() {
    return _db
        .collection('fruit_types') // Uzimamo kolekciju "fruit_types"
        .snapshots() // Praćenje promena u realnom vremenu
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Ovde osiguravamo da data() vrati Map<String, dynamic>
        var data = doc.data();
        // Pretvaranje podataka u FruitType objekat
        return FruitType.fromFirestore(data, doc.id);
      }).toList(); // Vraćamo listu svih FruitType objekata
    });
  }
}
