class DateFormatters {
  static String formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return "";
    return "${timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12)}:"
        "${timestamp.minute.toString().padLeft(2, '0')} "
        "${timestamp.hour >= 12 ? 'PM' : 'AM'}";
  }

  static String formatDate(DateTime? timestamp) {
    if (timestamp == null) return "";

    bool isFirstDayOfYear = timestamp.month == 1 && timestamp.day == 1;

    if (isFirstDayOfYear) {
      return "${_getMonth(timestamp.month)} ${timestamp.day}, ${timestamp.year}";
    } else {
      return "${_getMonth(timestamp.month)} ${timestamp.day}, "
          "${timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12)}:"
          "${timestamp.minute.toString().padLeft(2, '0')} "
          "${timestamp.hour >= 12 ? 'PM' : 'AM'}";
    }
  }

  static String formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Format as 12-hour time with AM/PM
      final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
      final period = timestamp.hour < 12 ? 'am' : 'pm';
      return '$hour:${timestamp.minute.toString().padLeft(2, '0')} $period';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      final difference = now.difference(timestamp);
      if (difference.inDays < 7) {
        // Within the past week, show day name
        return _getDayName(timestamp.weekday);
      } else if (timestamp.year == now.year) {
        // Same year, show month and day
        return '${timestamp.month}/${timestamp.day}';
      } else {
        // Different year, show full date
        return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
      }
    }
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  static String _getMonth(int month) {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }
}