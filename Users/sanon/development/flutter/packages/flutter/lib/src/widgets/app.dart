import 'package:flutter/material.dart';

class YourApp extends StatefulWidget {
  @override
  _YourAppState createState() => _YourAppState();
}

class _YourAppState extends State<YourApp> {
  String email = ''; // Change 'final' to allow updates

  void _sendPasswordResetEmail(String email) {
    // Logic to send password reset email
    // This could involve calling your backend API
    print('Password reset email sent to $email');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your App')),
      body: Center(
        child: Column(
          children: [
            // TextField for email input
            TextField(
              decoration: InputDecoration(labelText: 'Enter your email'),
              onChanged: (value) {
                setState(() {
                  email = value; // Now you can update 'email'
                });
              },
            ),
            // Button to send password reset email
            ElevatedButton(
              onPressed: () {
                _sendPasswordResetEmail(email); // Now 'email' is defined
              },
              child: Text('Send Password Reset Email'),
            ),
            // Button to navigate to forgot password screen
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context,
                    '/forgot-password'); // Navigate to the forgot password screen
              },
              child: Text('Forgot Password?'), // Update the button text
            ),
          ],
        ),
      ),
    );
  }

  // ...
}
