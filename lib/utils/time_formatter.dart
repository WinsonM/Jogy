/// 智能时间格式化工具
/// 根据时间差距自动选择合适的显示格式
class TimeFormatter {
  /// 将 DateTime 转换为智能时间显示字符串
  ///
  /// 规则:
  /// - < 10分钟: "N分钟前"
  /// - < 8小时: "N小时前"
  /// - 昨天: "昨天"
  /// - 更早: "YYYY年M月D日"
  static String formatRelative(DateTime dateTime, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final difference = currentTime.difference(dateTime);

    // 小于10分钟
    if (difference.inMinutes < 10) {
      final minutes = difference.inMinutes;
      if (minutes <= 0) return '刚刚';
      return '$minutes分钟前';
    }

    // 小于8小时
    if (difference.inHours < 8) {
      final hours = difference.inHours;
      if (hours == 0) {
        return '${difference.inMinutes}分钟前';
      }
      return '$hours小时前';
    }

    // 判断是否是昨天
    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == yesterday) {
      return '昨天';
    }

    // 更早的日期显示标准格式
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日';
  }

  /// 格式化日期为 "日 月份" 格式
  /// 例如: "06 12月"
  static String formatDayMonth(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = '${dateTime.month}月';
    return '$day $month';
  }

  /// 格式化年份标题
  /// 例如: "2025年"
  static String formatYearTitle(int year) {
    return '$year年';
  }
}
