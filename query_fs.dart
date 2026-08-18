import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://firestore.googleapis.com/v1/projects/fir-link-a8266/databases/(default)/documents:runQuery';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "structuredQuery": {
        "from": [{"collectionId": "attendance_logs"}],
      }
    })
  );
  print(response.body);
}
