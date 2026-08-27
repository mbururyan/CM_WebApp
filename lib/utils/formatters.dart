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

  static String _two(int n) => n.toString().padLeft(2, '0');
}