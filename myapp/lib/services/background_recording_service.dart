import 'notification_service.dart';
import 'foreground_service.dart';

class BackgroundRecordingService {
  static final BackgroundRecordingService _instance = BackgroundRecordingService._internal();
  factory BackgroundRecordingService() => _instance;
  BackgroundRecordingService._internal();

  static Future<void> initialize() async {
    // Service ready
  }

  static Future<void> startRecording() async {
    // Start foreground service to keep app alive in background
    await ForegroundService.start();
    
    // Start recording notification
    await NotificationService().showRecordingNotification();
  }

  static Future<void> stopRecording(String duration) async {
    // Stop foreground service
    await ForegroundService.stop();
    
    // Hide recording notification and show completion
    await NotificationService().hideRecordingNotification();
    await NotificationService().showRecordingCompletedNotification(duration);
  }
}
