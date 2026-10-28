import 'package:flutter/material.dart';
import 'components/account_menu.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            ProfileHeader(),
            Divider(height: 1),
            AccountMenuItems(),
          ],
        ),
      ),
    );
  }
}
