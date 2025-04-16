import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_main/main_chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.isNotEmpty) {
      try {
        final usernameQuery = query.startsWith('@') ? query : '@$query';
        final nameQuery = query;

        // Search for username match
        final usernameDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: usernameQuery)
            .get();

        // Search for name match (case insensitive)
        final nameDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: nameQuery)
            .where('name', isLessThan: nameQuery + 'z')
            .get();

        // Combine results and remove duplicates
        final allDocs = [...usernameDocs.docs, ...nameDocs.docs];
        final uniqueDocs = allDocs
            .fold<Map<String, DocumentSnapshot>>({}, (map, doc) {
              map[doc.id] = doc;
              return map;
            })
            .values
            .toList();

        setState(() {
          _results = uniqueDocs
              .map((doc) => {
                    "userId": doc.id,
                    "username": doc['username'],
                    "name": doc['name'],
                    "profilePictureUrl": doc['profilePictureUrl'] ?? '',
                  })
              .toList();
        });
      } catch (e) {
        print("Error searching for user: $e");
      }
    } else {
      setState(() {
        _results = [];
      });
    }
  }

  void _startChat(String userId, String name) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Get current user data
    DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    List<String> ids = [currentUserId, userId];
    ids.sort();
    String chatId = ids.join("-");

    DocumentReference chatRef =
        FirebaseFirestore.instance.collection('chats').doc(chatId);

    await chatRef.set({
      'participants': {
        currentUserId: true,
        userId: true,
      },
      'users': {
        currentUserId: {
          'username': currentUserDoc['username'],
          'name': currentUserDoc['name'],
          'userId': currentUserId,
        },
        userId: {
          'username': _results
              .firstWhere((user) => user['userId'] == userId)['username'],
          'name': name,
          'userId': userId,
        },
      },
    }, SetOptions(merge: true));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserChatScreen(userId: userId, userName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: ListView.builder(
          itemCount: _results.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                child: _results[index]["profilePictureUrl"]?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: _results[index]["profilePictureUrl"],
                        imageBuilder: (context, imageProvider) => CircleAvatar(
                          backgroundImage: imageProvider,
                          radius: 24,
                        ),
                        placeholder: (context, url) => CircleAvatar(
                          child: Text(_results[index]["name"][0].toUpperCase()),
                          radius: 24,
                        ),
                        errorWidget: (context, url, error) => CircleAvatar(
                          child: Text(_results[index]["name"][0].toUpperCase()),
                          radius: 24,
                        ),
                      )
                    : CircleAvatar(
                        child: Text(_results[index]["name"][0].toUpperCase()),
                        radius: 24,
                      ),
              ),
              title: Text(_results[index]["name"]),
              subtitle: Text(_results[index]["username"]),
              onTap: () {
                _startChat(_results[index]["userId"], _results[index]["name"]);
              },
            );
          },
        ),
      ),
    );
  }
}
