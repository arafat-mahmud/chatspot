import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

class FriendRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a friend request to another user
  static Future<bool> sendFriendRequest({
    required String receiverId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final currentUserId = currentUser.uid;
      if (currentUserId == receiverId) return false;

      // Check if users are already friends
      final existingFriendship = await _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUserId)
          .get();

      bool alreadyFriends = existingFriendship.docs.any((doc) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        return users.contains(receiverId) && doc.data()['status'] == 'accepted';
      });

      if (alreadyFriends) return false;

      // Check if there's already a pending request
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) return false;

      // Check if there's a reverse pending request
      final reverseRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reverseRequest.docs.isNotEmpty) return false;

      // Get sender data
      final senderDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (!senderDoc.exists) return false;

      final senderData = senderDoc.data()!;

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'senderName': senderData['name'] ?? 'Unknown',
        'senderUsername': senderData['username'] ?? '',
        'senderProfilePic': senderData['profilePictureUrl'] ?? '',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  /// Accept a friend request
  static Future<bool> acceptFriendRequest({
    required String requestId,
    required String senderId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final currentUserId = currentUser.uid;

      // Get both users' data
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();

      if (!currentUserDoc.exists || !senderDoc.exists) return false;

      final currentUserData = currentUserDoc.data()!;
      final senderData = senderDoc.data()!;

      final batch = _firestore.batch();

      // Update friend request status
      final requestRef =
          _firestore.collection('friend_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create friendship document
      final friendshipRef = _firestore.collection('friendships').doc();
      batch.set(friendshipRef, {
        'users': [currentUserId, senderId],
        'userDetails': {
          currentUserId: {
            'name': currentUserData['name'] ?? 'Unknown',
            'username': currentUserData['username'] ?? '',
            'profilePic': currentUserData['profilePictureUrl'] ?? '',
          },
          senderId: {
            'name': senderData['name'] ?? 'Unknown',
            'username': senderData['username'] ?? '',
            'profilePic': senderData['profilePictureUrl'] ?? '',
          },
        },
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject a friend request
  static Future<bool> rejectFriendRequest({
    required String requestId,
  }) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Get pending friend requests for current user
  static Stream<List<Map<String, dynamic>>> getPendingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Primary query attempt
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        List<Map<String, dynamic>> requests = [];

        for (var doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;

          // Enhance with fresh profile picture if missing or empty
          if (data['senderProfilePic'] == null ||
              data['senderProfilePic'] == '') {
            try {
              final senderDoc = await _firestore
                  .collection('users')
                  .doc(data['senderId'])
                  .get();

              if (senderDoc.exists) {
                final senderData = senderDoc.data()!;
                data['senderProfilePic'] =
                    senderData['profilePictureUrl'] ?? '';

                // Also update the name and username if they might have changed
                data['senderName'] =
                    senderData['name'] ?? data['senderName'] ?? 'Unknown';
                data['senderUsername'] =
                    senderData['username'] ?? data['senderUsername'] ?? '';
              }
            } catch (e) {
              print(
                  'Error fetching sender profile for ${data['senderId']}: $e');
            }
          }

          requests.add(data);
        }

        // Sort by timestamp if available, with null safety
        requests.sort((a, b) {
          final aTime = a['timestamp']?.toDate();
          final bTime = b['timestamp']?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime); // Most recent first
        });

        return requests;
      } catch (e) {
        print('Error processing friend requests: $e');
        return <Map<String, dynamic>>[];
      }
    }).handleError((error) {
      print('Error in getPendingFriendRequests stream: $error');
      // Return fallback stream that attempts a simpler query
      return _getFallbackPendingRequests(currentUser.uid);
    });
  }

  /// Fallback method for getting pending requests with simpler query
  static Stream<List<Map<String, dynamic>>> _getFallbackPendingRequests(
      String userId) {
    print('Using fallback method for friend requests');

    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        List<Map<String, dynamic>> requests = [];

        for (var doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            // Filter for pending status manually
            if (data['status'] == 'pending') {
              data['id'] = doc.id;

              // Enhance with fresh profile picture if missing or empty
              if (data['senderProfilePic'] == null ||
                  data['senderProfilePic'] == '') {
                try {
                  final senderDoc = await _firestore
                      .collection('users')
                      .doc(data['senderId'])
                      .get();

                  if (senderDoc.exists) {
                    final senderData = senderDoc.data()!;
                    data['senderProfilePic'] =
                        senderData['profilePictureUrl'] ?? '';

                    // Also update the name and username if they might have changed
                    data['senderName'] =
                        senderData['name'] ?? data['senderName'] ?? 'Unknown';
                    data['senderUsername'] =
                        senderData['username'] ?? data['senderUsername'] ?? '';
                  }
                } catch (e) {
                  print(
                      'Error fetching sender profile for ${data['senderId']}: $e');
                }
              }

              requests.add(data);
            }
          } catch (e) {
            print('Error processing document ${doc.id}: $e');
          }
        }

        return requests;
      } catch (e) {
        print('Error in fallback friend requests: $e');
        return <Map<String, dynamic>>[];
      }
    }).handleError((error) {
      print('Error in fallback stream: $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get friends list for current user
  static Stream<List<Map<String, dynamic>>> getFriendsList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUser.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        List<Map<String, dynamic>> friends = [];

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final users = List<String>.from(data['users'] ?? []);
            final userDetails =
                data['userDetails'] as Map<String, dynamic>? ?? {};

            // Find the other user (not current user)
            final otherUserId = users.firstWhere(
              (id) => id != currentUser.uid,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              Map<String, dynamic> friendData = {
                'userId': otherUserId,
                'friendshipId': doc.id,
              };

              // Try to get data from userDetails first
              if (userDetails.containsKey(otherUserId)) {
                final otherUserData =
                    userDetails[otherUserId] as Map<String, dynamic>;
                friendData['name'] = otherUserData['name'] ?? 'Unknown';
                friendData['username'] = otherUserData['username'] ?? '';
                friendData['profilePic'] = otherUserData['profilePic'] ?? '';
              }

              // If profile picture is missing or empty, fetch fresh data
              if (friendData['profilePic'] == null ||
                  friendData['profilePic'] == '') {
                try {
                  final userDoc = await _firestore
                      .collection('users')
                      .doc(otherUserId)
                      .get();

                  if (userDoc.exists) {
                    final userData = userDoc.data()!;
                    friendData['profilePic'] =
                        userData['profilePictureUrl'] ?? '';

                    // Also update name and username if not already set
                    if (friendData['name'] == 'Unknown' ||
                        friendData['name'] == '') {
                      friendData['name'] = userData['name'] ?? 'Unknown';
                    }
                    if (friendData['username'] == '') {
                      friendData['username'] = userData['username'] ?? '';
                    }
                  }
                } catch (e) {
                  print('Error fetching fresh user data for $otherUserId: $e');
                }
              }

              friends.add(friendData);
            }
          } catch (e) {
            print('Error processing friendship document ${doc.id}: $e');
            // Continue processing other documents
          }
        }

        // Sort friends alphabetically by name
        friends.sort((a, b) {
          final nameA = a['name'] as String? ?? 'Unknown';
          final nameB = b['name'] as String? ?? 'Unknown';
          return nameA.compareTo(nameB);
        });

        return friends;
      } catch (e) {
        print('Error processing friends list: $e');
        return <Map<String, dynamic>>[];
      }
    }).handleError((error) {
      print('Error in getFriendsList stream: $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Check if two users are friends
  static Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('friendships')
          .where('users', arrayContains: userId1)
          .where('status', isEqualTo: 'accepted')
          .get();

      return snapshot.docs.any((doc) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        return users.contains(userId2);
      });
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  /// Check if there's a pending friend request between users
  static Future<Map<String, dynamic>?> getPendingRequestBetweenUsers(
      String userId1, String userId2) async {
    try {
      // Check if userId1 sent request to userId2
      final request1 = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: userId1)
          .where('receiverId', isEqualTo: userId2)
          .where('status', isEqualTo: 'pending')
          .get();

      if (request1.docs.isNotEmpty) {
        final data = request1.docs.first.data();
        data['id'] = request1.docs.first.id;
        data['direction'] = 'sent';
        return data;
      }

      // Check if userId2 sent request to userId1
      final request2 = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
          .where('status', isEqualTo: 'pending')
          .get();

      if (request2.docs.isNotEmpty) {
        final data = request2.docs.first.data();
        data['id'] = request2.docs.first.id;
        data['direction'] = 'received';
        return data;
      }

      return null;
    } catch (e) {
      print('Error checking pending request: $e');
      return null;
    }
  }

  /// Remove friendship
  static Future<bool> removeFriend(String friendshipId) async {
    try {
      await _firestore.collection('friendships').doc(friendshipId).delete();
      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }
}
