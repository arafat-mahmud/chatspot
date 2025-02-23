import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController; // Mark as late
  final TextEditingController _contactController =
      TextEditingController(text: '+1234567890');

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on initialization
  }

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser; // Get the current user
    if (user != null) {
      // Replace 'user_id_here' with the actual user ID
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _nameController = TextEditingController(
            text: userDoc['name']); // Initialize with Firestore data
      } else {
        _nameController =
            TextEditingController(text: ''); // Default value if user not found
      }
      setState(() {
        _isLoading = false; // Update loading state
      });
    } else {
      // Handle the case where the user is not authenticated
      // You might want to redirect to a login page
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator()); // Show loading indicator
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller:
                  _nameController, // Use the dynamically initialized controller
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Save the changes
                print('Name: ${_nameController.text}');
                print('Contact: ${_contactController.text}');

                // Update Firestore user name
                final user =
                    FirebaseAuth.instance.currentUser; // Get the current user
                if (user != null) {
                  await _firestore
                      .collection('users')
                      .doc(user.uid) // Use the authenticated user's ID
                      .update({
                    'name': _nameController.text,
                  }).then((_) {
                    print("User name updated successfully!");
                  }).catchError((error) {
                    print("Failed to update user name: $error");
                  });
                }
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
