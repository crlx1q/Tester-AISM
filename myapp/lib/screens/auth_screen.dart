import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/profile_notifier.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const AuthScreen({super.key, required this.onSignedIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final ProfileNotifier _profileNotifier = ProfileNotifier();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isRequestingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;
  bool _awaitingConfirmation = false;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingName;
  bool _isResetMode = false;
  bool _awaitingResetCode = false;
  Timer? _resetTimer;
  int _resetCountdown = 0;

  void _toggleForm() {
    setState(() {
      if (_isResetMode) {
        _resetState();
      } else {
        _isLogin = !_isLogin;
      }

      if (_isLogin) {
        _codeController.clear();
        _stopCodeTimer();
        _awaitingConfirmation = false;
        _pendingEmail = null;
        _pendingPassword = null;
        _pendingName = null;
      }
    });
  }

  Future<void> _submitForm() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (_isResetMode) {
      await _submitPasswordReset();
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      _showError('Заполните email и пароль');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Введите корректный email');
      return;
    }

    if (!_isLogin && name.isEmpty) {
      _showError('Имя обязательно для регистрации');
      return;
    }

    if (!_isLogin && password.length < 6) {
      _showError('Пароль должен содержать минимум 6 символов');
      return;
    }

    if (_isLogin) {
      setState(() => _isLoading = true);

      try {
        final response = await _apiService.login(email, password);
        if (response['success']) {
          final prefs = await SharedPreferences.getInstance();
          final user = User.fromJson(response['data']);
          await prefs.setString('userData', jsonEncode(user.toJson()));
          _profileNotifier.updateUser(user);
          widget.onSignedIn();
        } else {
          _showError(response['message']);
        }
      } catch (e) {
        _showError('Не удалось подключиться к серверу. Убедитесь, что он запущен.');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    if (!_awaitingConfirmation) {
      if (name.isEmpty) {
        _showError('Имя обязательно для регистрации');
        return;
      }

      if (password.length < 6) {
        _showError('Пароль должен содержать минимум 6 символов');
        return;
      }

      await _requestCode(initialRequest: true);
      return;
    }

    if (code.isEmpty) {
      _showError('Введите код подтверждения');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.register(
        _pendingName ?? name,
        _pendingEmail ?? email,
        _pendingPassword ?? password,
        code,
      );

      if (response['success']) {
        final prefs = await SharedPreferences.getInstance();
        final user = User.fromJson(response['data']);
        await prefs.setString('userData', jsonEncode(user.toJson()));
        _profileNotifier.updateUser(user);
        widget.onSignedIn();
      } else {
        _showError(response['message']);
      }
    } catch (e) {
      _showError('Не удалось подключиться к серверу. Убедитесь, что он запущен.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestCode({bool initialRequest = false}) async {
    if (_isRequestingCode || (_codeCountdown > 0 && !initialRequest)) {
      return;
    }

    final email = initialRequest
        ? _emailController.text.trim()
        : (_pendingEmail ?? _emailController.text.trim());
    final name = initialRequest ? _nameController.text.trim() : _pendingName;
    final password = initialRequest ? _passwordController.text.trim() : _pendingPassword;

    if (!_isValidEmail(email)) {
      _showError('Введите корректный email прежде чем запрашивать код');
      return;
    }

    if (initialRequest) {
      if (name == null || name.isEmpty) {
        _showError('Имя обязательно для регистрации');
        return;
      }

      if (password == null || password.length < 6) {
        _showError('Пароль должен содержать минимум 6 символов');
        return;
      }
    }

    setState(() {
      _isRequestingCode = true;
    });

    try {
      final result = await _apiService.requestRegistrationCode(email);
      if (result['success']) {
        setState(() {
          _awaitingConfirmation = true;
          _pendingEmail = email;
          _pendingName = name;
          _pendingPassword = password;
        });
        _startCodeTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['data']['message']}\nКод: ${result['data']['debug_code']}'),
          ),
        );
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Не удалось запросить код. Попробуйте позже.');
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingCode = false;
        });
      }
    }
  }

  Future<void> _submitPasswordReset() async {
    if (_isLoading) return;

    final email = _resetEmailController.text.trim();

    if (!_awaitingResetCode) {
      if (email.isEmpty) {
        _showError('Введите email для сброса пароля');
        return;
      }

      if (!_isValidEmail(email)) {
        _showError('Введите корректный email');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final result = await _apiService.requestPasswordResetCode(email);
        if (result['success']) {
          setState(() {
            _awaitingResetCode = true;
          });
          _startResetTimer();
          final data = result['data'];
          final message = data['message'] ?? 'Код отправлен на вашу почту';
          final debugCode = data['debug_code'] != null ? '\nКод: ${data['debug_code']}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$message$debugCode')),
          );
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError('Не удалось запросить код. Попробуйте позже.');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    final code = _resetCodeController.text.trim();
    final newPassword = _resetPasswordController.text.trim();

    if (code.isEmpty) {
      _showError('Введите код сброса пароля');
      return;
    }

    if (newPassword.length < 6) {
      _showError('Новый пароль должен содержать минимум 6 символов');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.confirmPasswordReset(email, code, newPassword);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль успешно сброшен. Войдите с новым паролем.')),
        );
        setState(() {
          _isResetMode = false;
          _awaitingResetCode = false;
          _resetEmailController.clear();
          _resetCodeController.clear();
          _resetPasswordController.clear();
          _resetCountdown = 0;
        });
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Не удалось сбросить пароль. Попробуйте позже.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startResetTimer() {
    _stopResetTimer();
    setState(() {
      _resetCountdown = 59;
    });

    _resetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resetCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resetCountdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resetCountdown -= 1;
          });
        } else {
          timer.cancel();
        }
      }
    });
  }

  void _stopResetTimer() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _resetCountdown = 0;
  }

  void _resetState() {
    _isResetMode = false;
    _awaitingResetCode = false;
    _resetEmailController.clear();
    _resetCodeController.clear();
    _resetPasswordController.clear();
    _stopResetTimer();
  }

  void _startCodeTimer() {
    _stopCodeTimer();
    setState(() {
      _codeCountdown = 59;
    });

    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_codeCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _codeCountdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _codeCountdown -= 1;
          });
        } else {
          timer.cancel();
        }
      }
    });
  }

  void _stopCodeTimer() {
    _codeTimer?.cancel();
    _codeTimer = null;
    _codeCountdown = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _resetPasswordController.dispose();
    _codeTimer?.cancel();
    _resetTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final subtextColor = isDarkMode ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);
    final cardColor = isDarkMode ? const Color(0xFF1f2937) : Colors.white;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 80),
            Text(
              _isResetMode
                  ? (_awaitingResetCode ? 'Сброс пароля' : 'Забыли пароль?')
                  : (_isLogin ? 'Вход в аккаунт' : 'Создание аккаунта'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              _isResetMode
                  ? (_awaitingResetCode
                      ? 'Введите код, отправленный на вашу почту, и придумайте новый пароль.'
                      : 'Мы отправим код подтверждения на ваш email.')
                  : (_isLogin
                      ? 'Войдите, чтобы сохранить свой прогресс.'
                      : 'Заполните данные для регистрации.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtextColor, fontSize: 16),
            ),
            const SizedBox(height: 48),
            if (_isResetMode) ...[
              TextField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration('Email', cardColor),
              ),
              const SizedBox(height: 16),
              if (_awaitingResetCode) ...[
                TextField(
                  controller: _resetCodeController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Код сброса', cardColor),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _resetPasswordController,
                  obscureText: true,
                  decoration: _buildInputDecoration('Новый пароль', cardColor),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: (_resetCountdown == 0 && !_isLoading)
                      ? () async {
                          await _submitPasswordReset();
                        }
                      : null,
                  child: Text(
                    _resetCountdown == 0 ? 'Отправить код снова' : 'Отправить код снова (${_resetCountdown})',
                    style: TextStyle(
                      color: (_resetCountdown == 0 && !_isLoading) ? Colors.indigo : subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ] else if (_isLogin) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration('Email', cardColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _buildInputDecoration('Пароль', cardColor),
              ),
            ] else if (!_awaitingConfirmation) ...[
              TextField(
                controller: _nameController,
                decoration: _buildInputDecoration('Имя', cardColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration('Email', cardColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _buildInputDecoration('Пароль', cardColor),
              ),
            ] else ...[
              Text(
                'Подтверждение почты',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Мы отправили код на ${_pendingEmail ?? _emailController.text}. Введите его ниже.',
                style: TextStyle(color: subtextColor, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Код подтверждения', cardColor),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: (_codeCountdown == 0 && !_isRequestingCode)
                    ? () => _requestCode(initialRequest: false)
                    : null,
                child: Text(
                  _codeCountdown == 0
                      ? 'Отправить снова'
                      : 'Отправить снова (${_codeCountdown})',
                  style: TextStyle(
                    color: (_codeCountdown == 0 && !_isRequestingCode)
                        ? Colors.indigo
                        : subtextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isResetMode
                          ? (_awaitingResetCode ? 'Сбросить пароль' : 'Отправить код')
                          : (_isLogin
                              ? 'Войти'
                              : (_awaitingConfirmation ? 'Подтвердить' : 'Зарегистрироваться')),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),
            if (!_isResetMode && _isLogin)
              GestureDetector(
                onTap: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isResetMode = true;
                          _isLogin = true;
                        });
                      },
                child: Text(
                  'Забыли пароль?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                ),
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: 12),
            if (!_isResetMode && !_awaitingConfirmation)
              TextButton(
                onPressed: _isLoading ? null : _toggleForm,
                child: Text(
                  _isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти',
                  style: TextStyle(color: subtextColor),
                ),
              )
            else
              const SizedBox(height: 0),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  InputDecoration _buildInputDecoration(String label, Color fillColor) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

