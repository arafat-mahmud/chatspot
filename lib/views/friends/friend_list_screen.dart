import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/services/friend/friend_request_service.dart';
import 'package:chatspot/services/friend/friend_notification_service.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/services/chat_initialization_service.dart';
import 'package:chatspot/views/no_back_button_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../chat/chat_main/image_handler.dart';

class FriendListScreen extends StatefulWidget {
  @override
  _FriendListScreenState createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;

  // Search functionality
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    // Listen for tab changes to mark requests as seen when the Requests tab is selected
    _tabController.addListener(_handleTabSelection);

    // If screen is opened directly to the Requests tab, mark all as seen
    if (_tabController.index == 1) {
      FriendNotificationService.markAllRequestsAsSeen();
    }

    // Add listener for search updates
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _handleTabSelection() {
    // When user views the Requests tab (index 1), mark all requests as seen
    if (_tabController.index == 1) {
      FriendNotificationService.markAllRequestsAsSeen();
    }
  }

  void _refreshData() {
    setState(() {
      _refreshKey++;
    });
  }

  String _formatRequestDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';

    try {
      DateTime date = timestamp.toDate();
      DateTime now = DateTime.now();
      Duration difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('MMM dd, yyyy').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: NoBackButtonAppBar(
        title: 'Friends',
        backgroundColor: theme.primaryColor,
        titleColor: theme.appBarTheme.titleTextStyle?.color ?? Colors.white,
        iconTheme:
            theme.appBarTheme.iconTheme ?? IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
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
                        Text(
                          '$pendingCount',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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

        final allFriends = snapshot.data ?? [];

        // Apply search filtering
        final List<Map<String, dynamic>> filteredFriends = _searchQuery.isEmpty
            ? allFriends
            : allFriends.where((friend) {
                final name = (friend['name'] ?? '').toLowerCase();
                final username = (friend['username'] ?? '').toLowerCase();
                return name.contains(_searchQuery) ||
                    username.contains(_searchQuery);
              }).toList();

        // Show empty state when there are no friends at all
        if (allFriends.isEmpty) {
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

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search friends by name or username...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                // Hide keyboard when clearing search
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                      contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                      child: Text(
                        'Found ${filteredFriends.length} friend${filteredFriends.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Show message when search has no results
            if (_searchQuery.isNotEmpty && filteredFriends.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No matching friends found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Friend list
            if (filteredFriends.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    return _buildFriendTile(friend);
                  },
                ),
              ),
          ],
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
                    _formatRequestDate(request['timestamp']),
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
