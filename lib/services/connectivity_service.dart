import 'dart:async';

import 'online_check.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool isOnline = true;
  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  Future<void> _check() async {
    final online = await checkOnline();
    if (online != isOnline) {
      isOnline = online;
      _controller.add(online);
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
