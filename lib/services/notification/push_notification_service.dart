import 'dart:async';
import 'dart:convert';

import 'package:chatspot/services/call/call_model.dart';
import 'package:chatspot/services/call/call_notifications.dart';
import 'package:chatspot/services/call/call_service.dart';
import 'package:chatspot/services/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Runs in its own isolate when a push arrives while the app is in the
/// background or killed. Message and missed-call pushes carry a notification
/// the system shows by itself; incoming calls are data-only and ring here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  switch (data['type']) {
    case 'incoming_call':
      CallNotifications.handleDeclinesInBackground(
        (callId) => CallService.closeRingingCall(callId, CallStatus.declined),
      );
      final sentAt = int.tryParse(data['sentAt'] ?? '');
      await CallNotifications.showIncoming(
        callId: data['callId'] ?? '',
        callerName: data['callerName'] ?? 'Unknown',
        callerPhotoUrl:
            (data['callerPhotoUrl'] ?? '').isEmpty ? null : data['callerPhotoUrl'],
        video: data['callType'] == CallType.video.name,
        createdAt: sentAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(sentAt),
      );
    case 'call_ended':
      await CallNotifications.end(data['callId'] ?? '');
  }
}

/// Push notifications: registers this device's FCM token on the user's
/// profile (`users/{uid}.fcmTokens`, read by the Cloud Functions in
/// `functions/`), shows notifications while the app is open and opens the
/// right chat when one is tapped.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _missedCallsChannel =
      AndroidNotificationChannel(
    'missed_calls',
    'Missed calls',
    description: 'Calls you did not answer',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _userId;
  StreamSubscription? _tokenSub;

  /// The friend whose chat is on screen; their messages need no notification.
  String? activeChatUserId;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once from `main()`, before `runApp`.
  Future<void> init() async {
    if (_initialized || !_isMobile) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _openFromPayload(response.payload),
      );
      // Pushes from the server name these channels; they must exist before
      // the first one arrives.
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_messagesChannel);
      await android?.createNotificationChannel(_missedCallsChannel);
    } catch (e) {
      debugPrint('PushNotificationService: local notifications init failed: $e');
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
  }

  /// Registers this device for [userId]'s pushes. Safe to call repeatedly.
  Future<void> attach(String userId) async {
    if (!_isMobile || _userId == userId) return;
    _userId = userId;
    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission();
      await CallNotifications.requestFullScreenPermissionOnce();

      final token = await messaging.getToken();
      if (token != null && _userId == userId) await _saveToken(userId, token);
      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((t) => _saveToken(userId, t));
    } catch (e) {
      debugPrint('PushNotificationService: registering for pushes failed: $e');
    }

    // The app was launched by tapping a notification.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _openFromData(initial.data);
      } else {
        final launch = await _local.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _openFromPayload(launch!.notificationResponse?.payload);
        }
      }
    } catch (e) {
      debugPrint('PushNotificationService: reading launch notification failed: $e');
    }
  }

  /// Stops pushes to this device for the signed-out user. The server drops
  /// the deleted token the next time a send to it fails.
  Future<void> detach() async {
    if (_userId == null) return;
    _userId = null;
    await _tokenSub?.cancel();
    _tokenSub = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('PushNotificationService: deleting token failed: $e');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PushNotificationService: saving token failed: $e');
    }
  }

  /// Removes the notifications of a chat that was just opened.
  Future<void> clearChat(String chatId) async {
    if (!_initialized) return;
    try {
      // Shown by the system from a push (tagged by the server) ...
      await _local.cancel(id: 0, tag: chatId);
      // ... or by [_onForegroundMessage].
      await _local.cancel(id: chatId.hashCode);
    } catch (e) {
      debugPrint('PushNotificationService: clearing notifications failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    switch (data['type']) {
      case 'message':
        if (data['senderId'] == activeChatUserId) return;
        _show(
          id: (data['chatId'] ?? '').hashCode,
          channel: _messagesChannel,
          title: notification?.title ?? data['senderName'],
          body: notification?.body,
          data: data,
        );
      case 'missed_call':
        _show(
          id: (data['callId'] ?? '').hashCode,
          channel: _missedCallsChannel,
          title: notification?.title ?? data['callerName'],
          body: notification?.body ?? 'Missed call',
          data: data,
        );
      // While the app is open, CallService rings for incoming calls itself.
    }
  }

  Future<void> _show({
    required int id,
    required AndroidNotificationChannel channel,
    String? title,
    String? body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('PushNotificationService: showing notification failed: $e');
    }
  }

  void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _openFromData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (e) {
      debugPrint('PushNotificationService: bad notification payload: $e');
    }
  }

  /// Opens the chat a message or missed-call notification is about.
  void _openFromData(Map<String, dynamic> data) {
    final String? userId;
    final String? userName;
    switch (data['type']) {
      case 'message':
        userId = data['senderId'];
        userName = data['senderName'];
      case 'missed_call':
        userId = data['callerId'];
        userName = data['callerName'];
      default:
        return;
    }
    if (userId == null || userId.isEmpty) return;
    CallService.instance.navigatorKey.currentState?.pushNamed(
      '/user-chat-screen',
      arguments: {'userId': userId, 'userName': userName ?? 'Chat'},
    );
  }
}
