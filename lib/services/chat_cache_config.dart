class ChatCacheConfig {
  static const int maxCacheSize = 100; // Maximum number of chats to cache
  static const int userCacheSize = 500; // Maximum number of users to cache
  static const Duration cacheExpiry =
      Duration(minutes: 30); // Cache expiry time
  static const Duration retryDelay =
      Duration(seconds: 2); // Retry delay for failed operations
  static const int maxRetries = 3; // Maximum number of retries
}
