import 'package:flutter/material.dart';
import 'drawer_button.dart'; // Import the CustomDrawer
import 'views/chat/chat_screen.dart'; // Import the ChatsPage
import 'views/chat/call_screen.dart'; // Import the CallScreen instead of CallsPage

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    ChatsPage(),
    CallScreen(),
  ];

  static const List<String> _titles = <String>[
    'Chatspot',
    'Calls',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make the title bold
          ),
        ),
      ),
      drawer: CustomDrawer(), // Use the CustomDrawer widget
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
        unselectedItemColor: Colors.grey, // Set unselected item color
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensure fixed type
      ),
    );
  }
}
