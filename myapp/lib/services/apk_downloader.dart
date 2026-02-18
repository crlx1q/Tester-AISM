import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class ApkDownloader {
  late final Dio _dio;
  
  ApkDownloader() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10), // APK может быть большим
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      receiveDataWhenStatusError: true,
    ));
    
    // Добавляем retry interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (_shouldRetry(error)) {
            print('[APK Download] Retrying after error: ${error.message}');
            try {
              final response = await _retry(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
  
  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.response?.statusCode != null && error.response!.statusCode! >= 500);
  }
  
  Future<Response> _retry(RequestOptions requestOptions, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        await Future.delayed(Duration(seconds: i + 1));
        return await _dio.fetch(requestOptions);
      } on DioException catch (e) {
        if (i == retries - 1) {
          rethrow;
        }
        print('[APK Download] Retry ${i + 1}/$retries failed: ${e.message}');
      }
    }
    throw DioException(
      requestOptions: requestOptions,
      error: 'Failed after $retries retries',
    );
  }
  
  /// Download APK with progress callback (throttled to avoid UI lag)
  /// Returns the path to downloaded file
  Future<String> downloadApk({
    required String url,
    required Function(double progress) onProgress,
  }) async {
    CancelToken? cancelToken;
    try {
      print('[APK Download] Starting download from: $url');
      
      // Get external cache directory (better for large files)
      Directory cacheDir;
      try {
        final tempDirs = await getExternalCacheDirectories();
        cacheDir = (tempDirs != null && tempDirs.isNotEmpty) 
            ? tempDirs.first 
            : await getTemporaryDirectory();
      } catch (e) {
        print('[APK Download] Failed to get external cache, using temp: $e');
        cacheDir = await getTemporaryDirectory();
      }
      final savePath = '${cacheDir.path}/AIStudyMate.apk';
      
      print('[APK Download] Save path: $savePath');
      
      // Delete old APK if exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
        print('[APK Download] Deleted old APK');
      }
      
      // Create cancel token for potential cancellation
      cancelToken = CancelToken();
      
      // Download with throttled progress tracking
      int lastUpdate = 0;
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final now = DateTime.now().millisecondsSinceEpoch;
            // Update UI only every 200ms to avoid lag
            if (now - lastUpdate > 200 || received == total) {
              lastUpdate = now;
              final progress = received / total;
              final percentStr = (progress * 100).toStringAsFixed(1);
              print('[APK Download] Progress: $percentStr% ($received/$total bytes)');
              onProgress(progress);
            }
          }
        },
      );
      
      // Verify file exists and has content
      if (!await file.exists()) {
        throw Exception('APK файл не был создан');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        await file.delete();
        throw Exception('Загруженный APK файл пустой');
      }
      
      print('[APK Download] Success! File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      return savePath;
    } on DioException catch (e) {
      print('[APK Download] DioException: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Превышено время ожидания подключения к серверу');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Превышено время ожидания загрузки файла');
      } else if (e.type == DioExceptionType.badResponse) {
        throw Exception('Сервер вернул ошибку: ${e.response?.statusCode}');
      } else if (e.type == DioExceptionType.cancel) {
        throw Exception('Загрузка отменена');
      } else {
        throw Exception('Ошибка скачивания APK: ${e.message}');
      }
    } catch (e) {
      print('[APK Download] Unexpected error: $e');
      throw Exception('Ошибка скачивания APK: $e');
    } finally {
      cancelToken?.cancel();
    }
  }
  
  /// Open APK file for installation using FileProvider content URI
  Future<void> installApk(String filePath) async {
    try {
      if (!Platform.isAndroid) {
        throw Exception('Установка APK доступна только на Android');
      }

      // Use content:// URI with FileProvider authority
      final packageName = 'com.example.myapp'; // Your app package name
      final authority = '$packageName.fileprovider';
      
      // Convert file path to content URI
      // Format: content://com.example.myapp.fileprovider/cache/AIStudyMate.apk
      final fileName = filePath.split('/').last;
      final contentUri = 'content://$authority/external_cache/$fileName';

      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: contentUri,
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_GRANT_READ_URI_PERMISSION,
        ],
      );
      
      await intent.launch();
    } catch (e) {
      throw Exception('Ошибка установки APK: $e');
    }
  }
  
  /// Download and install APK in one call
  Future<void> downloadAndInstall({
    required String url,
    required Function(double progress) onProgress,
  }) async {
    final filePath = await downloadApk(url: url, onProgress: onProgress);
    await installApk(filePath);
  }
}
