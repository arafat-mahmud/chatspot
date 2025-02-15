import 'package:flutter/material.dart';
import 'views/auth/signin.dart';
import 'views/settings/settings.dart';

void main() {
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
      title: 'Auth Example',
      theme: _themeData,
      home: SignInPage(),
    );
  }
}
