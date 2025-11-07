import 'package:flutter/services.dart';

// Service to handle communication with native code
class PhotoCleanerService {
  static const _channel = MethodChannel('com.example.photoCleaner');

  Future<List<Map<dynamic, dynamic>>> findSimilarPhotos() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('findSimilarPhotos');
      return result.cast<Map<dynamic, dynamic>>();
    } on PlatformException catch (e) {
      print("Failed to find similar photos: '${e.message}'.");
      rethrow;
    }
  }

  Future<String?> recommendBestPhoto(List<String> identifiers) async {
    try {
      final String? bestPhotoId = await _channel.invokeMethod('recommendBestPhoto', {'identifiers': identifiers});
      return bestPhotoId;
    } on PlatformException catch (e) {
      print("Failed to recommend best photo: '${e.message}'.");
      return null;
    }
  }

  Future<void> deletePhotos(List<String> identifiers) async {
    try {
      await _channel.invokeMethod('deletePhotos', {'identifiers': identifiers});
    } on PlatformException catch (e) {
      print("Failed to delete photos: '${e.message}'.");
      rethrow;
    }
  }
}
