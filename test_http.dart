import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.namecheap.work';
  try {
    print('1. Testing Login (Custom JWT)...');
    final loginRes = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'admin', 'password': '1234'}),
    );

    if (loginRes.statusCode != 200) {
      print('Login Failed: ${loginRes.statusCode} - ${loginRes.body}');
      return;
    }

    final token = jsonDecode(loginRes.body)['token'];
    print('Login OK. Token: ${token.substring(0, 15)}...');

    print('2. Searching for "ปูน"...');
    final searchRes = await http.get(
      Uri.parse('$baseUrl/api/v1/products?q=%E0%B8%9B%E0%B8%B9%E0%B8%99'), // ปูน urlencoded
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Search Status: ${searchRes.statusCode}');
    print('Search Body: ${searchRes.body.length > 200 ? searchRes.body.substring(0, 200) + '...' : searchRes.body}');
  } catch(e) {
    print(e);
  }
}
