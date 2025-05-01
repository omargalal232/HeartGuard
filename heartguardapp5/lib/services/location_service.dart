import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

class LocationService {
  final Logger _logger = Logger();

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.w('Location permissions are permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e, stackTrace) {
      _logger.e('Error getting location', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  String? formatLocationForSMS(Position? position) {
    if (position == null) return null;
    return 'Location: ${position.latitude}, ${position.longitude}\n'
           'Google Maps: https://www.google.com/maps?q=${position.latitude},${position.longitude}';
  }
} 