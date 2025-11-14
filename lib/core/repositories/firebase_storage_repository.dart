/// Firebase Storage Repository Implementation
///
/// Implements file storage using Firebase Storage
library;

import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';
import 'storage_repository.dart';

/// Repository implementation using Firebase Storage
class FirebaseStorageRepository implements StorageRepository {
  final FirebaseStorage _storage;

  FirebaseStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String?> uploadImage(
    String localPath,
    String fileName, {
    String folder = 'images',
  }) async {
    try {
      final file = File(localPath);

      // Check if file exists
      if (!await file.exists()) {
        developer.log(
          '⚠️  File not found: $localPath',
          name: 'FirebaseStorageRepo.Upload',
        );
        return null;
      }

      developer.log(
        '📤 Uploading file: $fileName to folder: $folder',
        name: 'FirebaseStorageRepo.Upload',
      );

      // Upload to Storage
      final ref = _storage.ref().child('$folder/$fileName');
      final uploadTask = await ref.putFile(file);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final fileSize = await file.length();
      developer.log(
        '✅ File uploaded successfully\n'
        '   • File: $fileName\n'
        '   • Size: ${(fileSize / 1024).toStringAsFixed(2)} KB\n'
        '   • URL: $downloadUrl',
        name: 'FirebaseStorageRepo.Upload',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ File upload failed: $fileName',
        name: 'FirebaseStorageRepo.Upload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<bool> deleteImage(String fileName, {String folder = 'images'}) async {
    try {
      developer.log(
        '🗑️  Deleting file: $fileName from folder: $folder',
        name: 'FirebaseStorageRepo.Delete',
      );

      await _storage.ref().child('$folder/$fileName').delete();

      developer.log(
        '✅ File deleted successfully: $fileName',
        name: 'FirebaseStorageRepo.Delete',
      );

      return true;
    } catch (e, stackTrace) {
      developer.log(
        '❌ File deletion failed: $fileName',
        name: 'FirebaseStorageRepo.Delete',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<String?> getDownloadUrl(String fileName,
      {String folder = 'images'}) async {
    try {
      final downloadUrl =
          await _storage.ref().child('$folder/$fileName').getDownloadURL();

      developer.log(
        '✅ Download URL retrieved: $fileName',
        name: 'FirebaseStorageRepo.GetUrl',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Failed to get download URL: $fileName',
        name: 'FirebaseStorageRepo.GetUrl',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<bool> checkConnection() async {
    try {
      // Try to list files in root (will fail if no connection)
      await _storage.ref().listAll();

      developer.log(
        '✅ Firebase Storage connection OK',
        name: 'FirebaseStorageRepo.Connection',
      );
      return true;
    } catch (e) {
      developer.log(
        '❌ Firebase Storage connection failed',
        name: 'FirebaseStorageRepo.Connection',
        error: e,
      );
      return false;
    }
  }
}
