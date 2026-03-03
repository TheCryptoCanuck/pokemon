/// Format a [DateTime] as 'YYYY-MM-DD' for reliable date key comparison.
String formatDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
