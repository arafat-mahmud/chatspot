import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatspot/views/settings/theme_service.dart'; // Import ThemeService

class EmailVerificationPage extends StatefulWidget {
  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  String _userEmail = '';
  bool _isLoading = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  Future<void> _fetchUserEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _isVerified = user.emailVerified;
        });

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          _userEmail =
              userDoc.exists ? (userDoc['email'] ?? '') : (user.email ?? '');
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user email: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        final textColor = theme.brightness == Brightness.dark 
            ? Colors.white 
            : Colors.black;
        final secondaryTextColor = theme.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.7)
            : Colors.black.withOpacity(0.6);
        final iconColor = _isVerified ? Colors.green : Colors.orange;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Email Address',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            iconTheme: IconThemeData(color: textColor),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email,
                        size: 80,
                        color: iconColor,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Email helps you access your account. It isn\'t visible to others.',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: secondaryTextColor,
                              ),
                            ),
                            SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _userEmail,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  _isVerified ? Icons.check_circle : Icons.error,
                                  color: iconColor,
                                  size: 22,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  _isVerified ? 'Verified' : 'Not Verified',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    color: iconColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}