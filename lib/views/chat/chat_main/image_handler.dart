import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatspot/services/cloudinary_service.dart';
import 'package:photo_view/photo_view.dart';

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

  // New method to show full screen image
  static void showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

class FullScreenImageView extends StatefulWidget {
  final String imageUrl;
  final DateTime? timestamp;
  final bool isUser;

  const FullScreenImageView({
    Key? key,
    required this.imageUrl,
    this.timestamp,
    required this.isUser,
  }) : super(key: key);

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PhotoViewControllerBase controller;
  double scale = 1.0;

  @override
  void initState() {
    super.initState();
    controller = PhotoViewController()
      ..outputStateStream.listen(onControllerUpdate);
  }

  void onControllerUpdate(PhotoViewControllerValue value) {
    setState(() {
      scale = value.scale ?? 1.0;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: scale > 1.0 ? Colors.black54 : Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onDoubleTap: () {
          if (scale > 1.0) {
            controller.scale = 1.0;
            controller.position = Offset.zero;
          } else {
            controller.scale = 3.0;
          }
        },
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: widget.imageUrl,
                child: PhotoView(
                  imageProvider: NetworkImage(widget.imageUrl),
                  controller: controller,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: BoxDecoration(color: Colors.black),
                  loadingBuilder: (context, event) => Center(
                    child: Container(
                      width: 30.0,
                      height: 30.0,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded /
                                event.expectedTotalBytes!,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) => Center(
                    child:
                        Icon(Icons.broken_image, color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),
            if (widget.timestamp != null && scale <= 1.5)
              Positioned(
                bottom: 30,
                right: widget.isUser ? 30 : null,
                left: widget.isUser ? null : 30,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormatters.formatTimestamp(widget.timestamp),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
