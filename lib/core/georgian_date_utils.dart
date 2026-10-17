class GeorgianDateUtils {
  static const List<String> months = [
    'იანვარი',
    'თებერვალი',
    'მარტი',
    'აპრილი',
    'მაისი',
    'ივნისი',
    'ივლისი',
    'აგვისტო',
    'სექტემბერი',
    'ოქტომბერი',
    'ნოემბერი',
    'დეკემბერი',
  ];

  static const List<String> weekdaysFull = [
    'ორშაბათი',
    'სამშაბათი',
    'ოთხშაბათი',
    'ხუთშაბათი',
    'პარასკევი',
    'შაბათი',
    'კვირა',
  ];

  static const List<String> weekdaysShort = ['ო', 'ს', 'ო', 'ხ', 'პ', 'შ', 'კ'];

  static String formatDate(DateTime date) {
    return '${date.day} ${months[date.month - 1]}';
  }

  static String formatDateWithYear(DateTime date) {
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  static String formatMonthYear(int year, int month) {
    return '${months[month - 1]} $year';
  }

  static String formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDateTime(DateTime dt) {
    return '${formatDate(dt)} • ${formatTime(dt)}';
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }
}
