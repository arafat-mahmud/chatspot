import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  final TextEditingController _usernameController = TextEditingController();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _originalUsername = ''; // Store the original username for comparison

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _nameController = TextEditingController(text: userDoc['name']);
        String savedUsername = userDoc['username'] ?? '';
        _originalUsername = savedUsername; // Store the original username with '@'
        _usernameController.text = savedUsername.replaceFirst('@', ''); // Remove '@' for display
      } else {
        _nameController = TextEditingController(text: '');
        _usernameController.text = '';
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
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
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Trim and lowercase the username
                String username = _usernameController.text.trim().toLowerCase();

                // Add '@' to the username for saving in the database
                String usernameWithAt = '@$username';

                // Check if the username has been modified
                bool isUsernameModified = usernameWithAt != _originalUsername;

                // Validate username only if it has been modified
                if (isUsernameModified) {
                  if (!RegExp(r'^[a-z0-9_]{5,}$').hasMatch(username)) {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Username must be at least 5 characters long and can contain lowercase letters, numbers, and underscores.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return; // Exit the function if validation fails
                  }

                  // Check if username is available
                  final usernameExists = await _checkUsernameAvailability(usernameWithAt);
                  if (usernameExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Username is already taken.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return; // Exit the function if username is taken
                  }
                }

                // Save the changes
                print('Name: ${_nameController.text}');
                print('Username: $usernameWithAt');

                // Update Firestore user data
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await _firestore.collection('users').doc(user.uid).update({
                      'name': _nameController.text,
                      'username': usernameWithAt,
                    });
                    print("User data updated successfully!");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Update the original username after successful save
                    _originalUsername = usernameWithAt;
                  } catch (error) {
                    print("Failed to update user data: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update profile.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    try {
      final userDocs = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      return userDocs.docs.isNotEmpty;
    } catch (e) {
      print("Error checking username availability: $e");
      return false;
    }
  }
}