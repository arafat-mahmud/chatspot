import 'package:flutter/material.dart';
import 'email_verification.dart';

class AccountSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.email),
            title: Text('Email Address'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EmailVerificationPage()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.verified_user),
            title: Text('Two-step Verification'),
            onTap: () {
              // Handle two-step verification
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.phone),
            title: Text('Change Number'),
            onTap: () {
              // Handle change number
            },
          ),
        ],
      ),
    );
  }
} 