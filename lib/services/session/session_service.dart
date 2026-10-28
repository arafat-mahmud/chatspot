import 'dart:async';

import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../call/call_service.dart';
import '../chat/chat_repository.dart';
import '../friend/friend_repository.dart';
import '../notification/push_notification_service.dart';
import '../presence/presence_service.dart';
import '../user/profile_service.dart';
import '../user/user_repository.dart';

/// Starts everything that belongs to a signed-in user exactly once per
/// sign-in, and tears it down on sign-out.
///
/// This used to run from the root widget's build method, which re-ran it on
/// rebuilds and rewrote every chat document on each app start.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  /// The signed-in, email-verified user; null otherwise.
  final ValueNotifier<String?> uid = ValueNotifier(null);

  /// Firebase has reported the initial auth state; until then the app
  /// shows a splash instead of flashing the sign-in screen.
  final ValueNotifier<bool> resolved = ValueNotifier(false);

  StreamSubscription? _authSub;
  bool _sawFirstAuthEvent = false;

  void init() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  Future<void> signOut() async {
    // While still signed in: the rules only let us write our own presence.
    await PresenceService.instance.goOffline();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _onAuth(User? user) async {
    final next = (user != null && user.emailVerified) ? user.uid : null;
    final firstEvent = !_sawFirstAuthEvent;
    _sawFirstAuthEvent = true;
    if (next == uid.value) {
      resolved.value = true;
      return;
    }

    if (uid.value != null) await _stop();
    // Screens pushed by the previous session (or the sign-up flow) don't
    // belong to the new one. Not on launch: an accepted call may be opening.
    if (!firstEvent) {
      CallService.instance.navigatorKey.currentState
          ?.popUntil((route) => route.isFirst);
    }
    uid.value = next;
    resolved.value = true;
    if (next != null) await _start(next);
  }

  Future<void> _start(String userId) async {
    ThemeService.updateCurrentUser(userId);
    await UserRepository.instance.start(userId);
    FriendRepository.instance.start(userId);
    ChatRepository.instance.start(userId);
    PresenceService.instance.start(userId);
    UserRepository.instance.me.addListener(_onProfile);
    // Needs the navigator, which exists once the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (uid.value != userId) return;
      CallService.instance.attach(userId);
      PushNotificationService.instance.attach(userId);
    });
  }

  Future<void> _stop() async {
    UserRepository.instance.me.removeListener(_onProfile);
    CallService.instance.detach();
    PushNotificationService.instance.detach();
    await PresenceService.instance.stop();
    await ChatRepository.instance.stop();
    await FriendRepository.instance.stop();
    await UserRepository.instance.stop();
    ThemeService.updateCurrentUser(null);
  }

  void _onProfile() {
    final me = UserRepository.instance.me.value;
    if (me != null) ProfileService.ensureSearchable(me);
  }
}
