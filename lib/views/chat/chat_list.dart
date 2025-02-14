import 'package:flutter/material.dart';

class ChatList extends StatefulWidget {
  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final List<String> chatItems = [
    'Chat with Alice',
    'Chat with Bob',
    'Chat with Charlie',
    'Chat with Dave',
  ];

  late List<String> filteredChatItems;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    filteredChatItems = chatItems;
    searchController.addListener(() {
      filterChats();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void filterChats() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredChatItems = chatItems
          .where((chat) => chat.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Unfocus when tapping outside
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                labelText: 'Search Friends',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredChatItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(filteredChatItems[index][0]),
                  ),
                  title: Text(filteredChatItems[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(chatName: filteredChatItems[index]),
                      ),
                    ).then((_) {
                      // Ensure the search bar is unfocused when returning
                      if (searchFocusNode.hasFocus) {
                        searchFocusNode.unfocus();
                      }
                      searchFocusNode.unfocus();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final String chatName;

  ChatScreen({required this.chatName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chatName),
      ),
      body: Center(
        child: Text(
          'Chat with $chatName',
          style: TextStyle(fontSize: 24.0),
        ),
      ),
    );
  }
}
