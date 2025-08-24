import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatInitializationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Call this when user signs in to ensure all their existing chats
  /// have proper participant and user data structure
  static Future<void> initializeUserChats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final currentUserId = currentUser.uid;

      // Get current user data
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data()!;

      // Find all chats where this user is a participant
      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants.$currentUserId', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final chatDoc in chatsQuery.docs) {
        final chatData = chatDoc.data();
        final participants =
            chatData['participants'] as Map<String, dynamic>? ?? {};
        final users = chatData['users'] as Map<String, dynamic>? ?? {};

        // Ensure current user data is in the users map
        if (!users.containsKey(currentUserId)) {
          users[currentUserId] = {
            'name': currentUserData['name'] ?? 'Unknown',
            'username': currentUserData['username'] ?? '',
            'userId': currentUserId,
          };
        }

        // For each other participant, ensure their data is also in users map
        for (final participantId in participants.keys) {
          if (participantId != currentUserId &&
              !users.containsKey(participantId)) {
            try {
              final participantDoc =
                  await _firestore.collection('users').doc(participantId).get();

              if (participantDoc.exists) {
                final participantData = participantDoc.data()!;
                users[participantId] = {
                  'name': participantData['name'] ?? 'Unknown',
                  'username': participantData['username'] ?? '',
                  'userId': participantId,
                };
              }
            } catch (e) {
              print('Error fetching participant data for $participantId: $e');
            }
          }
        }

        // Update the chat document with the users data
        batch.update(chatDoc.reference, {'users': users});
      }

      await batch.commit();
      print(
          'Successfully initialized ${chatsQuery.docs.length} chats for user $currentUserId');
    } catch (e) {
      print('Error initializing user chats: $e');
    }
  }

  /// Call this to ensure a specific chat has proper participant structure
  static Future<void> ensureChatStructure({
    required String chatId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);

      // Get both users' data
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final otherUserDoc =
          await _firestore.collection('users').doc(otherUserId).get();

      if (!currentUserDoc.exists || !otherUserDoc.exists) return;

      final currentUserData = currentUserDoc.data()!;
      final otherUserData = otherUserDoc.data()!;

      await chatRef.set({
        'participants': {
          currentUserId: true,
          otherUserId: true,
        },
        'users': {
          currentUserId: {
            'name': currentUserData['name'] ?? 'Unknown',
            'username': currentUserData['username'] ?? '',
            'userId': currentUserId,
          },
          otherUserId: {
            'name': otherUserData['name'] ?? 'Unknown',
            'username': otherUserData['username'] ?? '',
            'userId': otherUserId,
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error ensuring chat structure: $e');
    }
  }
}
