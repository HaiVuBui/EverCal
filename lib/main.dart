/// main.dart
///
/// The entry point of the application.
/// Configures the MaterialApp, Themes, and the FileWatcher for auto-theme.
/// Binds the Home Screen.

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'models.dart';
import 'home_screen.dart';

void main() {
  runApp(const MyCalendarApp());
}

class MyCalendarApp extends StatefulWidget {
  const MyCalendarApp({super.key});

  @override
  State<MyCalendarApp> createState() => _MyCalendarAppState();
}

class _MyCalendarAppState extends State<MyCalendarApp> {
  AppThemeSetting _themeSetting = AppThemeSetting.auto; //Default setting
  ThemeMode _effectiveThemeMode = ThemeMode.dark; // Default theme
  StreamSubscription<FileSystemEvent>? _themeFileSubscription;
  WeatherUnit _weatherUnit = WeatherUnit.celsius; // Default weather unit

  String get _stateFilePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.cache/quickshell/theme_mode';
  }

  @override
  void initState() {
    super.initState();
    _initThemeOnBoot();
  }

  @override
  void dispose() {
    _stopWatchingTheme();
    super.dispose();
  }
// ------------------------------------------------------------------------------------------------------------------------------------
  //  I/O helpers for scope issues
  String _homeDir() => Platform.environment['HOME'] ?? '';

  String _joinPath(List<String> parts) {
    final sep = Platform.pathSeparator;
    return parts.where((p) => p.isNotEmpty).join(sep);
  }

  Directory _baseDir() =>
      Directory(_joinPath([_homeDir(), 'Documents', 'EverCal']));
  File _settingsFile() => File(_joinPath([_baseDir().path, 'settings.json']));

  Future<Map<String, dynamic>> _readSettings() async {
    try {
      final f = _settingsFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> _writeSettings(Map<String, dynamic> settings) async {
    try {
      final dir = _baseDir();
      if (!await dir.exists()) await dir.create(recursive: true);
      await _settingsFile().writeAsString(json.encode(settings));
    } catch (_) {}
  }
// ------------------------------------------------------------------------------------------------------------------------------------
  // Theme states are persistent
  Future<void> _initThemeOnBoot() async {
    
    // Check JSON settings first
    final settings = await _readSettings();
    final mode = settings['theme_mode'] ?? 'auto';
    final savedUnit = settings['weather_unit'];
    if (savedUnit == 'fahrenheit')
      _weatherUnit = WeatherUnit.fahrenheit;
    else if (savedUnit == 'kelvin')
      _weatherUnit = WeatherUnit.kelvin;
    else
      _weatherUnit = WeatherUnit.celsius;

    // Load View Mode
    final savedView = settings['calendar_view'];
    
    if (mode == 'light') {
      _applyManualTheme(AppThemeSetting.light, ThemeMode.light);
    } else if (mode == 'rose_pine_dawn') {
      _applyManualTheme(AppThemeSetting.rosePineDawn, ThemeMode.light);
    } else if (mode == 'dark') {
      _applyManualTheme(AppThemeSetting.dark, ThemeMode.dark);
    } else {
      // if 'auto'-- defer to the file watcher
      setState(() => _themeSetting = AppThemeSetting.auto);
      _startWatchingTheme();
    }
  }

  // Cycle theme: Dark - Light - Rose Pine Dawn - Auto - Dark
  Future<void> _cycleTheme() async {
    final settings = await _readSettings();

    if (_themeSetting == AppThemeSetting.dark) {
      _applyManualTheme(AppThemeSetting.light, ThemeMode.light);
      settings['theme_mode'] = 'light';
    } else if (_themeSetting == AppThemeSetting.light) {
      _applyManualTheme(AppThemeSetting.rosePineDawn, ThemeMode.light);
      settings['theme_mode'] = 'rose_pine_dawn';
    } else if (_themeSetting == AppThemeSetting.rosePineDawn) {
      setState(() => _themeSetting = AppThemeSetting.auto);
      _startWatchingTheme();
      settings['theme_mode'] = 'auto';
    } else {
      _applyManualTheme(AppThemeSetting.dark, ThemeMode.dark);
      settings['theme_mode'] = 'dark';
    }

    await _writeSettings(settings);
  }

  void _applyManualTheme(AppThemeSetting setting, ThemeMode mode) {
    _stopWatchingTheme();
    setState(() {
      _themeSetting = setting;
      _effectiveThemeMode = mode;
    });
  }

// Auto Mode (from File Watcher)
  void _startWatchingTheme() {
    _readStateFile(); // Read immediately
// Watch for changes
    final file = File(_stateFilePath);
    _themeFileSubscription?.cancel();

    // if state file doesn't exist, fall back to dark (and don't watch)
    try {
      if (!file.existsSync()) {
        if (mounted) setState(() => _effectiveThemeMode = ThemeMode.dark);
        return;
      }
      _themeFileSubscription =
          file.watch(events: FileSystemEvent.modify).listen((event) async {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) _readStateFile();
      });
    } catch (_) {
      if (mounted) setState(() => _effectiveThemeMode = ThemeMode.dark);
    }
  }

  void _stopWatchingTheme() {
    _themeFileSubscription?.cancel();
    _themeFileSubscription = null;
  }

  Future<void> _readStateFile() async {
    try {
      final file = File(_stateFilePath);
    
    // Missing file = dark
      if (!await file.exists()) {
        setState(() => _effectiveThemeMode = ThemeMode.dark);
        return;
      }
      final content = await file.readAsString();
      final trimmed = content.trim().toLowerCase();
      setState(() {
        if (trimmed == 'light') {
          _effectiveThemeMode = ThemeMode.light;
        } else {
          // Default to dark for 'dark' or any error
          _effectiveThemeMode = ThemeMode.dark;
        }
      });
    } catch (_) {
      // Fail to dark if permissions/path error
      setState(() => _effectiveThemeMode = ThemeMode.dark);
    }
  }
  
// ------------------------------------------------------------------------------------------------------------------------------------
 // HELPER: Get Icon based on setting
  IconData get _currentThemeIcon {
    switch (_themeSetting) {
      case AppThemeSetting.dark:
        return Icons.dark_mode_rounded;
      case AppThemeSetting.light:
        return Icons.light_mode_rounded;
      case AppThemeSetting.rosePineDawn:
        return Icons.palette_rounded;
      case AppThemeSetting.auto:
        return Icons.brightness_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // DARK THEME
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Manrope',
      colorScheme: const ColorScheme.dark(
        background: Color(0xFF232a2e),
        surface: Color(0xFF2d353b),
        surfaceVariant: Color(0xFF3d484f),
        onSurfaceVariant: Color(0xFF859289),
        primary: Color(0xFFa7c080),
        primaryContainer: Color(0xFF425047),
        secondary: Color(0xFFd699b6),
        tertiary: Color(0xFF7fbbb3),
        onBackground: Color(0xFFd3c6aa),
        onSurface: Color(0xFFd3c6aa),
        onPrimary: Color(0xFF2d353b),
        onPrimaryContainer: Color(0xFFd3c6aa),
        error: Color(0xFFe67e80),
        outline: Color(0xFF4b565c),
      ),
      scaffoldBackgroundColor: const Color(0xFF232a2e),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF3d484f).withOpacity(0.5),
        thickness: 1,
      ),
    );

    // LIGHT THEME
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      colorScheme: const ColorScheme.light(
        background: Color(0xFFbec5b2),
        surface: Color(0xFFeaedc8),
        surfaceVariant: Color(0xFFf0f2d4),
        onSurfaceVariant: Color(0xFF5C6A72),
        primary: Color(0xFF8da165),
        primaryContainer: Color(0xFFdce3b8),
        secondary: Color(0xFFd699b6),
        tertiary: Color(0xFF7fbbb3),
        onBackground: Color(0xFF1e2326),
        onSurface: Color(0xFF1e2326),
        onPrimary: Color(0xFFeaedc8),
        onPrimaryContainer: Color(0xFF1e2326),
        error: Color(0xFFe67e80),
        outline: Color(0xFF939f91),
      ),
      scaffoldBackgroundColor: const Color(0xFFbec5b2),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF939f91).withOpacity(0.5),
        thickness: 1,
      ),
    );

    final rosePineDawnTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      colorScheme: const ColorScheme.light(
        background: Color(0xFFFAF4ED),
        surface: Color(0xFFF2E9E1),
        surfaceVariant: Color(0xFFECE1D8),
        onSurfaceVariant: Color(0xFF797593),
        primary: Color(0xFF286983),
        primaryContainer: Color(0xFFDCEAF0),
        secondary: Color(0xFFD7827E),
        tertiary: Color(0xFF907AA9),
        onBackground: Color(0xFF575279),
        onSurface: Color(0xFF575279),
        onPrimary: Color(0xFFFAF4ED),
        onPrimaryContainer: Color(0xFF575279),
        error: Color(0xFFB4637A),
        outline: Color(0xFFD4C8BE),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF4ED),
      dividerTheme: DividerThemeData(
        color: const Color(0xFFD4C8BE).withOpacity(0.5),
        thickness: 1,
      ),
    );

    final activeTheme = switch (_themeSetting) {
      AppThemeSetting.dark => darkTheme,
      AppThemeSetting.light => lightTheme,
      AppThemeSetting.rosePineDawn => rosePineDawnTheme,
      AppThemeSetting.auto =>
        _effectiveThemeMode == ThemeMode.dark ? darkTheme : lightTheme,
    };

    return MaterialApp(
      title: 'EverCal',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      home: CalendarHome(
        onThemeToggle: _cycleTheme,
        isDarkMode: activeTheme.brightness == Brightness.dark,
        currentIcon: _currentThemeIcon,
      ),
    );
  }
}
