import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/services/call/call_model.dart';
import 'package:chatspot/services/call/call_service.dart';
import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// The "Calls" tab: recent calls with one-tap call back.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<List<CallModel>>? _history =
      _userId == null ? null : CallService.instance.callHistory(_userId);

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null) {
      return Center(child: Text('Please sign in to view calls'));
    }

    return StreamBuilder<List<CallModel>>(
      stream: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(Icons.error_outline, 'Could not load calls');
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final calls = snapshot.data!;
        if (calls.isEmpty) {
          return _buildMessage(Icons.call_outlined, 'No recent calls');
        }

        return ListView.builder(
          itemCount: calls.length,
          itemBuilder: (context, index) =>
              _CallHistoryTile(call: calls[index], userId: userId),
        );
      },
    );
  }

  Widget _buildMessage(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallModel call;
  final String userId;

  const _CallHistoryTile({required this.call, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = call.otherUserName(userId);
    final photoUrl = call.otherUserPhotoUrl(userId);
    final outgoing = call.isOutgoingFor(userId);
    final missed = call.isMissedFor(userId);

    final directionIcon = missed
        ? Icons.call_missed
        : outgoing
            ? Icons.call_made
            : Icons.call_received;
    final directionColor = missed ? Colors.red : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage:
            photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
        child: photoUrl == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: missed ? Colors.red : null,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(directionIcon, size: 16, color: directionColor),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              '${_describe(outgoing, missed)} · '
              '${DateFormatters.formatMessageTime(call.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(call.isVideo ? Icons.videocam : Icons.call),
        color: theme.colorScheme.primary,
        tooltip: call.isVideo ? 'Video call' : 'Voice call',
        onPressed: () => CallService.instance.startCall(
          context,
          calleeId: call.otherUserId(userId),
          calleeName: name,
          calleePhotoUrl: photoUrl,
          type: call.type,
        ),
      ),
    );
  }

  String _describe(bool outgoing, bool missed) {
    if (missed) return 'Missed';
    switch (call.status) {
      case CallStatus.ended:
        final duration = _formatDuration(call.durationSeconds);
        if (call.durationSeconds == 0) return outgoing ? 'Outgoing' : 'Incoming';
        return '${outgoing ? 'Outgoing' : 'Incoming'} · $duration';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.busy:
        return outgoing ? 'Busy' : 'Missed';
      case CallStatus.missed:
      case CallStatus.cancelled:
        return outgoing ? 'No answer' : 'Missed';
      case CallStatus.failed:
        return 'Failed';
      case CallStatus.ringing:
      case CallStatus.accepted:
        return 'In progress';
    }
  }

  static String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}
