import 'package:intl/intl.dart';

abstract final class SeoulDateTime {
  static const _offset = Duration(hours: 9);

  static DateTime fromEpochMilliseconds(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).add(_offset);
  }

  static String formatDateTime(int milliseconds) {
    return DateFormat(
      'M월 d일 a h:mm',
      'ko_KR',
    ).format(fromEpochMilliseconds(milliseconds));
  }

  static String formatTime(int milliseconds) {
    return DateFormat(
      'a h:mm',
      'ko_KR',
    ).format(fromEpochMilliseconds(milliseconds));
  }

  static int toEpochMilliseconds({
    required DateTime date,
    required TimeParts time,
  }) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour - 9,
      time.minute,
    ).millisecondsSinceEpoch;
  }
}

class TimeParts {
  const TimeParts({required this.hour, required this.minute});

  final int hour;
  final int minute;
}
