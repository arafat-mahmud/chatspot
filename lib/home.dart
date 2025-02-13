import 'package:flutter/material.dart';
import 'drawerbutton.dart'; // Import the CustomDrawer

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      drawer: CustomDrawer(), // Use the CustomDrawer widget
      body: Center(
        child: Text(
          'Welcome to the Home Page!',
          style: TextStyle(fontSize: 24.0),
        ),
      ),
    );
  }
}
