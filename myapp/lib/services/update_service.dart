import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/update_info.dart';
import 'api_service.dart';
import 'update_notifier.dart';

class UpdateStatus {
  final String currentVersion;
  final UpdateInfo? remoteInfo;
  final UpdateInfo? availableUpdate;
  final bool serverReachable;
  final String? message;
  final bool viaPush;

  const UpdateStatus({
    required this.currentVersion,
    required this.remoteInfo,
    required this.availableUpdate,
    required this.serverReachable,
    this.message,
    this.viaPush = false,
  });

  bool get isUpdateAvailable => availableUpdate != null;
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final ApiService _apiService = ApiService();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _connecting = false;
  String? _currentAppVersion;
  void Function(UpdateStatus status)? _listener;

  Future<String> _ensureCurrentVersion() async {
    if (_currentAppVersion != null) {
      return _currentAppVersion!;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    _currentAppVersion = packageInfo.version;
    return _currentAppVersion!;
  }

  Future<UpdateStatus> fetchStatus() async {
    final response = await _apiService.getHealthStatus();
    if (response['success'] != true) {
      final currentVersion = await _ensureCurrentVersion();
      return UpdateStatus(
        currentVersion: currentVersion,
        remoteInfo: null,
        availableUpdate: null,
        serverReachable: false,
        message: response['message']?.toString(),
      );
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    UpdateInfo? remoteInfo;
    final latestVersionJson = data['latestVersion'];
    if (latestVersionJson is Map<String, dynamic>) {
      remoteInfo = UpdateInfo.fromJson(latestVersionJson);
    }

    final message = data['message']?.toString();
    return _buildStatus(
      remoteInfo: remoteInfo,
      serverReachable: true,
      message: message,
      viaPush: false,
    );
  }

  Future<void> startListening(void Function(UpdateStatus status) listener) async {
    _listener = listener;
    await _ensureCurrentVersion();
    await _openChannel();
  }

  Future<void> dispose() async {
    _listener = null;
    _reconnectTimer?.cancel();
    await _closeChannel();
  }

  Future<void> _openChannel() async {
    if (_connecting) {
      return;
    }
    _reconnectTimer?.cancel();
    _connecting = true;
    await _closeChannel();

    final uri = ApiService.buildWebSocketUri('/updates');
    log('Подключение к серверу обновлений: $uri');
    try {
      final channel = IOWebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleWebSocketData,
        onError: (error) {
          log('Ошибка WebSocket обновлений: $error');
          _notifyConnectionIssue('Ошибка соединения с сервером обновлений');
          _scheduleReconnect();
        },
        onDone: () {
          log('Соединение WebSocket обновлений закрыто');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (error, stackTrace) {
      log('Не удалось подключиться к серверу обновлений', error: error, stackTrace: stackTrace);
      _notifyConnectionIssue('Не удалось подключиться к серверу обновлений');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleWebSocketData(dynamic event) {
    Future.microtask(() async {
      try {
        final raw = event is String ? event : jsonEncode(event);
        final payload = jsonDecode(raw);
        if (payload is! Map<String, dynamic>) {
          return;
        }

        final type = payload['type']?.toString() ?? '';
        final data = payload['data'];
        if (data is! Map) {
          return;
        }

        final remoteInfo = UpdateInfo.fromJson(Map<String, dynamic>.from(data as Map));
        final status = await _buildStatus(
          remoteInfo: remoteInfo,
          serverReachable: true,
          viaPush: type != 'latest_version',
        );
        _notifyStatus(status);
      } catch (error, stackTrace) {
        log('Не удалось обработать сообщение WebSocket обновлений', error: error, stackTrace: stackTrace);
      }
    });
  }

  Future<UpdateStatus> _buildStatus({
    UpdateInfo? remoteInfo,
    required bool serverReachable,
    String? message,
    required bool viaPush,
  }) async {
    final currentVersion = await _ensureCurrentVersion();
    UpdateInfo? availableUpdate;
    if (remoteInfo != null && _isNewerVersion(remoteInfo.version, currentVersion)) {
      final notifier = UpdateNotifier();
      if (notifier.isSnoozed(remoteInfo.version)) {
        availableUpdate = null;
      } else {
        availableUpdate = remoteInfo;
      }
    }

    return UpdateStatus(
      currentVersion: currentVersion,
      remoteInfo: remoteInfo,
      availableUpdate: availableUpdate,
      serverReachable: serverReachable,
      message: message,
      viaPush: viaPush,
    );
  }

  void _notifyStatus(UpdateStatus status) {
    final listener = _listener;
    if (listener != null) {
      listener(status);
    }
  }

  void _notifyConnectionIssue(String message) {
    _buildStatus(
      remoteInfo: null,
      serverReachable: false,
      message: message,
      viaPush: false,
    ).then(_notifyStatus).catchError((error, stackTrace) {
      log('Не удалось отправить статус ошибки подключения', error: error, stackTrace: stackTrace);
    });
  }

  void _scheduleReconnect([Duration delay = const Duration(seconds: 5)]) {
    if (_listener == null) {
      return;
    }
    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(delay, () async {
      await _openChannel();
    });
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  bool _isNewerVersion(String serverVersion, String localVersion) {
    final cleanedServer = _cleanVersion(serverVersion);
    final cleanedLocal = _cleanVersion(localVersion);

    for (var i = 0; i < cleanedServer.length || i < cleanedLocal.length; i++) {
      final serverPart = i < cleanedServer.length ? cleanedServer[i] : 0;
      final localPart = i < cleanedLocal.length ? cleanedLocal[i] : 0;

      if (serverPart > localPart) {
        return true;
      } else if (serverPart < localPart) {
        return false;
      }
    }
    return false;
  }

  List<int> _cleanVersion(String version) {
    final mainPart = version.split('+').first;
    final segments = mainPart.split('.');
    return segments
        .map((segment) => int.tryParse(segment.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
