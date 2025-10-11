import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'components/my_profile.dart';
import 'components/settings/settings.dart';
// ignore: unused_import
import '../../../main.dart';
import '../../views/auth/signin.dart';
import '../../services/cloudinary_service.dart';
import '../../views/friends/friend_list_screen.dart';
import '../../services/friend/friend_notification_service.dart';
import '../../views/chat/chat_main/image_handler.dart';

class MenuPage extends StatelessWidget {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  MenuPage({super.key});

  Future<void> _uploadProfilePicture(
      BuildContext context, String userId) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery, context, userId);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera, context, userId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(
      ImageSource source, BuildContext context, String userId) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        // ignore: use_build_context_synchronously
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Uploading image...')),
        );

        final imageUrl =
            await _cloudinaryService.uploadProfilePicture(image.path);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'profilePictureUrl': imageUrl});

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text(
          'Menu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
          ),
        ),
        iconTheme:
            theme.appBarTheme.iconTheme ?? IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Container(
                  height: 200,
                  child: Center(child: Text('Error loading user info')),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Container(
                  height: 200,
                  child: Center(child: Text('User not found')),
                );
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              String username = userData['username'] ?? 'No Username';
              String? profilePictureUrl = userData['profilePictureUrl'];

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                color: theme.primaryColor,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        profilePictureUrl != null
                            ? GestureDetector(
                                onTap: () {
                                  ImageHandler.showFullScreenImage(
                                      context, profilePictureUrl);
                                },
                                child: CircleAvatar(
                                  radius: 29,
                                  backgroundImage:
                                      NetworkImage(profilePictureUrl),
                                ),
                              )
                            : Icon(
                                Icons.account_circle,
                                size: 58,
                                color: theme.iconTheme.color,
                              ),
                        if (user != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  _uploadProfilePicture(context, user.uid),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: theme.iconTheme.color,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['name'] ?? 'User',
                            style: TextStyle(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: username));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Username copied!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text(
                              username,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(height: 25, color: theme.dividerColor),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('My Profile'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),
          StreamBuilder<int>(
            stream: FriendNotificationService.getPendingRequestCount(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data ?? 0;

              return ListTile(
                leading: Icon(Icons.people),
                title: Text('Friends'),
                trailing: pendingCount > 0
                    ? Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FriendListScreen()),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    setTheme:
                        ThemeService.changeTheme, // Updated to use ThemeService
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(builder: (context) => SignInPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
