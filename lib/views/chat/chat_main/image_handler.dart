// image_handler.dart
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatspot/services/cloudinary_service.dart';

class ImageHandler {
  final BuildContext context;
  final String chatId;
  final String currentUserId;
  final String receiverId;
  final Function scrollToBottom;
  final Function(bool) setLoadingState;

  ImageHandler({
    required this.context,
    required this.chatId,
    required this.currentUserId,
    required this.receiverId,
    required this.scrollToBottom,
    required this.setLoadingState,
  });

  final ImagePicker _picker = ImagePicker();

  Future<void> uploadAndSendImage(String imagePath,
      {required ImageSource source}) async {
    try {
      setLoadingState(true);

      // ignore: unused_local_variable
      final loadingSnackBar = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Uploading image...'),
            ],
          ),
          duration: Duration(minutes: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final cloudinaryService = CloudinaryService();
      final imageUrl = source == ImageSource.camera
          ? await cloudinaryService.uploadCameraPicture(imagePath)
          : await cloudinaryService.uploadGalleryPicture(imagePath);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await MessageServices.sendImageMessage(
        chatId: chatId,
        currentUserId: currentUserId,
        receiverId: receiverId,
        imageUrl: imageUrl,
        context: context,
      );

      scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Image upload error: $e');
    } finally {
      setLoadingState(false);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        await uploadAndSendImage(image.path, source: source);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
