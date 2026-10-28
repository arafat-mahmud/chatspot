import 'package:chatspot/services/chat/chat_models.dart';
import 'package:chatspot/services/chat/chat_repository.dart';
import 'package:chatspot/views/common/presence_widgets.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/search_bar/friend_aware_search_page.dart';
import 'package:flutter/material.dart';
import 'chat_list_item.dart';

/// The Chats tab. Rendered entirely from [ChatRepository]'s in-memory list,
/// which is kept live by a single listener for the whole session.
class FriendChatList extends StatefulWidget {
  const FriendChatList({super.key});

  @override
  State<FriendChatList> createState() => _FriendChatListState();
}

class _FriendChatListState extends State<FriendChatList> {
  final ChatRepository _repository = ChatRepository.instance;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _repository.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_repository.chats, _repository.loaded]),
      builder: (context, _) {
        final chats = _repository.chats.value;
        if (chats.isEmpty && !_repository.loaded.value) {
          return const ListSkeleton();
        }
        if (chats.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No chats yet',
            message: 'Message a friend, or find people to connect with.',
            actionLabel: 'Find people',
            onAction: () => _open(FriendAwareSearchPage()),
          );
        }
        return ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 4),
          // The first row is the strip of friends who are active now.
          itemCount: chats.length + 1,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox.shrink()
              : const Divider(height: 1, indent: 80),
          itemBuilder: (context, index) {
            if (index == 0) return const ActiveFriendsStrip();
            final ChatSummary chat = chats[index - 1];
            return ChatListItem(key: ValueKey(chat.chatId), chat: chat);
          },
        );
      },
    );
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
