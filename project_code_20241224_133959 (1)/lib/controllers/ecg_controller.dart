import '../models/ecg_record.dart';

class ECGController {
  List<ECGRecord> records = [];

  void addRecord(ECGRecord record) {
    records.add(record);
    // Additional logic for processing ECG records can be added here
  }

  List<ECGRecord> getRecords() {
    return records;
  }
}
