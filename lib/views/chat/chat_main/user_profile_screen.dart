import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:flutter/services.dart'; // Added for Clipboard functionality

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<DocumentSnapshot> _userFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserData();
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    return await _firestore.collection('users').doc(widget.userId).get();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        final textColor =
            theme.brightness == Brightness.dark ? Colors.white : Colors.black;
        final secondaryTextColor = theme.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.7)
            : Colors.black.withOpacity(0.6);
        final iconColor = Colors.green;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Profile',
              style: TextStyle(color: textColor),
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            iconTheme: IconThemeData(color: textColor),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          body: FutureBuilder<DocumentSnapshot>(
            future: _userFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading profile'));
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('User not found'));
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final name = userData['name'] ?? 'No name';
              final username = userData['username'] ?? '';
              final profilePictureUrl = userData['profilePictureUrl'] ?? '';
              final dob = userData['dob'] ?? 'Not specified';
              final email = userData['email'] ?? '';

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: profilePictureUrl.isNotEmpty
                          ? CachedNetworkImageProvider(profilePictureUrl)
                          : null,
                      child: profilePictureUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '',
                              style: TextStyle(fontSize: 24))
                          : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 30),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: secondaryTextColor,
                            ),
                          ),
                          SizedBox(height: 5),
                          GestureDetector(
                            onLongPress: () {
                              if (username.isNotEmpty) {
                                Clipboard.setData(
                                    ClipboardData(text: username));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Username copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    username.isNotEmpty ? username : 'Not set',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: secondaryTextColor,
                            ),
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  email.isNotEmpty ? email : 'Not set',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Date of Birth',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: secondaryTextColor,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            dob,
                            style: TextStyle(
                              fontSize: 16.0,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: iconColor,
                                size: 22,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Verified User',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: iconColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
