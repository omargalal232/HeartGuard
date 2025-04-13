import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class SMSService {
  final Logger _logger = Logger();
  static const String _apiKey = 'YOUR_NEXMO_API_KEY'; // استبدل بمفتاح API
  static const String _apiSecret = 'YOUR_NEXMO_API_SECRET'; // استبدل بالسر الخاص
  static const String _sender = 'HeartGuard'; // اسم المرسل
  static const String _baseUrl = 'https://rest.nexmo.com/sms/json';

  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // تنظيف رقم الهاتف
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // إضافة رمز الدولة إذا لم يكن موجوداً
      final formattedNumber = cleanPhoneNumber.startsWith('+') 
          ? cleanPhoneNumber.substring(1) // إزالة علامة + لأن Nexmo لا تحتاجها
          : '20$cleanPhoneNumber'; // افتراضياً مصر (20)

      final response = await http.post(
        Uri.parse(_baseUrl),
        body: {
          'api_key': _apiKey,
          'api_secret': _apiSecret,
          'to': formattedNumber,
          'from': _sender,
          'text': message,
          'type': 'unicode', // للدعم الكامل للغة العربية
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['messages'][0]['status'] == '0') {
          _logger.i('تم إرسال الرسالة بنجاح');
          return true;
        } else {
          _logger.e('فشل في إرسال الرسالة: ${data['messages'][0]['error-text']}');
          return false;
        }
      } else {
        _logger.e('خطأ في الاتصال بالخادم: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('خطأ في إرسال الرسالة', error: e);
      return false;
    }
  }
} 