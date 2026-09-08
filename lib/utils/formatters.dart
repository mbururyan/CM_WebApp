/// Small display helpers shared across screens. No Flutter imports — these
/// are pure string functions so they can be reused by the Excel export later.
class Fmt {
  Fmt._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// 04 Aug 2026
  static String date(DateTime? d) {
    if (d == null) return '—';
    return '${_two(d.day)} ${_months[d.month - 1]} ${d.year}';
  }

  /// 04 Aug — for tight columns where the year is obvious from context.
  static String shortDate(DateTime? d) {
    if (d == null) return '—';
    return '${_two(d.day)} ${_months[d.month - 1]}';
  }

  /// 12,480
  static String thousands(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// "3 days ago", "Today", "41 days ago"
  static String relative(DateTime? d, {DateTime? now}) {
    if (d == null) return 'Never';
    final n = now ?? DateTime.now();
    final days = DateTime(n.year, n.month, n.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    if (days < 365) return '${(days / 30).floor()} months ago';
    return Fmt.date(d);
  }

  /// snake_case answer ids and enum values into readable text:
  /// `feed_plan` -> `Feed plan`, `semi_intensive` -> `Semi intensive`.
  static String humanise(String raw) {
    if (raw.isEmpty) return '—';
    final words = raw.replaceAll('_', ' ').trim();
    return words[0].toUpperCase() + words.substring(1);
  }

  // ---- weeks -------------------------------------------------------
  //
  // The office works in week numbers, and the 2026 company calendar runs
  // Mon-Sat with no Sunday column. Its numbering is plain ISO 8601 — all
  // 310 rows of the calendar match the arithmetic below exactly — so the
  // weeks are computed rather than tabulated. A shipped table would only
  // be a copy of this that goes stale every January.

  /// The Monday that starts the ISO week containing [d].
  ///
  /// A Sunday therefore belongs to the week that began SIX days earlier,
  /// not the one starting the next day. That is what keeps a visit
  /// written up on a Sunday inside the weekly figures — the calendar has
  /// no Sunday, but the data does, and dropping those would leave the
  /// visit count and the weekly chart disagreeing with each other.
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// ISO 8601 week number.
  ///
  /// The Thursday of a week decides which year and which week the whole
  /// week belongs to, which is why a week straddling New Year is not
  /// split in two.
  static int isoWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final dayOfYear =
        thursday.difference(DateTime(thursday.year, 1, 1)).inDays + 1;
    return (dayOfYear - 1) ~/ 7 + 1;
  }

  /// The year that owns this week, which is not always the calendar year
  /// \u2014 31 Dec 2026 is week 53 of 2026, and so is 1 Jan 2027.
  static int isoWeekYear(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.add(Duration(days: 4 - day.weekday)).year;
  }

  /// Wk 32
  static String weekLabel(DateTime d) => 'Wk ${isoWeek(d)}';

  /// 05–10 Jan — the working days of that week.
  ///
  /// Mon to Sat, five days on from the Monday, because that is the week
  /// the office recognises. Sunday data is still counted in the week; it
  /// is just not named in the label.
  static String weekDays(DateTime start) {
    final monday = weekStart(start);
    final saturday = monday.add(const Duration(days: 5));
    final left = monday.month == saturday.month
        ? _two(monday.day)
        : '${_two(monday.day)} ${_months[monday.month - 1]}';
    return '$left\u2013${_two(saturday.day)} '
        '${_months[saturday.month - 1]}';
  }

  /// Week 32 · 03–08 Aug
  static String weekRange(DateTime start) =>
      'Week ${isoWeek(start)} \u00B7 ${weekDays(start)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}