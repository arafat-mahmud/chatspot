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