import 'package:fruit_care_pro/models/advertisement.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdvertisementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

    Stream<List<AdvertisementCategory>> retrieveAllCategories() {
    try {
      return _db.collection('advertisement_categories').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          var data = doc.data();
          return AdvertisementCategory.fromFirestore(data, doc.id, 5);
        }).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  Future<void> AddCategory(AdvertisementCategory category) async {
    DocumentReference docRef =
        await _db.collection('advertisement_categories').add({
      'name': category.name,
    });
  }

  Future<void> UpdateCategory(AdvertisementCategory category) async {
    await _db.collection('advertisement_categories').doc(category.id).update({
      'name': category.name,
    });
  }

  Future<void> DeleteCategory(String categoryId) async {
    await FirebaseFirestore.instance.collection('advertisement_categories').doc(categoryId).delete();
  }

  Future<void> AddNewAdvertisement(Advertisement model) async {
    DocumentReference docRef = await _db.collection('advertisements').add({
      'name': model.name,
      'description': model.description,
      'url': model.url,
      'imageUrl': model.imageUrl,
      'imagePath': model.imagePath,
      'thumbUrl': model.thumbUrl,
      'thumbPath': model.thumbPath,
      'localImagePath': model.localImagePath,
      'categoryRefId': model.categoryRefId
    });
  }

  Future<void> UpdateAdvertisement(Advertisement model) async {
    await _db.collection('advertisements').doc(model.id).update({
      'name': model.name,
      'description': model.description,
      'url': model.url,
      'imageUrl': model.imageUrl,
      'imagePath': model.imagePath,
      'thumbUrl': model.thumbUrl,
      'thumbPath': model.thumbPath,
      'localImagePath': model.localImagePath
    });
  }

  Future<List<Advertisement>> getAllAdvertisementsForCategory(String categoryId) async {
    try {
      QuerySnapshot querySnapshot =
          await _db.collection('advertisements').where('categoryRefId', isEqualTo: categoryId).get();

      List<Advertisement> returnValue = querySnapshot.docs.map((doc) {
        return Advertisement.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      return returnValue;
    } catch (e) {
      print('Greška prilikom dohvaćanja korisnika: $e');
      return [];
    }
  }
}
