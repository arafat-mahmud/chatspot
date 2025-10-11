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
}
