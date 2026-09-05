import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formatting and validation utilities tailored for TutionTracker
class AppFormatters {
  AppFormatters._();

  /// Currency symbol for Bangladeshi Taka
  static const String currencySymbol = '৳';

  /// Format amount in Taka (e.g. "৳ 5,000" or "৳ 500")
  static String formatTaka(num amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '$currencySymbol ${formatter.format(amount)}';
  }

  /// Format date with ordinal day (e.g. "4th Sep, 2026")
  static String formatDateOrdinal(DateTime date) {
    final day = date.day;
    final suffix = _getDayOrdinalSuffix(day);
    final monthYear = DateFormat('MMM, yyyy').format(date);
    return '$day$suffix $monthYear';
  }

  /// Get ordinal suffix for day of the month (1st, 2nd, 3rd, etc.)
  static String _getDayOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Determine broad time slot according to specification:
  /// - Morning: 06:00 AM – 11:59 AM
  /// - Noon: 12:00 PM – 03:59 PM
  /// - Afternoon: 04:00 PM – 05:29 PM
  /// - Evening: 05:30 PM – 07:29 PM
  /// - Night: 07:30 PM onwards
  static String getTimeSlot(DateTime time) {
    final minutesSinceMidnight = time.hour * 60 + time.minute;

    if (minutesSinceMidnight >= 6 * 60 && minutesSinceMidnight < 12 * 60) {
      return 'Morning';
    } else if (minutesSinceMidnight >= 12 * 60 && minutesSinceMidnight < 16 * 60) {
      return 'Noon';
    } else if (minutesSinceMidnight >= 16 * 60 && minutesSinceMidnight < 17 * 60 + 30) {
      return 'Afternoon';
    } else if (minutesSinceMidnight >= 17 * 60 + 30 && minutesSinceMidnight < 19 * 60 + 30) {
      return 'Evening';
    } else {
      return 'Night';
    }
  }

  /// Humanized time slot with formatted clock time (e.g. "Evening • 6:30 PM")
  static String formatTimeWithSlot(DateTime time) {
    final slot = getTimeSlot(time);
    final clock = DateFormat('h:mm a').format(time);
    return '$slot • $clock';
  }

  /// Clean Bangladeshi mobile number (removes spaces, dashes, brackets, +88 prefix)
  static String cleanBdPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+88')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('88')) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }

  /// Strict 11-digit Bangladeshi mobile validation
  /// Must start with 01 and match ^01[3-9]\d{8}$
  static bool isValidBdPhone(String phone) {
    final cleaned = cleanBdPhone(phone);
    final regex = RegExp(r'^01[3-9]\d{8}$');
    return regex.hasMatch(cleaned);
  }

  /// Direct Phone Dialer Launcher
  static Future<bool> launchDialer(String rawPhone) async {
    final cleaned = cleanBdPhone(rawPhone);
    if (cleaned.isEmpty) return false;

    // Use full E.164 format +880...
    final fullNumber = '+88$cleaned';
    final uri = Uri.parse('tel:$fullNumber');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Direct WhatsApp Launcher
  static Future<bool> launchWhatsApp(String rawPhone) async {
    final cleaned = cleanBdPhone(rawPhone);
    if (cleaned.isEmpty) return false;

    final waNumber = '88$cleaned';
    final uri = Uri.parse('https://wa.me/$waNumber');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Direct SMS/Message Launcher
  static Future<bool> launchSms(String rawPhone, [String? body]) async {
    final cleaned = cleanBdPhone(rawPhone);
    if (cleaned.isEmpty) return false;

    final fullNumber = '+88$cleaned';
    final Uri uri;
    if (body != null && body.isNotEmpty) {
      uri = Uri(
        scheme: 'sms',
        path: fullNumber,
        queryParameters: {'body': body},
      );
    } else {
      uri = Uri.parse('sms:$fullNumber');
    }
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

