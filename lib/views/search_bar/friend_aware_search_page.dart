import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chatspot/dashboard/menu/components/my_profile.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/search/search_history_store.dart';
import 'package:chatspot/services/search/user_search_service.dart';
import 'package:chatspot/services/user/user_profile.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import '../chat/chat_main/main_chat_screen.dart';
import '../chat/chat_main/user_profile_screen.dart';

/// Find people by name or @username.
///
/// Typing is debounced, each search is a few small indexed queries, results
/// are remembered while the page is open, and relationship buttons come
/// from memory. Recent profiles are stored on the device.
class FriendAwareSearchPage extends StatefulWidget {
  @override
  State<FriendAwareSearchPage> createState() => _FriendAwareSearchPageState();
}

class _FriendAwareSearchPageState extends State<FriendAwareSearchPage> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();
  final UserSearchService _search = UserSearchService();
  final FriendRepository _friends = FriendRepository.instance;
  late final String _selfId = UserRepository.instance.me.value?.uid ?? '';
  late final SearchHistoryStore _history = SearchHistoryStore(_selfId);

  Timer? _debounceTimer;
  String _query = '';
  List<UserProfile> _results = const [];
  List<UserProfile> _recent = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _history.load().then((recent) {
      if (mounted) setState(() => _recent = recent);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    setState(() => _query = query);
    _debounceTimer?.cancel();
    if (!UserSearchService.isSearchable(query)) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounceTimer = Timer(_debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    final results = await _search.search(query, selfId: _selfId);
    // Ignore answers to queries the user has already typed past.
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _open(UserProfile profile) async {
    final recent = await _history.add(profile);
    if (mounted) setState(() => _recent = recent);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: profile.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search by name or @username',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: UserRepository.instance.me,
        builder: (context, me, _) {
          if (me != null && !me.hasUsername) return _buildUsernameRequired();
          // Relationship buttons follow requests and accepts live.
          return ValueListenableBuilder<FriendsState>(
            valueListenable: _friends.state,
            builder: (context, _, __) =>
                _query.isEmpty ? _buildRecent() : _buildResults(),
          );
        },
      ),
    );
  }

  Widget _buildUsernameRequired() {
    return EmptyState(
      icon: Icons.alternate_email,
      title: 'Choose a username first',
      message: 'People find and add each other by username.',
      actionLabel: 'Set username',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage()),
      ),
    );
  }

  Widget _buildRecent() {
    if (_recent.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Find people',
        message: 'Search by name, or by @username for an exact person.',
      );
    }
    final theme = Theme.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final recent = await _history.clear();
                  if (mounted) setState(() => _recent = recent);
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        for (final profile in _recent)
          _buildUserTile(
            profile,
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Remove',
              onPressed: () async {
                final recent = await _history.remove(profile.uid);
                if (mounted) setState(() => _recent = recent);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    if (!UserSearchService.isSearchable(_query)) {
      return const EmptyState(
        icon: Icons.keyboard_outlined,
        title: 'Keep typing',
        message: 'Enter at least ${UserSearchService.minNameLength} characters.',
      );
    }
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No one found',
        message: 'No match for "$_query". Check the spelling or try a username.',
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildUserTile(_results[index]),
    );
  }

  Widget _buildUserTile(UserProfile profile, {Widget? trailing}) {
    return ListTile(
      leading: UserAvatar(name: profile.displayName, photoUrl: profile.photoUrl),
      title: Text(profile.displayName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: profile.username.isEmpty ? null : Text(profile.username),
      onTap: () => _open(profile),
      trailing: trailing ?? _buildRelationButton(profile),
    );
  }

  Widget _buildRelationButton(UserProfile profile) {
    switch (_friends.relationTo(profile.uid)) {
      case Relationship.self:
        return const SizedBox.shrink();
      case Relationship.friend:
        return FilledButton.tonalIcon(
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Chat'),
          onPressed: () async {
            await _history.add(profile);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserChatScreen(
                    userId: profile.uid, userName: profile.displayName),
              ),
            );
          },
        );
      case Relationship.requestSent:
        return OutlinedButton(
          onPressed: null,
          child: const Text('Requested'),
        );
      case Relationship.requestReceived:
        return FilledButton(
          onPressed: () =>
              _friends.accept(_friends.state.value.incomingFrom(profile.uid)!),
          child: const Text('Accept'),
        );
      case Relationship.none:
        return FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Add'),
          onPressed: () {
            _friends.sendRequest(profile);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Friend request sent to ${profile.displayName}'),
              behavior: SnackBarBehavior.floating,
            ));
          },
        );
    }
  }
}
