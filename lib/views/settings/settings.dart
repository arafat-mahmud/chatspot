import 'package:chatspot/views/settings/theme_service.dart';
import 'package:flutter/material.dart';
import '../auth/signin.dart'; // Import the SignInPage
import 'account_settings.dart'; // Import the AccountSettingsPage

class SettingsPage extends StatelessWidget {
  final void Function(ThemeData) setTheme; // Ensure this is non-nullable

  SettingsPage({required this.setTheme}); // Constructor to accept the function

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('Account'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountSettingsPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            onTap: () {
              // Handle notification settings
            },
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Privacy'),
            onTap: () {
              // Handle privacy settings
            },
          ),
          ListTile(
            leading: Icon(Icons.help),
            title: Text('Help & Support'),
            onTap: () {
              // Handle help and support
            },
          ),
          ListTile(
            leading: Icon(Icons.palette),
            title: Text('Theme'),
            onTap: () {
              _showThemeDialog(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () {
              // Navigate back to the SignInPage
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => SignInPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Select Theme'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              ListTile(
                title: Text('Light'),
                onTap: () {
                  ThemeService.changeTheme(ThemeData.light());
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Dark'),
                onTap: () {
                  ThemeService.changeTheme(ThemeData.dark());
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('System Default'),
                onTap: () {
                  ThemeService.changeTheme(ThemeData.fallback());
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
