import 'package:flutter/material.dart';
import 'chat_list.dart';

class ChatsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Chats'),
      // ),
      body: ChatList(),
    );
  }
}
