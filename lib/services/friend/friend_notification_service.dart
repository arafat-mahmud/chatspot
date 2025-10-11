import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get count of pending friend requests for current user
  static Stream<int> getPendingRequestCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.length;
      } catch (e) {
        print('Error counting friend requests: $e');
        return 0;
      }
    }).handleError((error) {
      print('Error in getPendingRequestCount stream: $error');
      return 0;
    });
  }

  /// Get count of unseen pending friend requests for current user
  /// Only counts requests that haven't been seen by the user
  static Stream<int> getUnseenRequestCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      try {
        // Count only requests that don't have 'seen: true'
        return snapshot.docs.where((doc) {
          final data = doc.data();
          return data['seen'] != true;
        }).length;
      } catch (e) {
        print('Error counting unseen friend requests: $e');
        return 0;
      }
    }).handleError((error) {
      print('Error in getUnseenRequestCount stream: $error');
      return 0;
    });
  }

  /// Get future count of pending friend requests for current user (for single check)
  static Future<int> getPendingRequestCountOnce() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return 0;
    }

    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting pending request count: $e');
      return 0;
    }
  }

  /// Mark all pending friend requests as seen
  /// This should be called when the user views the request list
  static Future<void> markAllRequestsAsSeen() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in snapshot.docs) {
        if (doc.data()['seen'] != true) {
          batch.update(doc.reference, {'seen': true});
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error marking requests as seen: $e');
    }
  }

  /// Mark a specific request as seen
  static Future<void> markRequestAsSeen(String requestId) async {
    try {
      await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .update({'seen': true});
    } catch (e) {
      print('Error marking request $requestId as seen: $e');
    }
  }
}
