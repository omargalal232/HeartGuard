class UploadResponse {
  final String result;

  UploadResponse({required this.result});

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      result: json['result'] ?? 'Unknown response',
    );
  }
}
