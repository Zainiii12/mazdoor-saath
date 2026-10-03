import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage uploads — progress photos, site check-ins, avatars.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// Uploads a daily progress photo for [jobId]; returns the download URL.
  Future<String> uploadProgressPhoto({
    required String jobId,
    required File file,
  }) async {
    final ref = _storage.ref().child('progress/$jobId/${_uuid.v4()}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Uploads a profile photo for [userId]; returns the download URL.
  Future<String> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    final ref = _storage.ref().child('profiles/$userId/${_uuid.v4()}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Deletes a previously uploaded file by its download URL (best effort).
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Best effort.
    }
  }
}
