import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary;

  CloudinaryService()
      : cloudinary = CloudinaryPublic(
          'draqhisid',  // Your cloud name
          'chatspot',   // Default upload preset
        );

  Future<String> uploadCameraPicture(String filePath) async {
    return _uploadToCloudinary(
      filePath,
      folder: "chatspot_camera_pictures", // Camera-specific folder
    );
  }

  Future<String> uploadGalleryPicture(String filePath) async {
    return _uploadToCloudinary(
      filePath,
      folder: "chatspot_gallery_pictures", // Gallery-specific folder
    );
  }

  Future<String> uploadProfilePicture(String filePath) async {
    return _uploadToCloudinary(
      filePath,
      folder: "chatspot_profile_pictures", // Profile-specific folder
    );
  }


  Future<String> _uploadToCloudinary(
    String filePath, {
    required String folder,
  }) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      // Cloudinary-specific errors
      print('Cloudinary upload failed ($folder): ${e.message}');
      throw Exception('Failed to upload image to $folder: ${e.message}');
    } catch (e) {
      // General errors (network, file access, etc.)
      print('Upload error ($folder): $e');
      throw Exception('Failed to upload image: $e');
    }
  }
}