import 'package:flutter/material.dart';
import 'views/auth/signin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Auth Example',
      theme: ThemeData(
        fontFamily: 'Chivo',
      ),
      home: SignInPage(),
    );
  }
}
