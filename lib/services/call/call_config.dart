/// Tunables for 1:1 WebRTC audio/video calls.
///
/// TURN credentials are injected at build time so they never land in git:
///
///   flutter run \
///     --dart-define=TURN_URLS=turn:turn.example.com:3478,turns:turn.example.com:5349 \
///     --dart-define=TURN_USERNAME=user \
///     --dart-define=TURN_CREDENTIAL=secret
///
/// Without TURN, calls still work on most Wi-Fi / home networks via STUN, but
/// can fail to connect when either side is behind a symmetric NAT (common on
/// mobile carriers and corporate networks).
class CallConfig {
  /// How long an unanswered call rings before it is marked as missed.
  static const Duration ringTimeout = Duration(seconds: 45);

  /// How long placing a call may wait for the server; Firestore writes
  /// otherwise wait forever while offline.
  static const Duration signalingTimeout = Duration(seconds: 15);

  /// How long we wait for media to flow after the callee accepts.
  static const Duration connectTimeout = Duration(seconds: 30);

  /// How long a dropped connection may try to recover before the call ends.
  static const Duration reconnectTimeout = Duration(seconds: 30);

  /// Grace period on "disconnected" before forcing an ICE restart; short
  /// network blips usually recover on their own within this window.
  static const Duration iceRestartDelay = Duration(seconds: 3);

  /// Opus fullband (48 kHz) target bitrate — "HD voice". WebRTC's default is
  /// ~32 kbps; 64 kbps mono is effectively transparent for speech.
  static const int hdAudioBitrate = 64000;

  /// Video capture target and upper bitrate bound. WebRTC's congestion
  /// control still scales down automatically on poor networks.
  static const int videoWidth = 1280;
  static const int videoHeight = 720;
  static const int videoFrameRate = 30;
  static const int hdVideoMaxBitrate = 2500000;

  static const String _turnUrls = String.fromEnvironment('TURN_URLS');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential =
      String.fromEnvironment('TURN_CREDENTIAL');

  static Map<String, dynamic> get rtcConfiguration => {
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
          if (_turnUrls.isNotEmpty)
            {
              'urls': _turnUrls.split(',').map((u) => u.trim()).toList(),
              'username': _turnUsername,
              'credential': _turnCredential,
            },
        ],
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      };

  static Map<String, dynamic> mediaConstraints({required bool video}) => {
        // `true` lets each platform apply its tuned voice-processing defaults
        // (echo cancellation, noise suppression, auto gain control).
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                // Plain numbers on purpose: flutter_webrtc's Android parser
                // ignores `{'ideal': ...}` maps.
                'width': videoWidth,
                'height': videoHeight,
                'frameRate': videoFrameRate,
              }
            : false,
      };
}
