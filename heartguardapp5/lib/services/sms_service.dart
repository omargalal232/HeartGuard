import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class SMSService {
  final Logger _logger = Logger();
  // المفتاح الصحيح المقدم من CallMeBot
  static const String _apiKey = '1332999';
  // استخدام نفس عنوان URL الرسمي من رسالة التأكيد
  static const String _baseUrl = 'https://api.callmebot.com/whatsapp.php';
  // رقم الهاتف المسجل مع إزالة علامة +
  static const String _defaultPhone = '201226248908';

  Future<bool> sendWhatsAppMessage({
    String? phoneNumber,
    required String message,
  }) async {
    try {
      // استخدام الرقم المقدم أو الرقم الافتراضي
      String targetPhone = phoneNumber ?? _defaultPhone;
      
      // تنظيف رقم الهاتف من أي أحرف غير رقمية
      targetPhone = targetPhone.replaceAll(RegExp(r'[^\d]'), '');
      
      // استخدام نفس تنسيق URL كما هو موضح في رسالة التأكيد
      final uri = Uri.parse('$_baseUrl?phone=$targetPhone&text=${Uri.encodeComponent(message)}&apikey=$_apiKey');

      _logger.d('Sending WhatsApp message to: $targetPhone');
      _logger.d('Request URL: ${uri.toString()}');

      final response = await http.get(uri);
      _logger.d('Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.toLowerCase().contains('queued') || 
            response.body.toLowerCase().contains('success')) {
          _logger.i('تم إرسال رسالة واتساب بنجاح');
          return true;
        } else {
          _logger.e('فشل في إرسال رسالة واتساب: ${response.body}');
          return false;
        }
      } else {
        _logger.e('خطأ في الاتصال بالخادم: ${response.statusCode}');
        _logger.e('تفاصيل الخطأ: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('خطأ في إرسال رسالة واتساب', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Method to send SMS using the SMS URI scheme
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Clean phone number
      String targetPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      if (targetPhone.isEmpty) {
        _logger.e('Cannot send SMS: invalid phone number');
        return false;
      }
      
      _logger.d('Attempting to send SMS to: $targetPhone');
      
      // Use URI scheme to open default SMS app
      final uri = Uri.parse('sms:$targetPhone?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // Note: We can't guarantee message was actually sent, only that SMS app opened
        _logger.i('SMS app opened successfully for: $targetPhone');
        return true;
      } else {
        _logger.e('Cannot launch SMS app for: $targetPhone');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending SMS', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // دالة مساعدة لتنسيق رسالة الطوارئ
  String formatEmergencyMessage({
    required String userEmail,
    required int heartRate,
    required int bloodPressure,
    required int oxygenLevel,
    required String diagnosis,
  }) {
    return '''Emergency Alert!
Patient: $userEmail
Vitals: HR=$heartRate BP=$bloodPressure O2=$oxygenLevel%
Issue: $diagnosis
HeartGuard App''';
  }
} 