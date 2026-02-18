import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/profile_notifier.dart';

class ProfileSettingsPage extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdated;

  const ProfileSettingsPage({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  static const _minPasswordLength = 6;
  final ApiService _apiService = ApiService();
  final ProfileNotifier _profileNotifier = ProfileNotifier();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUpdatingAvatar = false;
  bool _isUpdatingName = false;
  bool _isChangingPassword = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController.text = widget.user.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _isUpdatingAvatar = true;
      });

      try {
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        final avatarData = 'data:image/jpeg;base64,$base64Image';

        final result = await _apiService.updateAvatar(_currentUser!.id, avatarData);

        if (result['success']) {
          final updatedUser = User.fromJson(result['data']);
          await _updateLocalUserData(updatedUser);
          
          setState(() {
            _currentUser = updatedUser;
          });

          widget.onUserUpdated(updatedUser);
          _profileNotifier.updateUser(updatedUser);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аватарка обновлена!')),
            );
          }
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError('Ошибка загрузки: $e');
      } finally {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showError('Имя не может быть пустым');
      return;
    }

    if (newName == _currentUser!.name) {
      _showError('Новое имя должно отличаться от текущего');
      return;
    }

    setState(() {
      _isUpdatingName = true;
    });

    try {
      final result = await _apiService.updateUserName(_currentUser!.id, newName);

      if (result['success']) {
        final updatedUser = User.fromJson(result['data']);
        await _updateLocalUserData(updatedUser);
        
        setState(() {
          _currentUser = updatedUser;
        });

        widget.onUserUpdated(updatedUser);
        _profileNotifier.updateUser(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Имя обновлено!')),
          );
        }
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Ошибка обновления: $e');
    } finally {
      setState(() {
        _isUpdatingName = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('Новые пароли не совпадают');
      return;
    }

    if (newPassword.length < _minPasswordLength) {
      _showError('Новый пароль должен содержать минимум $_minPasswordLength символов');
      return;
    }

    if (currentPassword.length < _minPasswordLength) {
      _showError('Текущий пароль должен содержать минимум $_minPasswordLength символов');
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final result = await _apiService.changePassword(
        _currentUser!.id,
        currentPassword,
        newPassword,
      );

      if (result['success']) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароль успешно изменен!')),
          );
        }
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Ошибка смены пароля: $e');
    } finally {
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  Future<void> _updateLocalUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(user.toJson()));
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final cardColor = isDarkMode ? const Color(0xFF1f2937) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки профиля'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAvatarSection(cardColor, textColor),
            const SizedBox(height: 32),
            _buildNameSection(cardColor, textColor),
            const SizedBox(height: 32),
            _buildPasswordSection(cardColor, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Color cardColor, Color textColor) {
    final avatarText = _currentUser!.name.isNotEmpty ? _currentUser!.name[0].toUpperCase() : '';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('Аватарка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _currentUser?.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 48,
                      backgroundImage: MemoryImage(
                        base64Decode(_currentUser!.avatarUrl!.split(',')[1]),
                      ),
                    )
                  : CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(avatarText, style: TextStyle(fontSize: 48, color: Colors.indigo.shade800)),
                    ),
              Positioned(
                bottom: 0, right: -4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.indigo,
                  child: _isUpdatingAvatar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(LucideIcons.edit3, size: 16, color: Colors.white),
                          onPressed: _updateAvatar,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isUpdatingAvatar ? null : _updateAvatar,
            icon: const Icon(LucideIcons.upload),
            label: const Text('Изменить аватарку'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(Color cardColor, Color textColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Имя', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Введите ваше имя',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdatingName ? null : _updateName,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: _isUpdatingName
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Сохранить имя'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(Color cardColor, Color textColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Смена пароля', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Текущий пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Новый пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Подтвердите новый пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Изменить пароль'),
            ),
          ),
        ],
      ),
    );
  }
}
