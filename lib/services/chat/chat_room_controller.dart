import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'chat_models.dart';

/// Messages of one open chat, newest first.
///
/// Only the latest [pageSize] messages are live; older ones are fetched a
/// page at a time when the user scrolls up. Opening a chat therefore reads
/// at most one page (none when Firestore's on-device cache can resume the
/// listener), however long the conversation is.
class ChatRoomController extends ChangeNotifier {
  ChatRoomController(this.chatId, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const int pageSize = 30;

  final String chatId;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('chats').doc(chatId).collection('messages');

  List<ChatMessage> _live = const [];
  final List<ChatMessage> _older = [];
  DocumentSnapshot<Map<String, dynamic>>? _liveCursor;
  DocumentSnapshot<Map<String, dynamic>>? _olderCursor;
  StreamSubscription? _sub;
  bool _disposed = false;

  List<ChatMessage> messages = const [];
  bool loaded = false;
  bool loadingMore = false;
  bool hasMore = false;

  void start() {
    _sub = _messages
        .orderBy('timestamp', descending: true)
        .limit(pageSize)
        // Metadata changes flip "sending" to "sent"; they cost no reads.
        .snapshots(includeMetadataChanges: true)
        .listen(_onLive, onError: (Object e) {
      debugPrint('ChatRoomController: messages error: $e');
      loaded = true;
      _notify();
    });
  }

  void _onLive(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final docs = snapshot.docs;
    final live = docs.map(ChatMessage.fromDoc).toList();
    final full = docs.length >= pageSize;

    // A message leaving a full window was pushed out by a newer one, not
    // deleted: keep it at the top of the older messages.
    if (full) {
      final oldestLive = live.last.timestamp;
      final pushedOut = <(ChatMessage, DocumentSnapshot<Map<String, dynamic>>)>[];
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.removed) continue;
        final message = ChatMessage.fromDoc(change.doc);
        final time = message.timestamp;
        if (oldestLive != null && time != null && !time.isAfter(oldestLive)) {
          pushedOut.add((message, change.doc));
        }
      }
      if (pushedOut.isNotEmpty) {
        pushedOut.sort((a, b) => (b.$1.timestamp ?? DateTime(0))
            .compareTo(a.$1.timestamp ?? DateTime(0)));
        // Older pages continue below the oldest message we hold.
        if (_older.isEmpty) _olderCursor = pushedOut.last.$2;
        _older.insertAll(0, pushedOut.map((p) => p.$1));
      }
    }

    _live = live;
    _liveCursor = docs.isEmpty ? null : docs.last;
    if (!loaded) hasMore = full;
    loaded = true;
    _rebuild();
  }

  Future<void> loadMore() async {
    final cursor = _older.isEmpty ? _liveCursor : _olderCursor;
    if (loadingMore || !hasMore || cursor == null) return;
    loadingMore = true;
    _notify();
    try {
      final page = await _messages
          .orderBy('timestamp', descending: true)
          .startAfterDocument(cursor)
          .limit(pageSize)
          .get();
      final known = {for (final m in messages) m.id};
      _older.addAll(page.docs
          .map(ChatMessage.fromDoc)
          .where((message) => !known.contains(message.id)));
      if (page.docs.isNotEmpty) _olderCursor = page.docs.last;
      hasMore = page.docs.length >= pageSize;
      _rebuild();
    } catch (e) {
      debugPrint('ChatRoomController: loading older messages failed: $e');
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  void _rebuild() {
    final liveIds = {for (final m in _live) m.id};
    _older.removeWhere((message) => liveIds.contains(message.id));
    messages = [..._live, ..._older];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
