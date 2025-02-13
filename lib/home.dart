import 'package:flutter/material.dart';
import 'drawerbutton.dart'; // Import the CustomDrawer
import 'user_data/chats.dart'; // Import the ChatsPage
import 'user_data/calls.dart'; // Import the CallsPage

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    ChatsPage(),
    CallsPage(),
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
        onTap: _onItemTapped,
      ),
    );
  }
}
