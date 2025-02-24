import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  final TextEditingController _usernameController =
      TextEditingController(text: 'arafat123');

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
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
        _nameController = TextEditingController(
            text: userDoc['name']);
      } else {
        _nameController =
            TextEditingController(text: '');
      }
      setState(() {
        _isLoading = false;
      });
    } else {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator());
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
                  _nameController,
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
                // Save the changes
                print('Name: ${_nameController.text}');
                print('Username: ${_usernameController.text}');

                // Update Firestore user name
                final user =
                    FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
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
