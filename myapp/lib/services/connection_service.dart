import 'package:flutter/material.dart';
import 'api_service.dart';

class ConnectionService {
  static final ApiService _apiService = ApiService();
  
  // Проверка подключения и показ уведомления
  static Future<void> checkConnectionAndNotify(BuildContext context) async {
    final isConnected = await _apiService.checkServerConnection();
    
    if (!isConnected) {
      _showConnectionError(context);
    }
  }
  
  // Показать уведомление об ошибке подключения
  static void _showConnectionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Не удалось подключиться к серверу. Попробуйте позже.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Повторить',
          textColor: Colors.white,
          onPressed: () => checkConnectionAndNotify(context),
        ),
      ),
    );
  }
  
  // Показать уведомление об успешном подключении
  static void showConnectionSuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Подключение к серверу установлено',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
