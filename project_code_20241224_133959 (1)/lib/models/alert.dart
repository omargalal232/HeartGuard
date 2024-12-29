class Alert {
  String message;
  DateTime timestamp;
  bool isCritical;

  Alert(
      {required this.message,
      required this.timestamp,
      this.isCritical = false});
}
