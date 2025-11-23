
import 'package:bb_agro_portal/models/advertisement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdvertisementService {

final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<void> AddNewAdvertisement(Advertisement model) async
  {
    DocumentReference docRef = await _db.collection('advertisements').add({
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

  Future<void> UpdateAdvertisement(Advertisement model) async
    {
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
  Future<List<Advertisement>> getAllAdvertisements() async {
  try {
    QuerySnapshot querySnapshot = await _db.collection('advertisements').get();

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