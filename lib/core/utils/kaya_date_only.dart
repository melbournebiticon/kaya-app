/// Immutable calendar date without time or timezone components.
///
/// Follows Section 5 Functional Rules:
/// - "Separate date-only values from timestamps."
/// - Prevents midnight timezone shifts when evaluating due dates.
class KayaDateOnly implements Comparable<KayaDateOnly> {
  const KayaDateOnly(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12, 'Month must be between 1 and 12'),
      assert(day >= 1 && day <= 31, 'Day must be between 1 and 31');

  final int year;
  final int month;
  final int day;

  /// Extracts the local calendar date (`year`, `month`, `day`) from a [DateTime].
  factory KayaDateOnly.fromDateTime(DateTime dateTime) {
    return KayaDateOnly(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Parses an ISO-8601 date-only string (`YYYY-MM-DD`).
  static KayaDateOnly? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final int? y = int.tryParse(match.group(1)!);
    final int? m = int.tryParse(match.group(2)!);
    final int? d = int.tryParse(match.group(3)!);
    if (y == null || m == null || d == null) {
      return null;
    }
    if (m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    // Verify calendar validity (e.g. rejects Feb 30).
    final DateTime check = DateTime.utc(y, m, d);
    if (check.year != y || check.month != m || check.day != d) {
      return null;
    }
    return KayaDateOnly(y, m, d);
  }

  DateTime toUtcDateTime() => DateTime.utc(year, month, day);

  DateTime toLocalDateTime() => DateTime(year, month, day);

  /// ISO day of week (`1 = Monday .. 7 = Sunday`).
  int get weekday => toUtcDateTime().weekday;

  KayaDateOnly addDays(int days) {
    final DateTime shifted = toUtcDateTime().add(Duration(days: days));
    return KayaDateOnly(shifted.year, shifted.month, shifted.day);
  }

  /// Adds [months] calendar months and clamps [day] to the last valid day of
  /// the target month (e.g., Jan 31 + 1 month -> Feb 28 or Feb 29).
  KayaDateOnly addMonths(int months) {
    final int zeroBasedMonth = (year * 12 + (month - 1)) + months;
    final int targetYear = (zeroBasedMonth / 12).floor();
    final int targetMonth = zeroBasedMonth - (targetYear * 12) + 1;
    final int maxDay = daysInMonth(targetYear, targetMonth);
    final int targetDay = day <= maxDay ? day : maxDay;
    return KayaDateOnly(targetYear, targetMonth, targetDay);
  }

  /// Adds [years] calendar years with leap-day clamping (Feb 29 -> Feb 28).
  KayaDateOnly addYears(int years) => addMonths(years * 12);

  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  static int daysInMonth(int year, int month) {
    if (month == 2) {
      return isLeapYear(year) ? 29 : 28;
    }
    if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    }
    return 31;
  }

  /// Signed difference in whole calendar days (`this - other`).
  int daysDifferenceFrom(KayaDateOnly other) {
    return toUtcDateTime().difference(other.toUtcDateTime()).inDays;
  }

  bool isBefore(KayaDateOnly other) => compareTo(other) < 0;

  bool isAfter(KayaDateOnly other) => compareTo(other) > 0;

  bool isSameDay(KayaDateOnly other) => compareTo(other) == 0;

  /// Formats as `YYYY-MM-DD`.
  String toIsoDateString() {
    final String y = year.toString().padLeft(4, '0');
    final String m = month.toString().padLeft(2, '0');
    final String d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Human-readable short date (e.g. `Nov 14, 2026`).
  String formatReadable() {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, $year';
  }

  @override
  int compareTo(KayaDateOnly other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is KayaDateOnly &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoDateString();
}
