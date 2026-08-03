import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'package:s_link/features/auth/models/user_role.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class AuthService {
  final UserService _userService = UserService();

  Future<UserModel?> login(String username, String password) async {
    try {
      final baseUrl = await PosApiService().getBaseUrl() ?? 'https://api.namecheap.work';
      final uri = Uri.parse('$baseUrl/api/v1/auth/login');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          await prefs.setString('offline_jwt_token', data['token']);
          await prefs.setString('offline_username', username);
          await prefs.setString('offline_password', password);
          if (data['user'] != null) {
             final u = data['user'];
             final uid = u['id'].toString();
             final roleStr = (u['role'] ?? 'CASHIER').toString().toUpperCase();
             
             // 🔥 Dual Authentication: Log into Firebase for Firestore access
             // Use UID for email instead of username to prevent invalid-email errors with Thai names!
             String? firebaseUid;
             try {
               String firebasePassword = password;
               if (firebasePassword.length < 6) {
                 firebasePassword = firebasePassword.padRight(6, '0'); // Firebase requires >= 6 chars
               }
               
               final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                 email: 'user$uid@s-link.local', 
                 password: firebasePassword
               );
               firebaseUid = userCred.user?.uid;
               log('Firebase login successful (Dual Auth). UID: $firebaseUid');
             } on FirebaseAuthException catch (e) {
               if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
                 try {
                   String firebasePassword = password;
                   if (firebasePassword.length < 6) {
                     firebasePassword = firebasePassword.padRight(6, '0');
                   }
                   final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                     email: 'user$uid@s-link.local', 
                     password: firebasePassword
                   );
                   firebaseUid = userCred.user?.uid;
                   log('Firebase user auto-created and logged in (Dual Auth). UID: $firebaseUid');
                 } catch (createErr) {
                   log('⚠️ Firebase auto-create failed: $createErr');
                 }
               } else {
                 log('⚠️ Firebase login failed (Firestore may not work): $e');
               }
             } catch (e) {
               log('⚠️ Firebase login failed (Firestore may not work): $e');
             }
             
             // Map MySQL roles -> S-Link UserRole
             final UserRole role;
             switch (roleStr) {
               case 'ADMIN':
                 role = UserRole.admin;
                 break;
               case 'DRIVER':
                 role = UserRole.driver;
                 break;
               case 'HR':
                 role = UserRole.hr;
                 break;
               case 'GAS_STATION':
                 role = UserRole.gasStation;
                 break;
               case 'CASHIER':
               default:
                 role = UserRole.requester; // CASHIER = พนักงานหน้าร้าน = requester ใน S-Link
                 break;
             }
             
             // CRITICAL: We now strictly use the MySQL `uid` as the primary key for Firestore (`finalUid`),
             // completely dropping the reliance on `firebaseUid`. This perfectly maps users between POS and S-Link.
             final finalUid = uid;
             
             final user = UserModel(
               uid: finalUid,
               email: (u['username'] ?? '').toString(),
               name: (u['employee_name'] ?? u['username'] ?? 'Unknown').toString(),
               role: role,
             );
             
             // Sync the MySQL user to Firestore so FCM and other features still work
             // Non-critical: if Firestore fails (Windows/Web), login still succeeds
             try {
               await _userService.saveNewUser(finalUid, user.email, user.name, role);
             } catch (e) {
               log('⚠️ Firestore sync skipped (non-critical): $e');
             }
             
             return user;
          } else {
             throw Exception('Login failed: Invalid user data in response.');
          }
        } else {
          throw Exception('Login failed: No token received.');
        }
      } else {
        throw Exception('Login failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log('Login Exception: $e');

      // --- Offline Login Fallback ---
      try {
        final prefs = await SharedPreferences.getInstance();
        final offUser = prefs.getString('offline_username');
        final offPass = prefs.getString('offline_password');
        final offToken = prefs.getString('offline_jwt_token');

        if (offUser != null && offPass != null && offUser == username && offPass == password && offToken != null) {
          log('✅ Offline Login Successful using cached credentials');
          await prefs.setString('jwt_token', offToken);

          // Try Firebase login offline (uses cached session if no network)
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: '$username@s-link.local', 
              password: password
            );
          } catch (_) {}

          // Decode JWT payload
          final parts = offToken.split('.');
          if (parts.length == 3) {
            final payload = jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
            );
            
            final roleStr = (payload['role'] ?? 'CASHIER').toString().toUpperCase();
            UserRole role;
            switch (roleStr) {
              case 'ADMIN': role = UserRole.admin; break;
              case 'DRIVER': role = UserRole.driver; break;
              case 'HR': role = UserRole.hr; break;
              case 'GAS_STATION': role = UserRole.gasStation; break;
              case 'CASHIER':
              default: role = UserRole.requester; break;
            }

            return UserModel(
              uid: payload['id']?.toString() ?? '0',
              email: payload['username']?.toString() ?? '',
              name: payload['employee_name']?.toString() ?? payload['username']?.toString() ?? 'Unknown',
              role: role,
            );
          }
        }
      } catch (offlineErr) {
        log('Offline Login Exception: $offlineErr');
      }
      
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmail(
    String username,
    String password,
    String name,
    UserRole initialRole,
  ) async {
    try {
      final baseUrl = await PosApiService().getBaseUrl() ?? 'https://api.namecheap.work';
      final uri = Uri.parse('$baseUrl/api/v1/auth/register');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'name': name,
          'role': initialRole.name,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UserModel(
          uid: 'temp-uid', // Replace with real uid from API
          email: '$username@s-link.local',
          name: name,
          role: initialRole,
        );
      } else {
        throw Exception('Registration failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log('Registration Exception: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _userService.unsubscribeAllTopics();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}

