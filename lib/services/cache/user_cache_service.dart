import 'package:cloud_firestore/cloud_firestore.dart';

class UserCacheService {
  // Singleton instance
  static final UserCacheService _instance = UserCacheService._internal();

  // Factory constructor
  factory UserCacheService() => _instance;

  // Internal constructor
  UserCacheService._internal();

  // Cache storage
  Map<String, Map<String, dynamic>> _userDataCache = {};
  Map<String, DateTime> _cacheTimestamp = {};

  // Cache expiry duration (optional - set to 30 minutes)
  Duration _cacheExpiry = Duration(minutes: 30);

  // Get user data from cache or Firestore
  Future<Map<String, dynamic>> getUserData(String userId) async {
    // Check if we have valid cached data
    if (_userDataCache.containsKey(userId)) {
      final timestamp = _cacheTimestamp[userId];
      final now = DateTime.now();

      // If cache is still valid
      if (timestamp != null && now.difference(timestamp) < _cacheExpiry) {
        return _userDataCache[userId]!;
      }
    }

    // No valid cache, fetch from Firestore
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (docSnapshot.exists) {
      final userData = docSnapshot.data() as Map<String, dynamic>;

      // Update cache
      _userDataCache[userId] = userData;
      _cacheTimestamp[userId] = DateTime.now();

      return userData;
    }

    // Return empty data if user not found
    return {};
  }

  // Manually update cache (useful when profile picture is updated)
  void updateUserCache(String userId, Map<String, dynamic> userData) {
    _userDataCache[userId] = userData;
    _cacheTimestamp[userId] = DateTime.now();
  }

  // Clear cache for a specific user
  void clearCache(String userId) {
    _userDataCache.remove(userId);
    _cacheTimestamp.remove(userId);
  }

  // Clear all cache
  void clearAllCache() {
    _userDataCache.clear();
    _cacheTimestamp.clear();
  }
}
