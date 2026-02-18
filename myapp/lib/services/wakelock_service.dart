import 'package:flutter/services.dart';

class WakelockService {
  static const MethodChannel _channel = MethodChannel('wakelock_service');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (e) {
      print('Wakelock enable error: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (e) {
      print('Wakelock disable error: $e');
    }
  }
}
