import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Map<String, String>?> uploadImage(File file, String fileName) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fullName = 'full_$timestamp.jpg';
    final thumbName = 'thumb_$timestamp.jpg';

    // 🔹 1️⃣ Kompresija full-size slike (max širina 800px)
    final fullBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      quality: 85,
    );
    if (fullBytes == null) return null;

    // 🔹 2️⃣ Kompresija thumbnail slike (max širina 200px)
    final thumbBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 200,
      quality: 70,
    );
    if (thumbBytes == null) return null;

    // 🔹 3️⃣ Firebase Storage reference
    final storage = FirebaseStorage.instance;
    final fullRef = storage.ref('chat_images/$fullName');
    final thumbRef = storage.ref('chat_images/$thumbName');

    // 🔹 4️⃣ Upload full-size slike
    await fullRef.putData(
      fullBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );

    // 🔹 5️⃣ Upload thumbnail slike
    await thumbRef.putData(
      thumbBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );

    // 🔹 6️⃣ Preuzimanje URL-ova
    final fullUrl = await fullRef.getDownloadURL();
    final thumbUrl = await thumbRef.getDownloadURL();

    // 🔹 7️⃣ Povratna mapa sa svim podacima
    return {
      'fullPath': fullRef.fullPath,
      'thumbPath': thumbRef.fullPath,
      'fullUrl': fullUrl,
      'thumbUrl': thumbUrl,
    };
  } catch (e, st) {
    print('❌ Upload failed: $e\n$st');
    return null;
  }
}

// 5. UPLOAD SA PROGRESS TRACKING-OM
Future<Map<String, String>?> uploadImageWithProgress(
  File file, 
  String fileName,
  {Function(double)? onProgress}
) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fullName = 'full_$timestamp.jpg';
    final thumbName = 'thumb_$timestamp.jpg';

    // Kompresija (ovo je brzo, ne mora u isolate)
    final fullBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      quality: 85,
    );
    if (fullBytes == null) return null;

    final thumbBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 200,
      quality: 70,
    );
    if (thumbBytes == null) return null;

    final storage = FirebaseStorage.instance;
    final fullRef = storage.ref('chat_images/$fullName');
    final thumbRef = storage.ref('chat_images/$thumbName');

    // 🔥 PARALELNI UPLOAD (oba odjednom, ne sekvencijalno!)
    final uploadTasks = await Future.wait([
      // Full image upload sa progress tracking
      _uploadWithProgress(fullRef, fullBytes, onProgress),
      // Thumb upload (bez progress-a jer je mali)
      thumbRef.putData(
        thumbBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      ),
    ]);

    // Preuzmi URL-ove
    final urls = await Future.wait([
      fullRef.getDownloadURL(),
      thumbRef.getDownloadURL(),
    ]);

    return {
      'fullPath': fullRef.fullPath,
      'thumbPath': thumbRef.fullPath,
      'fullUrl': urls[0],
      'thumbUrl': urls[1],
    };

  } catch (e, st) {
    print('❌ Upload failed: $e\n$st');
    return null;
  }
}

Future<TaskSnapshot> _uploadWithProgress(
  Reference ref,
  Uint8List bytes,
  Function(double)? onProgress,
) async {
  final uploadTask = ref.putData(
    bytes,
    SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000, immutable',
    ),
  );

  // Track progress
  uploadTask.snapshotEvents.listen((snapshot) {
    final progress = snapshot.bytesTransferred / snapshot.totalBytes;
    onProgress?.call(progress);
  });

  return await uploadTask;
}

