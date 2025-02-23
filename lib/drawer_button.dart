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
                return DrawerHeader(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return DrawerHeader(child: Text('Error loading user info'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return DrawerHeader(child: Text('User not found'));
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;

              return DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${userData['name'] ?? 'User'}',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
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
