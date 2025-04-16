// search_history.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchHistory {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a search to user's history
  Future<void> addToSearchHistory(String searchedUserId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final userRef = _firestore.collection('users').doc(currentUserId);
      
      await userRef.update({
        'searchHistory': FieldValue.arrayUnion([searchedUserId])
      });
    } catch (e) {
      print("Error adding to search history: $e");
    }
  }

  // Get user's search history
  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      
      if (userDoc.exists && userDoc.data()?.containsKey('searchHistory') == true) {
        final List<dynamic> historyIds = userDoc['searchHistory'];
        // Remove duplicates while preserving order
        final uniqueIds = historyIds.toSet().toList();
        
        // Fetch user details for each history item
        List<Map<String, dynamic>> historyUsers = [];
        for (var userId in uniqueIds) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            historyUsers.add({
              "userId": userDoc.id,
              "username": userDoc['username'],
              "name": userDoc['name'],
              "profilePictureUrl": userDoc['profilePictureUrl'] ?? '',
            });
          }
        }
        return historyUsers;
      }
      return [];
    } catch (e) {
      print("Error getting search history: $e");
      return [];
    }
  }

  // Clear all search history
  Future<void> clearSearchHistory() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(currentUserId).update({
        'searchHistory': FieldValue.delete(),
      });
    } catch (e) {
      print("Error clearing search history: $e");
    }
  }

  // Remove a single item from search history
  Future<void> removeFromSearchHistory(String userId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(currentUserId).update({
        'searchHistory': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print("Error removing from search history: $e");
    }
  }

  // Widget to display search history
  Widget buildSearchHistoryList({
    required List<Map<String, dynamic>> history,
    required Function(String, String) onUserTap,
    required Function(String) onRemove,
    required BuildContext context,
  }) {
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
                  onPressed: () async {
                    await clearSearchHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Search history cleared')),
                    );
                  },
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
        ...history.map((user) => ListTile(
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
            )),
      ],
    );
  }
}