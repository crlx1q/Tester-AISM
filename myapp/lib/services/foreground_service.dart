import 'package:flutter/services.dart';

class ForegroundService {
  static const MethodChannel _channel = MethodChannel('foreground_service');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } catch (e) {
      print('Foreground service start error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      print('Foreground service stop error: $e');
    }
  }
}
