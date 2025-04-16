import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_main/main_chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_history.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchHistory _searchHistory = SearchHistory();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _historyResults = [];
  bool _showHistory = true;
  bool _hasUsername = false;
  bool _isCheckingUsername = true;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _loadSearchHistory();
    _checkUsername();
  }

  Future<void> _checkUsername() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        setState(() {
          _hasUsername = userDoc.exists &&
              userDoc.data()?.containsKey('username') == true &&
              userDoc['username'] != null &&
              userDoc['username'].toString().isNotEmpty;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      print("Error checking username: $e");
      setState(() {
        _isCheckingUsername = false;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchHistory.getSearchHistory();
    setState(() {
      _historyResults = history;
    });
  }

  void _onSearchChanged(String query) async {
    if (_isCheckingUsername) {
      return; // Wait until username check is complete
    }

    if (query.isNotEmpty) {
      if (!_hasUsername) {
        _showUsernameAlert();
        setState(() {
          _results = [];
          _showHistory = true;
        });
        return;
      }

      setState(() {
        _showHistory = false;
      });

      try {
        final isUsernameSearch = query.startsWith('@');
        final usernameQuery = isUsernameSearch ? query : '@$query';
        final nameQuery = query.toLowerCase();

        if (isUsernameSearch) {
          final usernameDocs = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: usernameQuery)
              .get();

          setState(() {
            _results = usernameDocs.docs
                .map((doc) => {
                      "userId": doc.id,
                      "username": doc['username'],
                      "name": doc['name'],
                      "profilePictureUrl": doc['profilePictureUrl'] ?? '',
                    })
                .toList();
          });
        } else {
          final usernameDocs = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: usernameQuery)
              .get();

          final nameDocs =
              await FirebaseFirestore.instance.collection('users').get();

          final filteredNameDocs = nameDocs.docs.where((doc) {
            final name = doc['name']?.toString().toLowerCase() ?? '';
            return name.contains(nameQuery);
          }).toList();

          final allDocs = [...usernameDocs.docs, ...filteredNameDocs];
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
        }
      } catch (e) {
        print("Error searching for user: $e");
      }
    } else {
      setState(() {
        _results = [];
        _showHistory = true;
      });
    }
  }

  void _showUsernameAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Username Required!"),
        content: Text(
            "Please set your username in your profile before searching for other users"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _startChat(String userId, String name) async {
    if (!_hasUsername) {
      _showUsernameAlert();
      return;
    }

    await _searchHistory.addToSearchHistory(userId);
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

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

  Future<void> _removeFromHistory(String userId) async {
    await _searchHistory.removeFromSearchHistory(userId);
    await _loadSearchHistory();
  }

  Future<void> _clearAllHistory() async {
    await _searchHistory.clearSearchHistory();
    await _loadSearchHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Search history cleared')),
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
      body: _isCheckingUsername
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(0),
              child: _showHistory
                  ? _searchHistory.buildSearchHistoryList(
                      history: _historyResults,
                      onUserTap: _startChat,
                      onRemove: _removeFromHistory,
                      onClearAll: _clearAllHistory,
                      context: context,
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            child: _results[index]["profilePictureUrl"]
                                        ?.isNotEmpty ==
                                    true
                                ? CachedNetworkImage(
                                    imageUrl: _results[index]
                                        ["profilePictureUrl"],
                                    imageBuilder: (context, imageProvider) =>
                                        CircleAvatar(
                                      backgroundImage: imageProvider,
                                      radius: 24,
                                    ),
                                    placeholder: (context, url) => CircleAvatar(
                                      child: Text(_results[index]["name"][0]
                                          .toUpperCase()),
                                      radius: 24,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        CircleAvatar(
                                      child: Text(_results[index]["name"][0]
                                          .toUpperCase()),
                                      radius: 24,
                                    ),
                                  )
                                : CircleAvatar(
                                    child: Text(_results[index]["name"][0]
                                        .toUpperCase()),
                                    radius: 24,
                                  ),
                          ),
                          title: Text(_results[index]["name"]),
                          subtitle: Text(_results[index]["username"]),
                          onTap: () {
                            _startChat(_results[index]["userId"],
                                _results[index]["name"]);
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
