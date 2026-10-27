import 'package:intl/intl.dart';

class TimezoneInfo {
  final String code;
  final String name;
  final String region;
  final int offsetHours;
  final String formattedTime;

  const TimezoneInfo({
    required this.code,
    required this.name,
    required this.region,
    required this.offsetHours,
    required this.formattedTime,
  });
}

class TimezoneService {
  static final TimezoneService instance = TimezoneService._internal();
  TimezoneService._internal();

  /// Determine if London is currently observing British Summer Time (BST, UTC+1)
  /// Last Sunday of March to last Sunday of October
  static bool isLondonDst(DateTime utcNow) {
    if (utcNow.month < 3 || utcNow.month > 10) return false;
    if (utcNow.month > 3 && utcNow.month < 10) return true;

    // Boundary months (March and October)
    final lastSunday = DateTime.utc(utcNow.year, utcNow.month, 31);
    final dayOfWeek = lastSunday.weekday % 7; // Sunday is 7 in Dart DateTime -> 0
    final lastSundayDate = 31 - dayOfWeek;

    if (utcNow.month == 3) {
      return utcNow.day >= lastSundayDate;
    } else {
      return utcNow.day < lastSundayDate;
    }
  }

  /// Get time information for all 4 required timezones
  List<TimezoneInfo> getAllTimezones({DateTime? customUtc}) {
    final utc = (customUtc ?? DateTime.now()).toUtc();
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    // 1. WIB (Western Indonesia Time, UTC+7)
    final wibTime = utc.add(const Duration(hours: 7));

    // 2. WITA (Central Indonesia Time, UTC+8)
    final witaTime = utc.add(const Duration(hours: 8));

    // 3. WIT (Eastern Indonesia Time, UTC+9)
    final witTime = utc.add(const Duration(hours: 9));

    // 4. London (GMT UTC+0 or BST UTC+1)
    final londonOffset = isLondonDst(utc) ? 1 : 0;
    final londonTime = utc.add(Duration(hours: londonOffset));

    return [
      TimezoneInfo(
        code: 'WIB',
        name: 'Waktu Indonesia Barat (UTC+7)',
        region: 'Jawa, Sumatera, Kalimantan Barat & Tengah',
        offsetHours: 7,
        formattedTime: '${timeFormat.format(wibTime)} • ${dateFormat.format(wibTime)}',
      ),
      TimezoneInfo(
        code: 'WITA',
        name: 'Waktu Indonesia Tengah (UTC+8)',
        region: 'Bali, NTB, NTT, Sulawesi, Kalimantan Selatan & Timur',
        offsetHours: 8,
        formattedTime: '${timeFormat.format(witaTime)} • ${dateFormat.format(witaTime)}',
      ),
      TimezoneInfo(
        code: 'WIT',
        name: 'Waktu Indonesia Timur (UTC+9)',
        region: 'Maluku, Papua, Papua Barat',
        offsetHours: 9,
        formattedTime: '${timeFormat.format(witTime)} • ${dateFormat.format(witTime)}',
      ),
      TimezoneInfo(
        code: 'London',
        name: isLondonDst(utc) ? 'London (BST, UTC+1)' : 'London (GMT, UTC+0)',
        region: 'United Kingdom',
        offsetHours: londonOffset,
        formattedTime: '${timeFormat.format(londonTime)} • ${dateFormat.format(londonTime)}',
      ),
    ];
  }
}
