import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertService with ChangeNotifier {
  final List<AlertModel> _alerts = [];

  void addAlert(AlertModel alert) {
    _alerts.add(alert);
    notifyListeners();
  }

  List<AlertModel> getAlerts() {
    return _alerts;
  }
} 