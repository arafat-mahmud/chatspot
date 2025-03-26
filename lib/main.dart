import 'package:chatspot/chats&calls_button.dart';
import 'package:chatspot/views/chat/user_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/auth/signin.dart';
import 'forgot_password.dart';
import 'firebase_options.dart';


const String base64SignerKey =
    'yWflScrPyZIFtzEXL1RIEIah7Gq1hUwCgiobw4+TIFQ='; // Replace with 'openssl rand -base64 32' type in terminal

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
  ThemeData _themeData = ThemeData.light();

  void setTheme(ThemeData theme) {
    setState(() {
      _themeData = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatspot',
      theme: _themeData,
      home: FirebaseAuth.instance.currentUser != null ? HomePage() : SignInPage(),
      onGenerateRoute: (settings) {
  if (settings.name == '/user-chat-screen') {
    final args = settings.arguments as Map<String, dynamic>;
    return MaterialPageRoute(
      builder: (context) => UserChatScreen(
        userId: args['userId'],
        userName: args['userName'],
      ),
    );
  }
  return null;
},
      routes: {
        '/forgot-password': (context) => ForgotPasswordScreen(),
      },
    );
  }
}
