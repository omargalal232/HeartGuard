class ECGRecord {
  DateTime timestamp;
  List<double> data; // Assuming ECG data is a list of doubles

  ECGRecord({required this.timestamp, required this.data});
}
