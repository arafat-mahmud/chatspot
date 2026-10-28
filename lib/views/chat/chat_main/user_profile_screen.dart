import 'package:flutter/material.dart';
import 'package:chatspot/services/call/call_model.dart';
import 'package:chatspot/services/call/call_service.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/user/user_profile.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import 'package:chatspot/views/no_back_button_app_bar.dart';
import 'package:flutter/services.dart';
import 'image_handler.dart';

/// Someone's profile, with actions that match how you're connected.
///
/// Shows whatever is cached at once (friends list, search results) and
/// fills in the rest with at most one read, which [UserRepository] reuses
/// for 12 hours.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserRepository _users = UserRepository.instance;
  final FriendRepository _friends = FriendRepository.instance;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile = _users.peek(widget.userId);
    _load();
  }

  Future<void> _load() async {
    final profile = await _users.get(widget.userId);
    if (!mounted) return;
    setState(() {
      _profile = profile ?? _profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBar = theme.appBarTheme.titleTextStyle?.color ?? Colors.white;
    final profile = _profile;

    return Scaffold(
      appBar: NoBackButtonAppBar(
        title: 'Profile',
        titleColor: onBar,
        backgroundColor: theme.primaryColor,
        iconTheme: IconThemeData(color: onBar),
      ),
      body: profile == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'User not found',
                ))
          : ValueListenableBuilder<FriendsState>(
              valueListenable: _friends.state,
              builder: (context, _, __) => _buildProfile(theme, profile),
            ),
    );
  }

  Widget _buildProfile(ThemeData theme, UserProfile profile) {
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Center(
          child: UserAvatar(
            name: profile.displayName,
            photoUrl: profile.photoUrl,
            radius: 52,
            onTap: profile.photoUrl.isEmpty
                ? null
                : () =>
                    ImageHandler.showFullScreenImage(context, profile.photoUrl),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (profile.username.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            profile.username,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 24),
        _buildActions(profile),
        const SizedBox(height: 28),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _infoTile(Icons.alternate_email, 'Username',
                  profile.username.isNotEmpty ? profile.username : 'Not set',
                  copyable: profile.username.isNotEmpty),
              if (profile.email.isNotEmpty)
                _infoTile(Icons.mail_outline, 'Email', profile.email),
              if (profile.dob.isNotEmpty)
                _infoTile(Icons.cake_outlined, 'Date of birth', profile.dob),
              if (profile.emailVerified)
                ListTile(
                  leading: Icon(Icons.verified, color: Colors.green.shade600),
                  title: Text(
                    'Verified account',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActions(UserProfile profile) {
    switch (_friends.relationTo(profile.uid)) {
      case Relationship.self:
        return const SizedBox.shrink();
      case Relationship.friend:
        final friend = _friends.state.value.friend(profile.uid)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _action(Icons.chat_bubble_outline, 'Message', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserChatScreen(
                      userId: profile.uid, userName: profile.displayName),
                ),
              );
            }),
            _action(Icons.call_outlined, 'Voice', () => _call(profile, CallType.audio)),
            _action(Icons.videocam_outlined, 'Video', () => _call(profile, CallType.video)),
            _action(Icons.person_remove_outlined, 'Remove', () => _confirmRemove(friend)),
          ],
        );
      case Relationship.requestReceived:
        final request = _friends.state.value.incomingFrom(profile.uid)!;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _friends.decline(request),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _friends.accept(request),
                child: const Text('Accept request'),
              ),
            ),
          ],
        );
      case Relationship.requestSent:
        final request = _friends.state.value.outgoingTo(profile.uid)!;
        return OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: const Text('Requested · Tap to cancel'),
          onPressed: () => _friends.cancel(request),
        );
      case Relationship.none:
        return FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add friend'),
          onPressed: () => _friends.sendRequest(profile),
        );
    }
  }

  Widget _action(IconData icon, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          IconButton.filledTonal(
            icon: Icon(icon),
            onPressed: onPressed,
            iconSize: 24,
            padding: const EdgeInsets.all(14),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value,
      {bool copyable = false}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: copyable ? const Icon(Icons.copy, size: 18) : null,
      onTap: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          : null,
    );
  }

  void _call(UserProfile profile, CallType type) {
    CallService.instance.startCall(
      context,
      calleeId: profile.uid,
      calleeName: profile.displayName,
      calleePhotoUrl: profile.photoUrl,
      type: type,
    );
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text("You'll need a new request to chat with "
            '${friend.displayName} again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) _friends.remove(friend);
  }
}
