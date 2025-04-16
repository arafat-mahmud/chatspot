import 'package:chatspot/views/chat/chat_main/chats_list/chat_list.dart'; // Correct import for ChatList
import 'package:chatspot/views/chat/call_screen.dart';
import 'package:flutter/material.dart';
import 'menu/main_drawer.dart';
import '../views/search_bar/main_search_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    ChatList(),
    CallScreen(),
  ];

  static const List<String> _titles = <String>[
    'Chatnook',
    'Chatnook',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56.0),
        child: AppBar(
          backgroundColor: theme.primaryColor,
          title: SizedBox(
            width: double.infinity,
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.search),
              color: theme.appBarTheme.actionsIconTheme?.color ?? Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchPage()),
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(
              height: 1.0,
              thickness: 1.0,
              color: theme.dividerColor,
            ),
          ),
          iconTheme: theme.appBarTheme.iconTheme ?? IconThemeData(color: Colors.white),
        ),
      ),
      drawer: CustomDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor ?? 
            const Color.fromARGB(255, 21, 138, 234),
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor ?? 
            Colors.grey,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ?? 
            theme.scaffoldBackgroundColor,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}