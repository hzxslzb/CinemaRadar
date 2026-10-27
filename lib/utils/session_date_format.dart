const _chineseWeekdays = <String>[
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

String formatSessionDate(String source, {bool short = false}) {
  final value = DateTime.tryParse(source);
  if (value == null) return source;
  final date = short
      ? '${value.month}月${value.day}日'
      : '${value.year}年${value.month}月${value.day}日';
  return '$date ${_chineseWeekdays[value.weekday - 1]}';
}
