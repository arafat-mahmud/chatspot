/// Tunables for 1:1 WebRTC audio/video calls.
///
/// Calls are peer-to-peer over STUN, with no paid relay. Call quality adapts
/// to the network on the device (see [CallQualityController]).
///
/// An optional TURN relay can be injected at build time so credentials never
/// land in git:
///
///   flutter run \
///     --dart-define=TURN_URLS=turn:turn.example.com:3478,turns:turn.example.com:5349 \
///     --dart-define=TURN_USERNAME=user \
///     --dart-define=TURN_CREDENTIAL=secret
///
/// Without TURN, calls still work on most Wi-Fi / home networks via STUN, but
/// fail to connect when either side is behind a symmetric NAT, which is how
/// most mobile carriers share IP addresses.
class CallConfig {
  /// How long an unanswered call rings before it is marked as missed.
  static const Duration ringTimeout = Duration(seconds: 45);

  /// How long placing a call may wait for the server; Firestore writes
  /// otherwise wait forever while offline. Generous because a slow mobile
  /// link can take several seconds just to reopen its connection.
  static const Duration signalingTimeout = Duration(seconds: 25);

  /// How long we wait for media to flow after the callee accepts. On slow,
  /// high-latency links the connectivity checks take a while.
  static const Duration connectTimeout = Duration(seconds: 45);

  /// How long a dropped connection may try to recover before the call ends.
  static const Duration reconnectTimeout = Duration(seconds: 45);

  /// Grace period on "disconnected" before forcing an ICE restart; network
  /// blips, frequent on weak mobile links, usually recover on their own.
  static const Duration iceRestartDelay = Duration(seconds: 5);

  /// How often connection stats are sampled to adapt call quality.
  static const Duration statsInterval = Duration(seconds: 2);

  /// Opus fullband (48 kHz) target bitrate — "HD voice". WebRTC's default is
  /// ~32 kbps; 64 kbps mono is effectively transparent for speech.
  static const int hdAudioBitrate = 64000;

  /// Video capture target and upper bitrate bound on a fast network (Full
  /// HD). [CallQualityController] scales both down on slower networks;
  /// cameras that can't capture 1080p deliver their closest size.
  static const int videoWidth = 1920;
  static const int videoHeight = 1080;
  static const int videoFrameRate = 30;
  static const int maxVideoBitrate = 4000000;

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
        // Keeps gathering after network changes (Wi-Fi <-> mobile, cell
        // handover) so the call can move paths without a full ICE restart.
        'continualGatheringPolicy': 'gather_continually',
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
