import 'dart:io';

Future<bool> checkOnline() async {
  try {
    final socket = await Socket.connect('8.8.8.8', 53,
        timeout: const Duration(seconds: 3));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
