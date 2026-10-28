import 'package:flutter/material.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/views/chat/chat_main/user_profile_screen.dart';
import 'package:chatspot/views/common/presence_widgets.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import 'package:chatspot/views/no_back_button_app_bar.dart';
import 'package:chatspot/views/search_bar/friend_aware_search_page.dart';
import 'package:intl/intl.dart';
import '../chat/chat_main/image_handler.dart';

/// Friends and friend requests. Everything here comes from
/// [FriendRepository]'s live in-memory state: opening the screen, switching
/// tabs and filtering cost no reads.
class FriendListScreen extends StatefulWidget {
  const FriendListScreen({super.key, this.initialTab = 0});

  /// 0: friends, 1: requests.
  final int initialTab;

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen>
    with SingleTickerProviderStateMixin {
  final FriendRepository _friends = FriendRepository.instance;
  late final TabController _tabController = TabController(
      length: 2, vsync: this, initialIndex: widget.initialTab);
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    _onTabChanged();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Viewing requests clears the badge (writes only unseen ones).
    if (_tabController.index == 1) _friends.markRequestsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBar = theme.appBarTheme.titleTextStyle?.color ?? Colors.white;

    return ValueListenableBuilder<FriendsState>(
      valueListenable: _friends.state,
      builder: (context, state, _) => Scaffold(
        appBar: NoBackButtonAppBar(
          title: 'Friends',
          backgroundColor: theme.primaryColor,
          titleColor: onBar,
          iconTheme:
              theme.appBarTheme.iconTheme ?? IconThemeData(color: onBar),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Find people',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FriendAwareSearchPage()),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: onBar,
            unselectedLabelColor: onBar.withValues(alpha: 0.7),
            indicatorColor: onBar,
            tabs: [
              Tab(
                text: state.friends.isEmpty
                    ? 'Friends'
                    : 'Friends (${state.friends.length})',
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Requests'),
                    if (state.incoming.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CountBadge(state.incoming.length),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFriends(state),
            _buildRequests(state),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Friends tab
  // ---------------------------------------------------------------------------

  Widget _buildFriends(FriendsState state) {
    if (!state.loaded) return const ListSkeleton();
    if (state.friends.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No friends yet',
        message: 'Find people by name or @username and send a request.',
        actionLabel: 'Find people',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FriendAwareSearchPage()),
        ),
      );
    }

    final query = _query.toLowerCase();
    final friends = query.isEmpty
        ? state.friends
        : state.friends
            .where((f) =>
                f.name.toLowerCase().contains(query) ||
                f.username.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search friends',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        Expanded(
          child: friends.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different name or username.',
                )
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) =>
                      _buildFriendTile(friends[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return ListTile(
      leading: PresenceAvatar(
        uid: friend.uid,
        name: friend.displayName,
        photoUrl: friend.photoUrl,
        onTap: friend.photoUrl.isEmpty
            ? null
            : () => ImageHandler.showFullScreenImage(context, friend.photoUrl),
      ),
      title: Text(friend.displayName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: PresenceLabel(uid: friend.uid, fallback: friend.username),
      onTap: () => _openChat(friend),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'chat':
              _openChat(friend);
            case 'profile':
              _openProfile(friend.uid);
            case 'remove':
              _confirmRemove(friend);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'chat',
            child: ListTile(
              leading: Icon(Icons.chat_bubble_outline),
              title: Text('Message'),
            ),
          ),
          PopupMenuItem(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('View profile'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.person_remove_outlined, color: Colors.red),
              title: Text('Remove friend', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Requests tab
  // ---------------------------------------------------------------------------

  Widget _buildRequests(FriendsState state) {
    if (state.incoming.isEmpty && state.outgoing.isEmpty) {
      return const EmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No pending requests',
        message: 'Requests you send or receive show up here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (state.incoming.isNotEmpty) ...[
          _sectionHeader('Received', state.incoming.length),
          for (final request in state.incoming) _buildIncomingTile(request),
        ],
        if (state.outgoing.isNotEmpty) ...[
          _sectionHeader('Sent', state.outgoing.length),
          for (final request in state.outgoing) _buildOutgoingTile(request),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$title · $count',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIncomingTile(FriendRequest request) {
    final sender = request.sender;
    return ListTile(
      leading: UserAvatar(name: sender.displayName, photoUrl: sender.photoUrl),
      title: Text(sender.displayName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (sender.username.isNotEmpty) sender.username,
          _formatRequestDate(request.sentAt),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _openProfile(request.senderId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.close),
            tooltip: 'Decline',
            onPressed: () => _friends.decline(request),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            icon: const Icon(Icons.check),
            tooltip: 'Accept',
            onPressed: () {
              _friends.accept(request);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('You and ${sender.displayName} are now friends'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingTile(FriendRequest request) {
    final receiver = request.receiver;
    return ListTile(
      leading:
          UserAvatar(name: receiver.displayName, photoUrl: receiver.photoUrl),
      title: Text(
        receiver.name.isNotEmpty ? receiver.name : 'Pending request',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (receiver.username.isNotEmpty) receiver.username,
          _formatRequestDate(request.sentAt),
        ].join(' · '),
      ),
      onTap: () => _openProfile(request.receiverId),
      trailing: OutlinedButton(
        onPressed: () => _friends.cancel(request),
        child: const Text('Cancel'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openChat(Friend friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserChatScreen(userId: friend.uid, userName: friend.displayName),
      ),
    );
  }

  void _openProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid)),
    );
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
            "${friend.displayName} won't be notified. You'll need a new request to chat again."),
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

  static String _formatRequestDate(DateTime? date) {
    if (date == null) return 'Recently';
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 7) return DateFormat('MMM d, yyyy').format(date);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
