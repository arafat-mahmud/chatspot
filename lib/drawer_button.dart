import 'package:flutter/material.dart';
import 'views/settings/settings.dart'; // Updated path
import 'views/settings/profile.dart'; // Updated path
import 'main.dart'; // Import MyApp to access MyAppState
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

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
                return DrawerHeader(child: Container());
              }
              if (snapshot.hasError) {
                return DrawerHeader(child: Text('Error loading user info'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return DrawerHeader(child: Text('User not found'));
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;

              return SizedBox(
                height: 150, // Adjust height as needed
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Align everything to the left
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 58,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8), // Space between icon and username
                      Text(
                        userData['name'] ?? 'User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4), // Space between name and username
                      Text(
                        userData['username'] ??
                            'No Username', // Display username
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  final myAppState =
                      context.findAncestorStateOfType<MyAppState>();
                  return SettingsPage(setTheme: myAppState!.setTheme);
                }),
              );
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
