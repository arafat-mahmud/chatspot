import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatspot/services/chat_initialization_service.dart';
import 'package:chatspot/services/friend/friend_request_service.dart';
import '../chat/chat_main/main_chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_history.dart';
import '../chat/chat_main/image_handler.dart';

class FriendAwareSearchPage extends StatefulWidget {
  @override
  _FriendAwareSearchPageState createState() => _FriendAwareSearchPageState();
}

class _FriendAwareSearchPageState extends State<FriendAwareSearchPage> {
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

        if (mounted) {
          setState(() {
            _hasUsername = userDoc.exists &&
                userDoc.data()?.containsKey('username') == true &&
                userDoc['username'] != null &&
                userDoc['username'].toString().isNotEmpty;
            _isCheckingUsername = false;
          });
        }
      }
    } catch (e) {
      print("Error checking username: $e");
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchHistory.getSearchHistory();
    if (mounted) {
      setState(() {
        _historyResults = history;
      });
    }
  }

  void _onSearchChanged(String query) async {
    if (_isCheckingUsername) {
      return;
    }

    if (query.isNotEmpty) {
      if (!_hasUsername) {
        _showUsernameAlert();
        if (mounted) {
          setState(() {
            _results = [];
            _showHistory = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _showHistory = false;
        });
      }

      try {
        final currentUserId = FirebaseAuth.instance.currentUser!.uid;
        final isUsernameSearch = query.startsWith('@');

        if (isUsernameSearch) {
          final usernameQuery = query;
          final usernameSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: usernameQuery)
              .get();

          List<Map<String, dynamic>> results = [];

          for (var doc in usernameSnapshot.docs) {
            if (doc.id != currentUserId) {
              // Exclude current user
              final data = doc.data();

              // Check friendship status and pending requests
              final isFriend =
                  await FriendRequestService.areFriends(currentUserId, doc.id);
              final pendingRequest =
                  await FriendRequestService.getPendingRequestBetweenUsers(
                      currentUserId, doc.id);

              results.add({
                "userId": doc.id,
                "username": data['username'] ?? '',
                "name": data['name'] ?? '',
                "profilePictureUrl": data['profilePictureUrl'] ?? '',
                "isFriend": isFriend,
                "pendingRequest": pendingRequest,
              });
            }
          }

          if (mounted) {
            setState(() {
              _results = results;
            });
          }
        } else {
          final nameQuery = query.toLowerCase();
          final allUsers =
              await FirebaseFirestore.instance.collection('users').get();

          List<QueryDocumentSnapshot> matchingUsers = [];

          if (nameQuery.length == 1) {
            final char = nameQuery[0];

            matchingUsers = allUsers.docs.where((doc) {
              if (doc.id == currentUserId) return false; // Exclude current user
              final name = doc['name']?.toString().toLowerCase() ?? '';
              return name.isNotEmpty && name.split(' ')[0].startsWith(char);
            }).toList();

            matchingUsers.sort((a, b) => (a['name'] ?? '')
                .toLowerCase()
                .compareTo((b['name'] ?? '').toLowerCase()));
          } else {
            matchingUsers = allUsers.docs.where((doc) {
              if (doc.id == currentUserId) return false; // Exclude current user
              final name = doc['name']?.toString().toLowerCase() ?? '';
              return name.contains(nameQuery);
            }).toList();

            matchingUsers.sort((a, b) {
              final aName = a['name'].toString().toLowerCase();
              final bName = b['name'].toString().toLowerCase();

              if (aName == nameQuery) return -1;
              if (bName == nameQuery) return 1;

              final aStarts = aName.startsWith(nameQuery);
              final bStarts = bName.startsWith(nameQuery);
              if (aStarts && !bStarts) return -1;
              if (!aStarts && bStarts) return 1;

              final aLastWord = aName.split(' ').last;
              final bLastWord = bName.split(' ').last;
              final aLastMatch = aLastWord.startsWith(nameQuery);
              final bLastMatch = bLastWord.startsWith(nameQuery);
              if (aLastMatch && !bLastMatch) return -1;
              if (!aLastMatch && bLastMatch) return 1;

              return aName
                  .indexOf(nameQuery)
                  .compareTo(bName.indexOf(nameQuery));
            });
          }

          List<Map<String, dynamic>> results = [];

          for (var doc in matchingUsers) {
            final data = doc.data() as Map<String, dynamic>;

            // Check friendship status and pending requests
            final isFriend =
                await FriendRequestService.areFriends(currentUserId, doc.id);
            final pendingRequest =
                await FriendRequestService.getPendingRequestBetweenUsers(
                    currentUserId, doc.id);

            results.add({
              "userId": doc.id,
              "username": data['username'] ?? '',
              "name": data['name'] ?? '',
              "profilePictureUrl": data['profilePictureUrl'] ?? '',
              "isFriend": isFriend,
              "pendingRequest": pendingRequest,
            });
          }

          if (mounted) {
            setState(() {
              _results = results;
            });
          }
        }
      } catch (e) {
        print("Error searching for user: $e");
      }
    } else {
      if (mounted) {
        setState(() {
          _results = [];
          _showHistory = true;
        });
      }
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

  void _handleUserTap(Map<String, dynamic> user) async {
    if (!_hasUsername) {
      _showUsernameAlert();
      return;
    }

    final userId = user['userId'];
    final name = user['name'];
    final isFriend = user['isFriend'] ?? false;
    final pendingRequest = user['pendingRequest'];

    if (isFriend) {
      // They are friends, start chat directly
      await _startChat(userId, name);
    } else if (pendingRequest != null) {
      // There's a pending request
      if (pendingRequest['direction'] == 'sent') {
        _showRequestSentDialog(name);
      } else {
        _showIncomingRequestDialog(name);
      }
    } else {
      // Not friends and no pending request, show friend request dialog
      _showSendRequestDialog(user);
    }
  }

  void _showRequestSentDialog(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Request Sent"),
        content: Text(
            "You've already sent a friend request to $name. Please wait for them to respond."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showIncomingRequestDialog(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pending Request"),
        content: Text(
            "$name has sent you a friend request. Check your friend requests to accept or decline."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSendRequestDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Send Friend Request"),
        content: Text(
            "Send a friend request to ${user['name']}? You'll be able to chat once they accept."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendFriendRequest(user);
            },
            child: Text("Send Request"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
    final success = await FriendRequestService.sendFriendRequest(
      receiverId: user['userId'],
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${user['name']}!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the search results to update the button state
      _onSearchChanged(_searchController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startChat(String userId, String name) async {
    await _searchHistory.addToSearchHistory(userId);
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    List<String> ids = [currentUserId, userId];
    ids.sort();
    String chatId = ids.join("-");

    // Use the chat initialization service to ensure proper chat structure
    await ChatInitializationService.ensureChatStructure(
      chatId: chatId,
      currentUserId: currentUserId,
      otherUserId: userId,
    );

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

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isFriend = user['isFriend'] ?? false;
    final pendingRequest = user['pendingRequest'];

    String actionText = 'Add Friend';
    Color actionColor = Colors.blue;
    IconData actionIcon = Icons.person_add;

    if (isFriend) {
      actionText = 'Chat';
      actionColor = Colors.green;
      actionIcon = Icons.chat;
    } else if (pendingRequest != null) {
      if (pendingRequest['direction'] == 'sent') {
        actionText = 'Sent';
        actionColor = Colors.orange;
        actionIcon = Icons.schedule;
      } else {
        actionText = 'Respond';
        actionColor = Colors.purple;
        actionIcon = Icons.notification_important;
      }
    }

    return ListTile(
      leading: GestureDetector(
        onTap: user["profilePictureUrl"]?.isNotEmpty == true
            ? () {
                ImageHandler.showFullScreenImage(
                    context, user["profilePictureUrl"]);
              }
            : null,
        child: CircleAvatar(
          radius: 24,
          child: user["profilePictureUrl"]?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: user["profilePictureUrl"],
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    backgroundImage: imageProvider,
                    radius: 24,
                  ),
                  placeholder: (context, url) => CircleAvatar(
                    child: Text(user["name"][0].toUpperCase()),
                    radius: 24,
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    child: Text(user["name"][0].toUpperCase()),
                    radius: 24,
                  ),
                )
              : CircleAvatar(
                  child: Text(user["name"][0].toUpperCase()),
                  radius: 24,
                ),
        ),
      ),
      title: Text(user["name"]),
      subtitle: Text(user["username"]),
      trailing: Container(
        decoration: BoxDecoration(
          color: actionColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(actionIcon, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                actionText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      onTap: () => _handleUserTap(user),
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
                      onUserTap:
                          _startChat, // Only friends can be in history, so this is safe
                      onRemove: _removeFromHistory,
                      onClearAll: _clearAllHistory,
                      context: context,
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        return _buildUserTile(_results[index]);
                      },
                    ),
            ),
    );
  }
}
