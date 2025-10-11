import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendRequestDebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Debug function to test Firestore connectivity and permissions
  static Future<Map<String, dynamic>> debugFriendRequestsAccess() async {
    final result = <String, dynamic>{};

    try {
      final currentUser = _auth.currentUser;
      result['currentUser'] = currentUser?.uid ?? 'null';

      if (currentUser == null) {
        result['error'] = 'No authenticated user';
        return result;
      }

      // Test basic collection access
      try {
        final testQuery =
            await _firestore.collection('friend_requests').limit(1).get();
        result['collectionAccess'] = 'success';
        result['testQueryResults'] = testQuery.docs.length;
      } catch (e) {
        result['collectionAccess'] = 'failed';
        result['collectionError'] = e.toString();
      }

      // Test specific user query
      try {
        final userQuery = await _firestore
            .collection('friend_requests')
            .where('receiverId', isEqualTo: currentUser.uid)
            .limit(5)
            .get();
        result['userQueryAccess'] = 'success';
        result['userQueryResults'] = userQuery.docs.length;

        // Get sample data
        if (userQuery.docs.isNotEmpty) {
          result['sampleData'] = userQuery.docs.first.data();
        }
      } catch (e) {
        result['userQueryAccess'] = 'failed';
        result['userQueryError'] = e.toString();
      }

      // Test user document access
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        result['userDocAccess'] = 'success';
        result['userExists'] = userDoc.exists;
        if (userDoc.exists) {
          final userData = userDoc.data();
          result['userName'] = userData?['name'];
          result['userEmail'] = userData?['email'];
        }
      } catch (e) {
        result['userDocAccess'] = 'failed';
        result['userDocError'] = e.toString();
      }
    } catch (e) {
      result['generalError'] = e.toString();
    }

    return result;
  }

  /// Simple test to create a friend request (for debugging)
  static Future<Map<String, dynamic>> debugCreateTestRequest(
      String receiverId) async {
    final result = <String, dynamic>{};

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        result['error'] = 'No authenticated user';
        return result;
      }

      // Get current user data
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        result['error'] = 'Current user document not found';
        return result;
      }

      final userData = userDoc.data()!;

      // Try to create a test request
      final requestData = {
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'senderName': userData['name'] ?? 'Test User',
        'senderUsername': userData['username'] ?? '@testuser',
        'senderProfilePic': userData['profilePictureUrl'] ?? '',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef =
          await _firestore.collection('friend_requests').add(requestData);

      result['success'] = true;
      result['requestId'] = docRef.id;
      result['requestData'] = requestData;
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  /// Print debug information to console
  static Future<void> printDebugInfo() async {
    print('=== FRIEND REQUEST DEBUG INFO ===');
    final debugInfo = await debugFriendRequestsAccess();
    debugInfo.forEach((key, value) {
      print('$key: $value');
    });
    print('================================');
  }
}
