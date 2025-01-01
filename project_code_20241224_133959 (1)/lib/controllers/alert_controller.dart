import '../models/alert.dart';

class AlertController {
  List<Alert> alerts = [];

  void addAlert(Alert alert) {
    alerts.add(alert);
    // Additional logic for processing alerts can be added here
  }

  List<Alert> getAlerts() {
    return alerts;
  }
}
