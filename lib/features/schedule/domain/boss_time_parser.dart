abstract final class BossTimeParser {
  static Duration? parseRemaining(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'^\d+$').hasMatch(clean)) {
      var hours = 0;
      var minutes = 0;
      var seconds = 0;
      if (clean.length == 4) {
        minutes = int.parse(clean.substring(0, 2));
        seconds = int.parse(clean.substring(2));
      } else if (clean.length == 6) {
        hours = int.parse(clean.substring(0, 2));
        minutes = int.parse(clean.substring(2, 4));
        seconds = int.parse(clean.substring(4));
      } else {
        minutes = int.parse(clean);
      }
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }

    final compact = clean.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(
      r'^(?:(\d+)일)?(?:(\d+)시간)?(?:(\d+)분)?(?:(\d+)초)?$',
    ).firstMatch(compact);
    if (match == null) return null;
    final duration = Duration(
      days: int.tryParse(match.group(1) ?? '') ?? 0,
      hours: int.tryParse(match.group(2) ?? '') ?? 0,
      minutes: int.tryParse(match.group(3) ?? '') ?? 0,
      seconds: int.tryParse(match.group(4) ?? '') ?? 0,
    );
    return duration == Duration.zero ? null : duration;
  }

  static ({int hour, int minute, int second})? parseClock(String input) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$',
    ).firstMatch(input.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hour > 23 || minute > 59 || second > 59) return null;
    return (hour: hour, minute: minute, second: second);
  }
}
