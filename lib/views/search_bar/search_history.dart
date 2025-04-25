import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchHistory {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addToSearchHistory(String searchedUserId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final userRef = _firestore.collection('users').doc(currentUserId);

      // Get current history
      final userDoc = await userRef.get();
      List<dynamic> currentHistory = userDoc.data()?['searchHistory'] ?? [];

      // Remove if already exists (to avoid duplicates)
      currentHistory.remove(searchedUserId);

      // Add to beginning of list (most recent first)
      currentHistory.insert(0, searchedUserId);

      // Keep only the last 20 searches
      if (currentHistory.length > 20) {
        currentHistory = currentHistory.sublist(0, 20);
      }

      await userRef.update({'searchHistory': currentHistory});
      print('Successfully added $searchedUserId to search history');
    } catch (e) {
      print("Error adding to search history: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      print('Fetching search history for user: $currentUserId');

      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (!userDoc.exists) {
        print('User document does not exist');
        return [];
      }

      final userData = userDoc.data();
      if (userData == null || !userData.containsKey('searchHistory')) {
        print('No searchHistory field found in user document');
        return [];
      }

      final List<dynamic> historyIds = userData['searchHistory'];
      print('Found search history IDs: $historyIds');

      if (historyIds.isEmpty) {
        print('Search history is empty');
        return [];
      }

      // Fetch user details for each history item with error handling
      List<Map<String, dynamic>> historyUsers = [];
      for (var userId in historyIds) {
        try {
          if (userId == null || userId.toString().isEmpty) {
            print('Skipping empty user ID in history');
            continue;
          }

          print('Fetching user details for: $userId');
          final userDoc =
              await _firestore.collection('users').doc(userId.toString()).get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            historyUsers.add({
              "userId": userDoc.id,
              "username": userData['username'] ?? '',
              "name": userData['name'] ?? '',
              "profilePictureUrl": userData['profilePictureUrl'] ?? '',
            });
            print('Added user to history: ${userDoc.id}');
          } else {
            print('User document not found for ID: $userId');
          }
        } catch (e) {
          print("Error fetching user $userId: $e");
        }
      }

      print('Returning history users: ${historyUsers.length} items');
      return historyUsers;
    } catch (e) {
      print("Error getting search history: $e");
      rethrow;
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(currentUserId).update({
        'searchHistory': [],
      });
      print('Cleared search history');
    } catch (e) {
      print("Error clearing search history: $e");
      rethrow;
    }
  }

  Future<void> removeFromSearchHistory(String userId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(currentUserId).update({
        'searchHistory': FieldValue.arrayRemove([userId]),
      });
      print('Removed $userId from search history');
    } catch (e) {
      print("Error removing from search history: $e");
      rethrow;
    }
  }

  Widget buildSearchHistoryList({
    required List<Map<String, dynamic>> history,
    required Function(String, String) onUserTap,
    required Function(String) onRemove,
    required Function() onClearAll,
    required BuildContext context,
  }) {
    print('Building history list with ${history.length} items');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (history.isNotEmpty)
                TextButton(
                  onPressed: onClearAll,
                  child: Text('Clear all'),
                ),
            ],
          ),
        ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No recent searches',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
        ...history.map((user) {
          print('Displaying user in history: ${user['userId']}');
          return ListTile(
            leading: CircleAvatar(
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
            title: Text(user["name"]),
            subtitle: Text(user["username"]),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: () => onRemove(user["userId"]),
            ),
            onTap: () => onUserTap(user["userId"], user["name"]),
          );
        }),
      ],
    );
  }
}
