import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SMSHelper {
  static Future<bool> requestSMSPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final hasPermission = await requestSMSPermission();
      if (!hasPermission) {
        return false;
      }

      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
} 