import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatspot/views/no_back_button_app_bar.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize Firebase Auth

  @override
  Widget build(BuildContext context) {
    String email = '';

    return Scaffold(
      appBar: NoBackButtonAppBar(title: 'Forgot Password'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Enter your email'),
              onChanged: (value) {
                email = value; // Update email variable
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _auth.sendPasswordResetEmail(
                      email: email); // Send password reset email
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Password reset email sent to $email')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
