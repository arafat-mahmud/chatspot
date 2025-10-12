import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:flutter/material.dart';
import '../../../../views/auth/signin.dart'; // Import the SignInPage
import 'account_settings.dart'; // Import the AccountSettingsPage

class SettingsPage extends StatefulWidget {
  final void Function(ThemeData) setTheme; // Ensure this is non-nullable

  SettingsPage({required this.setTheme}); // Constructor to accept the function

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // This removes the back button
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
            subtitle:
                Text(ThemeService.isDarkMode ? 'Dark Mode' : 'Light Mode'),
            trailing: Switch(
              value: ThemeService.isDarkMode,
              onChanged: (value) {
                setState(() {
                  ThemeService.toggleTheme();
                });
              },
            ),
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
                  trailing: ThemeService.isDarkMode ? null : Icon(Icons.check),
                  onTap: () {
                    if (ThemeService.isDarkMode) {
                      setState(() {
                        ThemeService.toggleTheme();
                      });
                    }
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text('Dark'),
                  trailing: ThemeService.isDarkMode ? Icon(Icons.check) : null,
                  onTap: () {
                    if (!ThemeService.isDarkMode) {
                      setState(() {
                        ThemeService.toggleTheme();
                      });
                    }
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
