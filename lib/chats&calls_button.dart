import 'package:flutter/material.dart';
import 'drawer_button.dart'; // Import the CustomDrawer
import 'views/chat/chat_list.dart'; // Import the ChatsPage
import 'views/chat/call_screen.dart'; // Import the CallScreen
import 'views/search_bar/search_page.dart'; // Import the SearchPage

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    ChatsPage(), // This uses the updated ChatList
    CallScreen(),
  ];

  static const List<String> _titles = <String>[
    'Chatspot',
    'Chatspot',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56.0),
        child: AppBar(
          backgroundColor: Color.fromARGB(255, 50, 157, 244),
          title: SizedBox(
            width: double.infinity,
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.search), // Search icon
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SearchPage()), // Navigate to SearchPage
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(
              height: 1.0,
              thickness: 1.0,
              color: Colors.grey[300],
            ),
          ),
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
        selectedItemColor: const Color.fromARGB(255, 21, 138, 234),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensure fixed type
      ),
    );
  }
}
