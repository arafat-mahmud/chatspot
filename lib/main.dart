import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/auth/signin.dart';
import 'forgot_password.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase app already initialized: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeData _themeData = ThemeData.light(); // Default theme

  void setTheme(ThemeData theme) {
    setState(() {
      _themeData = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatspot Messenger',
      theme: _themeData,
      home: SignInPage(),
      routes: {
        '/forgot-password': (context) => ForgotPasswordScreen(),
      },
    );
  }
}
