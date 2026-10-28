import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'call_config.dart';

/// User actions on the native incoming-call screen.
enum NativeCallAction { accept, decline }

/// The system incoming-call screen (Android): rings over the lock screen with
/// Accept / Decline even when the app is in the background or killed.
///
/// Used whenever the app isn't on screen — from the push background isolate
/// when the app is closed, and from [CallService] when it is merely in the
/// background. While the app is open, calls ring in Flutter's [CallScreen].
///
/// iOS is not covered: CallKit on a killed app requires PushKit VoIP pushes.
/// There, a regular push notification opens the app, which then rings.
class CallNotifications {
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const String _askedFullScreenKey = 'callkit_full_screen_asked';
  static StreamSubscription? _backgroundSub;

  /// Accept / decline taps, in whichever isolate is listening.
  static Stream<(NativeCallAction, String)> get actions {
    if (!isSupported) return const Stream.empty();
    return FlutterCallkitIncoming.onEvent.transform(
      StreamTransformer.fromHandlers(handleData: (event, sink) {
        switch (event) {
          case CallEventActionCallAccept(:final callKitParams):
            sink.add((NativeCallAction.accept, callKitParams.id));
          case CallEventActionCallDecline(:final callKitParams):
            sink.add((NativeCallAction.decline, callKitParams.id));
          default:
            break;
        }
      }),
    );
  }

  /// Rings for [callId] unless it is already ringing: the push and the
  /// in-app listener can both report the same call.
  static Future<void> showIncoming({
    required String callId,
    required String callerName,
    String? callerPhotoUrl,
    required bool video,
    DateTime? createdAt,
  }) async {
    if (!isSupported) return;
    final age =
        createdAt == null ? Duration.zero : DateTime.now().difference(createdAt);
    final remaining = CallConfig.ringTimeout - age;
    if (remaining <= Duration.zero) return;

    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active.any((c) => c.id == callId)) return;

      await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'Chatnook',
        avatar: callerPhotoUrl,
        handle: video ? 'Video call' : 'Voice call',
        type: video ? 1 : 0,
        duration: remaining.inMilliseconds,
        // The server sends the missed-call notification, and the call's own
        // foreground service shows the ongoing-call notification.
        missedCallNotification: const NotificationParams(showNotification: false),
        callingNotification: const NotificationParams(showNotification: false),
        android: const AndroidParams(
          isCustomNotification: true,
          isShowFullLockedScreen: true,
          isShowCallID: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#1B2229',
          actionColor: '#4CAF50',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Incoming calls',
          missedCallNotificationChannelName: 'Missed calls',
          textAccept: 'Accept',
          textDecline: 'Decline',
        ),
      ));
    } catch (e) {
      debugPrint('CallNotifications: showing call $callId failed: $e');
    }
  }

  static Future<void> end(String callId) async {
    if (!isSupported) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('CallNotifications: ending call $callId failed: $e');
    }
  }

  /// A call the user accepted on the native screen, which launched the app.
  static Future<String?> acceptedCallId() async {
    if (!isSupported) return null;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      for (final call in active) {
        if (call.isAccepted) return call.id;
      }
    } catch (e) {
      debugPrint('CallNotifications: reading active calls failed: $e');
    }
    return null;
  }

  /// Background isolate only: records a decline tapped while the app is
  /// killed, so the caller stops ringing right away. Accepts launch the app,
  /// which joins the call itself.
  static void handleDeclinesInBackground(
    Future<void> Function(String callId) onDecline,
  ) {
    if (!isSupported || _backgroundSub != null) return;
    _backgroundSub = actions.listen((action) {
      if (action.$1 == NativeCallAction.decline) onDecline(action.$2);
    });
  }

  /// Android 14+ may deny full-screen ringing; asks once to allow it.
  static Future<void> requestFullScreenPermissionOnce() async {
    if (!isSupported) return;
    try {
      if (await FlutterCallkitIncoming.canUseFullScreenIntent()) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedFullScreenKey) == true) return;
      await prefs.setBool(_askedFullScreenKey, true);
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      debugPrint('CallNotifications: full-screen permission check failed: $e');
    }
  }
}
