import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Device-side effects of a call: ringtone, audio routing, screen handling
/// and (on Android) a foreground service so the microphone and camera keep
/// working while the app is in the background.
///
/// Everything here is best-effort — a plugin missing on some platform must
/// never break the call itself.
class CallPlatform {
  static const MethodChannel _channel = MethodChannel('chatspot/call');
  static final FlutterRingtonePlayer _ringtone = FlutterRingtonePlayer();
  static Timer? _iosRingTimer;
  static bool _foregroundTaskInitialized = false;
  static Future<void> _lifecycle = Future.value();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isMobile => _isAndroid || _isIOS;

  static Future<void> startRinging() async {
    await _guard('start ringtone', () => _ringtone.playRingtone(looping: true));
    // iOS plays the system sound once and ignores `looping`.
    if (_isIOS) {
      _iosRingTimer?.cancel();
      _iosRingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _guard('replay ringtone', () => _ringtone.playRingtone());
      });
    }
  }

  static Future<void> stopRinging() async {
    _iosRingTimer?.cancel();
    _iosRingTimer = null;
    await _guard('stop ringtone', _ringtone.stop);
  }

  /// Must run before `getUserMedia`: Android fixes the audio mode per session.
  static Future<void> prepareAudioSession({required bool video}) async {
    if (_isAndroid) {
      await _guard(
        'android audio config',
        () => Helper.setAndroidAudioConfiguration(
            AndroidAudioConfiguration.communication),
      );
    } else if (_isIOS) {
      await _guard(
        'ios audio config',
        () => Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {AppleAudioCategoryOption.allowBluetooth},
          // voiceChat/videoChat enable Apple's voice processing (AEC + NS).
          appleAudioMode:
              video ? AppleAudioMode.videoChat : AppleAudioMode.voiceChat,
        )),
      );
    }
  }

  static Future<void> setSpeakerphone(bool enabled) async {
    if (!_isMobile) return;
    await _guard('speakerphone', () => Helper.setSpeakerphoneOn(enabled));
  }

  /// Turns the screen off when the phone is held to the ear so the cheek
  /// can't hit mute/hang-up. Only meaningful for earpiece audio.
  static Future<void> setProximitySensor(bool enabled) async {
    if (!_isMobile) return;
    await _guard('proximity sensor',
        () => _channel.invokeMethod<void>('setProximitySensor', enabled));
  }

  static Future<void> _setKeepScreenOn(bool enabled) async {
    if (!_isMobile) return;
    await _guard('keep screen on',
        () => _channel.invokeMethod<void>('setKeepScreenOn', enabled));
  }

  static Future<void> onCallActive({
    required bool video,
    required String title,
  }) {
    return _enqueue(() async {
      // Audio calls rely on the proximity sensor instead.
      if (video) await _setKeepScreenOn(true);
      if (_isAndroid) await _startForegroundService(video: video, title: title);
    });
  }

  static Future<void> onCallFinished() async {
    await stopRinging();
    await setProximitySensor(false);
    await _enqueue(() async {
      await _setKeepScreenOn(false);
      if (_isAndroid) {
        await _guard(
            'stop foreground service', FlutterForegroundTask.stopService);
        await _guard(
            'reset audio device', Helper.clearAndroidCommunicationDevice);
      }
    });
  }

  /// Runs call start/finish side effects strictly in order, so a quick
  /// hang-up can't leave the foreground service or screen lock behind.
  static Future<void> _enqueue(Future<void> Function() action) =>
      _lifecycle = _lifecycle.then((_) => action()).catchError((Object e) {
        // One failed step must not block every later call's side effects.
        debugPrint('CallPlatform: call lifecycle step failed: $e');
      });

  static Future<void> _startForegroundService({
    required bool video,
    required String title,
  }) async {
    if (!_foregroundTaskInitialized) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'ongoing_call',
          channelName: 'Ongoing calls',
          channelDescription:
              'Keeps your call running while the app is in the background',
        ),
        iosNotificationOptions:
            const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWifiLock: true,
          allowAutoRestart: false,
          stopWithTask: true,
        ),
      );
      _foregroundTaskInitialized = true;
    }

    await _guard('start foreground service', () async {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: 7001,
        // Android 14+ only grants background mic/camera to matching types,
        // and refuses `camera` unless that permission was granted.
        serviceTypes: [
          ForegroundServiceTypes.microphone,
          if (video) ForegroundServiceTypes.camera,
        ],
        notificationTitle: title,
        notificationText:
            video ? 'Video call in progress' : 'Voice call in progress',
      );
      if (result is ServiceRequestFailure) throw result.error;
    });
  }

  static Future<void> _guard(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('CallPlatform: $label failed: $e');
    }
  }
}
