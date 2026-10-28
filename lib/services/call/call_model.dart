import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { audio, video }

/// Lifecycle of a call document in Firestore (`calls/{callId}.status`).
///
/// `ringing` and `accepted` are live states; everything else is terminal.
enum CallStatus {
  ringing,
  accepted,
  ended,
  declined,
  missed,
  busy,
  cancelled,
  failed;

  bool get isTerminal => this != ringing && this != accepted;

  static CallStatus parse(Object? value) => CallStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => CallStatus.failed,
      );
}

/// Immutable snapshot of a `calls/{callId}` document.
class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhotoUrl;
  final String calleeId;
  final String calleeName;
  final String? calleePhotoUrl;
  final CallType type;
  final CallStatus status;
  final DateTime? createdAt;
  final int durationSeconds;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.calleeId,
    required this.calleeName,
    this.calleePhotoUrl,
    required this.type,
    required this.status,
    this.createdAt,
    this.durationSeconds = 0,
  });

  bool get isVideo => type == CallType.video;

  bool isOutgoingFor(String uid) => callerId == uid;
  String otherUserId(String uid) => isOutgoingFor(uid) ? calleeId : callerId;
  String otherUserName(String uid) =>
      isOutgoingFor(uid) ? calleeName : callerName;
  String? otherUserPhotoUrl(String uid) =>
      isOutgoingFor(uid) ? calleePhotoUrl : callerPhotoUrl;

  /// A call the user never picked up (incoming side only).
  bool isMissedFor(String uid) =>
      !isOutgoingFor(uid) &&
      (status == CallStatus.missed || status == CallStatus.cancelled);

  factory CallModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CallModel(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerPhotoUrl: _nonEmpty(data['callerPhotoUrl']),
      calleeId: data['calleeId'] ?? '',
      calleeName: data['calleeName'] ?? 'Unknown',
      calleePhotoUrl: _nonEmpty(data['calleePhotoUrl']),
      type: data['type'] == CallType.video.name ? CallType.video : CallType.audio,
      status: CallStatus.parse(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
