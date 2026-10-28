import 'package:flutter/material.dart';
import 'components/account_menu.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        automaticallyImplyLeading: false, // This removes the back button
        title: Text(
          'Menu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
          ),
        ),
        iconTheme:
            theme.appBarTheme.iconTheme ?? IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: const [
          ProfileHeader(),
          Divider(height: 1),
          AccountMenuItems(),
        ],
      ),
    );
  }
}
