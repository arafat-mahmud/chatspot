import 'package:chatspot/chats&calls_button.dart';
import 'package:chatspot/views/chat/user_chat_screen.dart';
import 'package:chatspot/views/settings/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/auth/signin.dart';
import 'forgot_password.dart';
import 'firebase_options.dart';

const String base64SignerKey = 'yWflScrPyZIFtzEXL1RIEIah7Gq1hUwCgiobw4+TIFQ=';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print('Firebase init error: $e');
  }

  await ThemeService.init();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        ThemeService.updateCurrentUser(snapshot.data?.uid);
        
        return ValueListenableBuilder<ThemeData>(
          valueListenable: ThemeService.themeNotifier,
          builder: (context, theme, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Chatspot',
              theme: theme,
              home: snapshot.hasData ? HomePage() : SignInPage(),
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
          },
        );
      },
    );
  }
}