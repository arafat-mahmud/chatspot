import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'views/settings/profile.dart';
import 'views/settings/settings.dart';
import '../main.dart'; // Correct path to MyAppState

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return DrawerHeader(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return DrawerHeader(child: Text('Error loading user info'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return DrawerHeader(child: Text('User not found'));
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              String username = userData['username'] ??
                  'No Username'; // Handle missing username

              return Container(
                padding: EdgeInsets.all(16), // Adds padding to avoid overflow
                color: Colors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Adapts height dynamically
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 58,
                      color: Colors.white,
                    ),
                    SizedBox(height: 8), // Space between icon and name
                    Text(
                      userData['name'] ?? 'User', // Handle missing name
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8), // Space between name and username
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4, // Space between username and copy icon
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
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
                          child: Icon(
                            Icons.copy,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  final myAppState =
                      context.findAncestorStateOfType<MyAppState>();
                  return SettingsPage(setTheme: myAppState!.setTheme);
                },
              ));
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}