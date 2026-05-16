import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

Future<String?> discoverPosServer() async {
  RawDatagramSocket? socket;
  try {
    // 1. Bind to ANY available port
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    // 2. Prepare Broadcast Message
    final message = utf8.encode('WHO_IS_POS');
    final destPort = 4040;
    final destAddress = InternetAddress('255.255.255.255');

    debugPrint(
        '📡 [UDP Client] Sending "WHO_IS_POS" to 255.255.255.255:$destPort');
    socket.send(message, destAddress, destPort);

    // 3. Listen for Reply (Timeout 3s)
    final completer = Completer<String?>();

    // Timer to close socket if no reply
    final timer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket?.receive();
        if (datagram != null) {
          final reply = utf8.decode(datagram.data).trim();
          debugPrint(
              '📡 [UDP Client] Received "$reply" from ${datagram.address.address}');

          if (reply == 'I_AM_POS') {
            if (!completer.isCompleted) {
              completer.complete(datagram.address.address); // Return IP
            }
          }
        }
      }
    });

    final result = await completer.future;
    timer.cancel();
    return result;
  } catch (e) {
    debugPrint('❌ [UDP Client] Error: $e');
    return null;
  } finally {
    socket?.close();
  }
}
