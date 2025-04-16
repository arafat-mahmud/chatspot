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
  String _dob = ''; // Add this for date of birth
  String _gender = ''; // Add this for gender

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _originalUsername = '';
  String _usernameAvailabilityMessage = '';
  bool _isUsernameAvailable = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fetchUserData();
    _testUsernameCheck(); // Call the test function here
  }

  void _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _nameController.text = userDoc['name'] ?? '';
          String savedUsername = userDoc['username'] ?? '';
          _originalUsername = savedUsername;
          _usernameController.text = savedUsername.replaceFirst('@', '');

          // Add these lines to fetch dob and gender
          _dob = userDoc['dob'] ?? 'Not specified';
          _gender = userDoc['gender'] ?? 'Not specified';
        } else {
          _nameController.text = '';
          _usernameController.text = '';
          _dob = 'Not specified';
          _gender = 'Not specified';
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
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
              onChanged: (value) async {
                String username = value.trim().toLowerCase();
                String usernameWithAt = '@$username';
                if (username.isNotEmpty) {
                  if (!RegExp(r'^[a-z0-9_]{5,}$').hasMatch(username)) {
                    setState(() {
                      _usernameAvailabilityMessage =
                          'Username must be at least 5 characters long and can contain lowercase letters, numbers, and underscores.';
                      _isUsernameAvailable = false;
                    });
                  } else {
                    final usernameExists =
                        await _checkUsernameAvailability(usernameWithAt);
                    setState(() {
                      _usernameAvailabilityMessage = usernameExists
                          ? 'Username is already taken.'
                          : 'Username is available.';
                      _isUsernameAvailable = !usernameExists;
                      print(
                          'Username availability: $_isUsernameAvailable, Username: $usernameWithAt');
                    });
                  }
                } else {
                  setState(() {
                    _usernameAvailabilityMessage = '';
                    _isUsernameAvailable = false;
                  });
                }
              },
            ),
            SizedBox(height: 8),
            Text(
              _usernameAvailabilityMessage,
              style: TextStyle(
                color: _usernameAvailabilityMessage.contains('available')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            SizedBox(height: 16),
            // Add these new fields for Date of Birth and Gender
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text('Date of Birth: '),
                  Text(
                    _dob,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text('Gender: '),
                  Text(
                    _gender,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    // Always allow name to be updated
                    String name = _nameController.text.trim();

                    // Check if username is modified and available
                    String username =
                        _usernameController.text.trim().toLowerCase();
                    String usernameWithAt = '@$username';
                    bool isUsernameModified =
                        usernameWithAt != _originalUsername;

                    if (isUsernameModified) {
                      if (!_isUsernameAvailable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Username is not available.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    // Update user data
                    await _firestore.collection('users').doc(user.uid).set({
                      'name': name,
                      'username': isUsernameModified
                          ? usernameWithAt
                          : _originalUsername,
                    }, SetOptions(merge: true));

                    print("User data updated successfully!");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Update original username if it was changed
                    if (isUsernameModified) {
                      setState(() {
                        _originalUsername = usernameWithAt;
                      });
                    }
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

  void _testUsernameCheck() async {
    // Use your real username for testing
    bool taken = await _checkUsernameAvailability('@testusername');
    print('Test username check: @testusername is taken: $taken');
    bool available = await _checkUsernameAvailability('@testusernamenotTaken');
    print('Test username check: @testusernamenotTaken is taken: $available');
  }
}
