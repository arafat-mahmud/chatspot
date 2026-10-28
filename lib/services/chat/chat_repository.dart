import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_messenger.dart';
import '../friend/friend_repository.dart';
import '../user/user_repository.dart';
import 'chat_models.dart';

/// The chat list and every write that changes it.
///
/// * One listener, newest chats first and limited to [_pageSize] (more on
///   demand), replaces the old unbounded query that also read the whole
///   friends list once per chat.
/// * Names and photos come from the friends list, which is already in
///   memory, so building the list costs no extra reads.
/// * Unread counts and read receipts live on the chat document itself
///   (`unread.{uid}`, `lastRead.{uid}`): sending a message updates them in the
///   same write, and opening a chat is one small update instead of one write
///   per message.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  static const int _pageSize = 50;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  /// Chats with friends, newest first.
  final ValueNotifier<List<ChatSummary>> chats = ValueNotifier(const []);

  /// The first page has arrived (from the device cache or the server).
  final ValueNotifier<bool> loaded = ValueNotifier(false);

  /// Sum of unread messages, for the tab badge.
  final ValueNotifier<int> unreadTotal = ValueNotifier(0);

  String? _uid;
  StreamSubscription? _sub;
  List<ChatSummary> _all = const [];
  int _limit = _pageSize;
  bool _hasMore = false;
  bool _legacyQuery = false;
  final Set<String> _markingRead = {};

  bool get hasMore => _hasMore;

  /// Every chat in the current window, friends or not (profile fan-out).
  List<ChatSummary> get allChats => _all;

  void start(String uid) {
    _uid = uid;
    _limit = _pageSize;
    _legacyQuery = false;
    FriendRepository.instance.state.addListener(_publish);
    _listen();
    _migrateLegacyChats(uid);
  }

  Future<void> stop() async {
    _uid = null;
    FriendRepository.instance.state.removeListener(_publish);
    await _sub?.cancel();
    _sub = null;
    _all = const [];
    _markingRead.clear();
    chats.value = const [];
    loaded.value = false;
    unreadTotal.value = 0;
  }

  void loadMore() {
    if (!_hasMore || _legacyQuery) return;
    _limit += _pageSize;
    _listen();
  }

  ChatSummary? summary(String chatId) {
    for (final chat in _all) {
      if (chat.chatId == chatId) return chat;
    }
    return null;
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    _sub?.cancel();
    final Query<Map<String, dynamic>> query = _legacyQuery
        // Before the participantIds index is deployed: unordered, unbounded.
        ? _chats.where('participants.$uid', isEqualTo: true)
        : _chats
            .where('participantIds', arrayContains: uid)
            .orderBy('lastMessageTime', descending: true)
            .limit(_limit);

    _sub = query.snapshots().listen((snapshot) {
      _all = snapshot.docs
          .map((doc) => ChatSummary.fromDoc(doc, uid))
          .whereType<ChatSummary>()
          .toList();
      _hasMore = !_legacyQuery && snapshot.docs.length >= _limit;
      loaded.value = true;
      _publish();
    }, onError: (Object e) {
      if (!_legacyQuery &&
          e is FirebaseException &&
          e.code == 'failed-precondition') {
        debugPrint('ChatRepository: chat index missing, using the legacy '
            'query. Deploy firestore.indexes.json. ${e.message}');
        _legacyQuery = true;
        _listen();
        return;
      }
      debugPrint('ChatRepository: chat list error: $e');
      loaded.value = true;
    });
  }

  void _publish() {
    final friends = FriendRepository.instance.state.value;
    // Wait for the friends list so non-friend chats never flash in.
    if (!friends.loaded) return;

    final visible = <ChatSummary>[];
    var unread = 0;
    for (final chat in _all) {
      final friend = friends.friend(chat.peerId);
      if (friend == null) continue;
      visible.add(chat.copyWith(
        peerName: friend.displayName,
        peerPhotoUrl:
            friend.photoUrl.isNotEmpty ? friend.photoUrl : chat.peerPhotoUrl,
      ));
      unread += chat.unreadCount;
    }
    visible.sort((a, b) => (b.lastMessageTime ?? DateTime.now())
        .compareTo(a.lastMessageTime ?? DateTime.now()));
    chats.value = visible;
    unreadTotal.value = unread;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Sends a text message. Returns false (and writes nothing) when the peer
  /// isn't a friend. Never waits for the server: the message shows up at
  /// once and is delivered when the network allows.
  Future<bool> sendText(String peerId, String text) =>
      _send(peerId, {'text': text, 'isImage': false}, preview: text);

  Future<bool> sendImage(String peerId, String imageUrl) => _send(
        peerId,
        {'text': '', 'imageUrl': imageUrl, 'isImage': true},
        preview: '[Photo]',
      );

  Future<bool> _send(
    String peerId,
    Map<String, dynamic> content, {
    required String preview,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    if (!await FriendRepository.instance.isFriendConfirmed(peerId)) {
      return false;
    }

    final me = UserRepository.instance.me.value;
    final peer = FriendRepository.instance.state.value.friend(peerId);
    final chatRef = _chats.doc(chatIdFor(uid, peerId));
    final batch = _db.batch()
      ..set(chatRef.collection('messages').doc(), {
        ...content,
        'senderId': uid,
        'receiverId': peerId,
        'timestamp': FieldValue.serverTimestamp(),
      })
      ..set(
        chatRef,
        {
          'participants': {uid: true, peerId: true},
          'participantIds': ([uid, peerId]..sort()),
          'users': {
            uid: {
              'name': me?.name ?? '',
              'username': me?.username ?? '',
              'photoUrl': me?.photoUrl ?? '',
            },
            peerId: {
              'name': peer?.name ?? '',
              'username': peer?.username ?? '',
              'photoUrl': peer?.photoUrl ?? '',
            },
          },
          'lastMessage': preview,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': uid,
          'unread': {peerId: FieldValue.increment(1), uid: 0},
          // Replying means we've read everything before it.
          'lastRead': {uid: FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
    batch.commit().catchError((Object e) {
      debugPrint('ChatRepository: sending failed: $e');
      AppMessenger.error("Message couldn't be sent");
    });
    return true;
  }

  /// Marks a chat read for the signed-in user. Writes only when something
  /// is actually unread, so calling it on every new message is cheap.
  void markRead(String chatId) {
    final uid = _uid;
    final chat = summary(chatId);
    if (uid == null || chat == null || !chat.hasUnread) return;
    if (!_markingRead.add(chatId)) return;
    _chats.doc(chatId).update({
      'unread.$uid': 0,
      'lastRead.$uid': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('ChatRepository: marking $chatId read failed: $e');
    }).whenComplete(() => _markingRead.remove(chatId));
  }

  /// Chats created before `participantIds` existed are invisible to the
  /// ordered query. Fix them once per account and device; later runs find
  /// nothing to update.
  Future<void> _migrateLegacyChats(String uid) async {
    final flag = 'chats_participant_ids_v1_$uid';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(flag) == true) return;
      final legacy =
          await _chats.where('participants.$uid', isEqualTo: true).get();
      final batch = _db.batch();
      var updates = 0;
      for (final doc in legacy.docs) {
        final data = doc.data();
        if (data['participantIds'] is List) continue;
        final ids = ((data['participants'] as Map?)?.keys ?? const [])
            .map((id) => '$id')
            .toList()
          ..sort();
        if (ids.length != 2) continue;
        batch.update(doc.reference, {'participantIds': ids});
        if (++updates == 450) break;
      }
      if (updates > 0) await batch.commit();
      if (updates < 450) await prefs.setBool(flag, true);
    } catch (e) {
      debugPrint('ChatRepository: migrating chats failed: $e');
    }
  }
}
