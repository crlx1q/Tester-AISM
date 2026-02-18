import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';

import 'screens/auth_screen.dart';
import 'screens/home_page_new.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_page.dart';
import 'screens/recorder_page.dart';
import 'screens/tutor_page.dart';
import 'screens/todo_list_page.dart';
import 'services/background_recording_service.dart';
import 'services/notification_service.dart';
import 'services/connection_service.dart';
import 'services/api_service.dart';
import 'services/profile_notifier.dart';
import 'services/update_service.dart';
import 'services/update_notifier.dart';
import 'services/theme_service.dart';
import 'providers/stats_provider.dart';
import 'providers/notebook_provider.dart';
import 'providers/planner_provider.dart';
import 'providers/insights_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/todo_provider.dart';
import 'models/user_model.dart';
import 'widgets/overlay_timer_widget.dart';
import 'services/focus_overlay_manager.dart';
import 'services/focus_timer_service.dart';

// Entry point для плавающего окна
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayTimerWidget(),
    ),
  );
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Wrap initialization in try-catch to prevent black screen on errors
  try {
    // Initialize services with error handling
    await NotificationService().initialize().catchError((e) {
      print('NotificationService initialization error: $e');
    });

    await BackgroundRecordingService.initialize().catchError((e) {
      print('BackgroundRecordingService initialization error: $e');
    });

    await UpdateNotifier().initialize().catchError((e) {
      print('UpdateNotifier initialization error: $e');
    });

    await ThemeService().init().catchError((e) {
      print('ThemeService initialization error: $e');
    });

    await FocusTimerService().initialize().catchError((e) {
      print('FocusTimerService initialization error: $e');
    });

    // Initialize date formatting for Russian locale
    await initializeDateFormatting('ru_RU', null).catchError((e) {
      print('Date formatting initialization error: $e');
    });
  } catch (e) {
    // Log any errors but continue to run the app
    print('Main initialization error: $e');
  }

  // Always run the app, even if some services failed to initialize
  runApp(const AIStudyMateApp());
}

class AIStudyMateApp extends StatefulWidget {
  const AIStudyMateApp({super.key});

  @override
  State<AIStudyMateApp> createState() => _AIStudyMateAppState();
}

class _AIStudyMateAppState extends State<AIStudyMateApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Use default text theme as fallback
    TextTheme lightTextTheme;
    TextTheme darkTextTheme;

    try {
      // Try to use Google Fonts, but have a fallback
      lightTextTheme = GoogleFonts.interTextTheme();
      darkTextTheme = GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      );
    } catch (e) {
      print('Google Fonts error: $e');
      // Fallback to default Flutter fonts
      lightTextTheme = ThemeData.light().textTheme;
      darkTextTheme = ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileNotifier()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => NotebookProvider()),
        ChangeNotifierProvider(create: (_) => PlannerProvider()),
        ChangeNotifierProvider(create: (_) => InsightsProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: MaterialApp(
        title: 'AI-StudyMate',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
        ],
        locale: const Locale('ru', 'RU'),
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          textTheme: lightTextTheme,
          scaffoldBackgroundColor: const Color(0xFFF3F4F6), // gray-100
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.indigo,
          textTheme: darkTextTheme,
          scaffoldBackgroundColor: const Color(0xFF111827), // gray-900
        ),
        themeMode: _themeService.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          final overlay = brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
                  .copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark
                  .copyWith(statusBarColor: Colors.transparent);

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

enum AppStatus { loading, splash, onboarding, auth, app }

class _AppShellState extends State<AppShell> {
  AppStatus _appStatus = AppStatus.loading;
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  final ProfileNotifier _profileNotifier = ProfileNotifier();
  final UpdateService _updateService = UpdateService();
  final UpdateNotifier _updateNotifier = UpdateNotifier();
  bool _isCheckingUpdates = false;
  bool _hasShownUpdateNotification = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _updateService.startListening(_handleUpdateStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _initFocusOverlay();
    });
  }

  void _initFocusOverlay() {
    // Слушаем изменения состояния таймера и показываем/скрываем overlay
    final focusProvider = context.read<FocusProvider>();
    focusProvider.addListener(() {
      if (!mounted) return;

      // Проверяем, не находимся ли мы на экране FocusPage
      final currentRoute = ModalRoute.of(context);
      final isOnFocusPage = currentRoute?.settings.name == '/focus' ||
          currentRoute?.settings.arguments.toString().contains('FocusPage') ==
              true;

      if (focusProvider.timerState != FocusTimerState.idle) {
        // Показываем только если не на экране FocusPage
        if (!FocusOverlayManager.isShowing && !isOnFocusPage) {
          FocusOverlayManager.show(context, focusProvider);
        }
      } else {
        if (FocusOverlayManager.isShowing) {
          FocusOverlayManager.hide();
        }
      }
    });
  }

  Future<void> _checkStatus() async {
    try {
      // Show splash screen immediately
      if (mounted) setState(() => _appStatus = AppStatus.splash);

      // Load data in background with timeout
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding =
          prefs.getBool('hasSeenOnboarding') ?? false;

      if (!hasSeenOnboarding) {
        // Minimum splash duration to avoid flicker
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _appStatus = AppStatus.onboarding);
      } else {
        final String? userData = prefs.getString('userData');

        if (userData != null) {
          // Add timeout for fetching user data to prevent infinite loading
          final freshUserMap = await _fetchUserData(userData).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('User data fetch timeout, using cached data');
              try {
                return Map<String, dynamic>.from(jsonDecode(userData));
              } catch (e) {
                print('Failed to decode cached user data: $e');
                return null;
              }
            },
          );

          if (freshUserMap != null) {
            try {
              final user = User.fromJson(freshUserMap);
              await prefs.setString('userData', jsonEncode(user.toJson()));
              _profileNotifier.updateUser(user);

              if (mounted) setState(() => _appStatus = AppStatus.app);
              // Проверяем подключение к серверу после входа в приложение
              if (mounted) {
                ConnectionService.checkConnectionAndNotify(context);
                _checkForUpdates();
              }
            } catch (e) {
              print('Failed to parse user data: $e');
              await prefs.remove('userData');
              if (mounted) setState(() => _appStatus = AppStatus.auth);
            }
          } else {
            // Аккаунт не найден на сервере - выходим
            await prefs.remove('userData');
            if (mounted) setState(() => _appStatus = AppStatus.auth);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Аккаунт не найден. Войдите заново.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          if (mounted) setState(() => _appStatus = AppStatus.auth);
        }
      }
    } catch (e) {
      // If anything goes wrong, at least show the auth screen
      print('Critical error in _checkStatus: $e');
      if (mounted) setState(() => _appStatus = AppStatus.auth);
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userDataString) async {
    Map<String, dynamic> localData;

    try {
      localData = Map<String, dynamic>.from(jsonDecode(userDataString));
    } catch (e) {
      print('Failed to decode local user data: $e');
      return null;
    }

    final userId = localData['id'];
    if (userId == null) {
      return null;
    }

    try {
      final result = await _apiService.getUserProfile(userId);
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(result['data']);
      }

      final message = (result['message'] ?? '').toString();
      if (message.contains('Пользователь не найден')) {
        return null;
      }

      // В случае других ошибок (например, сервер недоступен) используем локальные данные
      return localData;
    } catch (e) {
      print('Account fetch error: $e');
      // В случае ошибок сети используем локальные данные
      return localData;
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    setState(() => _appStatus = AppStatus.auth);
  }

  void _finishAuth() {
    setState(() => _appStatus = AppStatus.app);
  }

  void _signOut() {
    _profileNotifier.clearUser();
    setState(() {
      _appStatus = AppStatus.auth;
    });
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    _isCheckingUpdates = true;
    try {
      final status = await _updateService.fetchStatus();
      _handleUpdateStatus(status);
    } catch (e) {
      debugPrint('Update check failed: $e');
    } finally {
      _isCheckingUpdates = false;
    }
  }

  Future<void> _handleUpdateStatus(UpdateStatus status) async {
    _updateNotifier.updateStatus(status);

    if (!status.serverReachable) {
      return;
    }

    final update = status.availableUpdate;
    if (update == null) {
      return;
    }

    if (status.viaPush || !_hasShownUpdateNotification) {
      await NotificationService().showUpdateAvailableNotification(update);
      _hasShownUpdateNotification = true;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_appStatus) {
      case AppStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppStatus.splash:
        return const SplashScreen();
      case AppStatus.onboarding:
        return OnboardingScreen(onCompleted: _finishOnboarding);
      case AppStatus.auth:
        return AuthScreen(onSignedIn: _finishAuth);
      case AppStatus.app:
        return WillPopScope(
          onWillPop: () async {
            if (_selectedIndex != 0) {
              setState(() {
                _selectedIndex = 0; // Go back to Home tab instead of exiting
              });
              return false; // Prevent app from closing
            }
            return true; // Allow default behavior (exit) when already on Home
          },
          child: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: <Widget>[
                HomePageNew(
                  onOpenProfile: () => _onItemTapped(4),
                  onOpenRecorder: () => _onItemTapped(1),
                  onOpenTutor: () => _onItemTapped(2),
                  updateNotifier: _updateNotifier,
                ),
                const RecorderPage(),
                const TutorPage(),
                const TodoListPage(),
                ProfilePage(onSignedOut: _signOut),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(LucideIcons.home), label: 'Главная'),
                BottomNavigationBarItem(
                    icon: Icon(LucideIcons.mic), label: 'Диктофон'),
                BottomNavigationBarItem(
                    icon: Icon(LucideIcons.bot), label: 'AI-Тьютор'),
                BottomNavigationBarItem(
                    icon: Icon(LucideIcons.listTodo), label: 'Задачи'),
                BottomNavigationBarItem(
                    icon: Icon(LucideIcons.user), label: 'Профиль'),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType
                  .fixed, // Important for more than 3 items
              showSelectedLabels: false,
              showUnselectedLabels: false,
            ),
          ),
        );
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage('assets/images/logo.png'),
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'AI-StudyMate',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Загрузка...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
