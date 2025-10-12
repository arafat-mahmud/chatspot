# Menu Cache Implementation

This document explains how caching is implemented in the Menu section of the app.

## Overview

The menu section previously made a Firestore query each time it was opened, causing the loading spinner to appear. With the new implementation, user data is cached after the first load, reducing unnecessary network requests and eliminating repeated loading indicators.

## Implementation Details

1. **UserCacheService**: A singleton class that handles caching user data
   - Located at `/lib/services/cache/user_cache_service.dart`
   - Uses in-memory caching with configurable expiry time (default: 30 minutes)

2. **Key Features**:
   - Automatic data retrieval from cache when available
   - Fallback to Firestore when cache is expired or not available
   - Manual cache update methods when data changes (e.g., profile picture updates)
   - Cache clearing on logout

3. **Cache Usage in Menu Page**:
   - The `MenuPage` widget uses the cache service instead of direct Firestore queries
   - Cache is updated when profile picture changes
   - Cache is cleared on logout

## Benefits

- Faster menu loading after initial load
- Reduced Firebase read operations
- Better user experience with fewer loading spinners
- Reduced data usage

## Future Improvements

- Add persistent cache storage using shared_preferences or hive
- Implement cache invalidation based on server-side changes
- Add automatic cache refresh in background
