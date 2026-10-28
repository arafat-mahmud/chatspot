import 'package:chatspot/services/chat/chat_repository.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/views/chat/chat_main/chats_list/friend_chat_list.dart';
import 'package:chatspot/views/call/call_history_screen.dart';
import 'package:flutter/material.dart';
import 'menu/main_drawer.dart';
import 'menu/menu_page.dart';
import '../views/search_bar/friend_aware_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  /// Tabs are built on first visit (the Calls tab's listener doesn't start
  /// until it's opened) and then kept alive, so switching never reloads.
  final Set<int> _visited = {0};

  static const List<Widget> _pages = <Widget>[
    FriendChatList(),
    CallHistoryScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MenuPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
        _visited.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBar = theme.appBarTheme.titleTextStyle?.color ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        automaticallyImplyLeading: false,
        title: Text(
          'Chatnook',
          style: TextStyle(fontWeight: FontWeight.bold, color: onBar),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find people',
            color: theme.appBarTheme.actionsIconTheme?.color ?? onBar,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FriendAwareSearchPage()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1.0, thickness: 1.0, color: theme.dividerColor),
        ),
        iconTheme: theme.appBarTheme.iconTheme ??
            const IconThemeData(color: Colors.white),
      ),
      drawer: CustomDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            _visited.contains(i) ? _pages[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: ChatRepository.instance.unreadTotal,
              builder: (context, unread, child) => Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: child,
              ),
              child: const Icon(Icons.chat),
            ),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<FriendsState>(
              valueListenable: FriendRepository.instance.state,
              builder: (context, friends, child) => Badge(
                isLabelVisible: friends.unseenCount > 0,
                label: Text('${friends.unseenCount}'),
                child: child,
              ),
              child: const Icon(Icons.menu),
            ),
            label: 'Menu',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor ??
            const Color.fromARGB(255, 21, 138, 234),
        unselectedItemColor:
            theme.bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ??
            theme.scaffoldBackgroundColor,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
