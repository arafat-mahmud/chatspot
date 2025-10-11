import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/services/friend/friend_request_service.dart';
import 'package:chatspot/services/friend/friend_request_debug_service.dart';
import 'package:chatspot/services/friend/friend_notification_service.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/services/chat_initialization_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_main/image_handler.dart';

class FriendListScreen extends StatefulWidget {
  @override
  _FriendListScreenState createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _refreshData() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text(
          'Friends',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
          ),
        ),
        iconTheme:
            theme.appBarTheme.iconTheme ?? IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () async {
              await FriendRequestDebugService.printDebugInfo();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Debug info printed to console')),
              );
            },
            tooltip: 'Debug Friend Requests',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Friends'),
            StreamBuilder<int>(
              stream: FriendNotificationService.getPendingRequestCount(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Requests'),
                      if (pendingCount > 0) ...[
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          labelColor: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
          unselectedLabelColor: Colors.grey[300],
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      stream: FriendRequestService.getFriendsList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Friends list error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Error loading friends',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // This will rebuild the widget and retry the stream
                    });
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Search for users and send friend requests',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildFriendTile(friend);
          },
        );
      },
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    return ListTile(
      leading: GestureDetector(
        onTap: friend['profilePic']?.isNotEmpty == true
            ? () {
                ImageHandler.showFullScreenImage(context, friend['profilePic']);
              }
            : null,
        child: CircleAvatar(
          radius: 24,
          backgroundImage: friend['profilePic']?.isNotEmpty == true
              ? CachedNetworkImageProvider(friend['profilePic'])
              : null,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: friend['profilePic']?.isEmpty != false
              ? Text(
                  friend['name']?.isNotEmpty == true
                      ? friend['name'][0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : null,
        ),
      ),
      title: Text(friend['name'] ?? 'Unknown'),
      subtitle: Text(friend['username'] ?? ''),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'chat') {
            await _startChat(friend['userId'], friend['name']);
          } else if (value == 'remove') {
            await _removeFriend(friend);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'chat',
            child: Row(
              children: [
                Icon(Icons.chat),
                SizedBox(width: 8),
                Text('Chat'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove Friend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () async {
        await _startChat(friend['userId'], friend['name']);
      },
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      stream: FriendRequestService.getPendingFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Friend requests error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Error loading requests',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // This will rebuild the widget and retry the stream
                    });
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No friend requests',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestTile(request);
          },
        );
      },
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            GestureDetector(
              onTap: request['senderProfilePic']?.isNotEmpty == true
                  ? () {
                      ImageHandler.showFullScreenImage(
                          context, request['senderProfilePic']);
                    }
                  : null,
              child: CircleAvatar(
                radius: 24,
                backgroundImage: request['senderProfilePic']?.isNotEmpty == true
                    ? CachedNetworkImageProvider(request['senderProfilePic'])
                    : null,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                child: request['senderProfilePic']?.isEmpty != false
                    ? Text(
                        request['senderName']?.isNotEmpty == true
                            ? request['senderName'][0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request['senderName'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (request['senderUsername']?.isNotEmpty == true)
                    Text(
                      request['senderUsername'],
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    'wants to be your friend',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _acceptRequest(request);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(80, 32),
                  ),
                  child: Text('Accept'),
                ),
                SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () async {
                    await _rejectRequest(request);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: Size(80, 32),
                  ),
                  child: Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final success = await FriendRequestService.acceptFriendRequest(
      requestId: request['id'],
      senderId: request['senderId'],
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final success = await FriendRequestService.rejectFriendRequest(
      requestId: request['id'],
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request declined'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startChat(String userId, String name) async {
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

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Friend'),
        content: Text(
            'Are you sure you want to remove ${friend['name']} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (result == true) {
      final success =
          await FriendRequestService.removeFriend(friend['friendshipId']);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend removed'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove friend'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
