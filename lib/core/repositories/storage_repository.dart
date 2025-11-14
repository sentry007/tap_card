/// Storage Repository Interface
///
/// Abstract repository for file storage operations
library;

/// Abstract repository for file storage (images, documents, etc.)
abstract class StorageRepository {
  /// Upload an image file
  /// Returns download URL or null if upload fails
  Future<String?> uploadImage(String localPath, String fileName,
      {String folder = 'images'});

  /// Delete an image file
  /// Returns true if successful
  Future<bool> deleteImage(String fileName, {String folder = 'images'});

  /// Get download URL for a file
  Future<String?> getDownloadUrl(String fileName, {String folder = 'images'});

  /// Check if storage is accessible
  Future<bool> checkConnection();
}
