// lib/features/expenses/expense_format.dart

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// Inserts thousands separators into a plain digit string.
/// "1234567" -> "1,234,567"
String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 12345 -> "KSh 12,345"
/// -1234 -> "KSh -1,234"
/// 0     -> "KSh 0"
String formatKsh(num amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  return 'KSh $sign${_groupDigits(rounded.abs().toString())}';
}

/// 12345 -> "KSh 12,345"
/// 1234567 -> "KSh 1.2M"
/// 15000 -> "KSh 15.0K"
String formatShortKsh(num amount) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    return 'KSh ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 10000) {
    return 'KSh ${(amount / 1000).toStringAsFixed(1)}K';
  }
  return formatKsh(amount);
}

/// 1234.5 kg  ·  500 units  ·  0 kg  ·  1250 bag
String formatQuantity(double qty, String unit) {
  final isWhole = qty == qty.roundToDouble();
  final text = isWhole ? qty.toStringAsFixed(0) : qty.toStringAsFixed(1);

  final negative = text.startsWith('-');
  final unsigned = negative ? text.substring(1) : text;
  final parts = unsigned.split('.');

  final grouped = _groupDigits(parts[0]);
  final number = parts.length == 2 ? '$grouped.${parts[1]}' : grouped;

  return '${negative ? '-' : ''}$number $unit';
}

/// 12 Aug 2025
String fullDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Aug
String monthShort(DateTime d) => _months[d.month - 1];

/// Today / Yesterday / Tomorrow / Mon, 12 Aug (year appended when not current year)
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final diff = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(d.year, d.month, d.day))
      .inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';

  final base = '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}