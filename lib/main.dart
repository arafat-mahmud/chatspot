import 'package:chatspot/dashboard/chats&calls_button.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/services/app_messenger.dart';
import 'package:chatspot/services/call/call_service.dart';
import 'package:chatspot/services/notification/push_notification_service.dart';
import 'package:chatspot/services/session/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // Every screen reads through Firestore's on-device cache: lists appear
    // instantly on launch and work offline, and resumed listeners only pay
    // for what changed. Must be set before the first Firestore call.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 200 * 1024 * 1024,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await ThemeService.init();
  await PushNotificationService.instance.init();
  // Before runApp: tapping Accept on the system call screen can be what
  // launched the app.
  CallService.instance.init();
  SessionService.instance.init();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return MaterialApp(
          navigatorKey: CallService.instance.navigatorKey,
          scaffoldMessengerKey: AppMessenger.key,
          debugShowCheckedModeBanner: false,
          title: 'Chatnook',
          theme: theme,
          home: const AuthGate(),
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
  }
}

/// Shows the app for a signed-in, verified user and the sign-in screen
/// otherwise. Screens never navigate on sign-in or sign-out themselves.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([session.resolved, session.uid]),
      builder: (context, _) {
        if (!session.resolved.value) {
          return Scaffold(
            body: Center(
              child: Icon(
                Icons.forum_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        final uid = session.uid.value;
        // A fresh home per account, so no state leaks between accounts.
        return uid == null ? SignInPage() : HomePage(key: ValueKey(uid));
      },
    );
  }
}
