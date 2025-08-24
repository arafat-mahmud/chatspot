import 'package:chatspot/dashboard/chats&calls_button.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/services/chat_initialization_service.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/auth/signin.dart';
import 'views/auth/forgot_password.dart';
import 'services/firebase_options.dart';

const String base64SignerKey = 'yWflScrPyZIFtzEXL1RIEIah7Gq1hUwCgiobw4+TIFQ=';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
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

        // Initialize user chats when user signs in
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await ChatInitializationService.initializeUserChats();
            // Initialize chat cache after chat initialization
            await ChatCacheService().initializeCache();
          });
        } else {
          // Clear cache when user signs out
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ChatCacheService().clearAndReinitialize();
          });
        }

        return ValueListenableBuilder<ThemeData>(
          valueListenable: ThemeService.themeNotifier,
          builder: (context, theme, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Chatnook',
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
