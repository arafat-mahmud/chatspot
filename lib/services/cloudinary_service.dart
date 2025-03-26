import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary;

  CloudinaryService()
      : cloudinary = CloudinaryPublic(
          'draqhisid',  // Replace with your actual cloud name
          'chatspot',  // Create this in Cloudinary dashboard
        );

  Future<String> uploadProfilePicture(String filePath) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(filePath,
            resourceType: CloudinaryResourceType.Image,
            folder: "chatspot_profile_pictures"),
      );
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
}