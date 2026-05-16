import 'package:flutter/material.dart';
import 'dart:io';
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
  AppThemeSetting _themeSetting = AppThemeSetting.dark;

  String _homeDir() => Platform.environment['HOME'] ?? '';

  String _joinPath(List<String> parts) =>
      parts.where((p) => p.isNotEmpty).join(Platform.pathSeparator);

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

  @override
  void initState() {
    super.initState();
    _initThemeOnBoot();
  }

  Future<void> _initThemeOnBoot() async {
    final settings = await _readSettings();
    final mode = settings['theme_mode'] ?? 'dark';
    if (mode == 'light') {
      setState(() => _themeSetting = AppThemeSetting.light);
    } else if (mode == 'rose_pine_dawn') {
      setState(() => _themeSetting = AppThemeSetting.rosePineDawn);
    } else {
      setState(() => _themeSetting = AppThemeSetting.dark);
    }
  }

  // Cycle theme: Dark → Light → Rose Pine Dawn → Dark
  Future<void> _cycleTheme() async {
    final settings = await _readSettings();

    if (_themeSetting == AppThemeSetting.dark) {
      setState(() => _themeSetting = AppThemeSetting.light);
      settings['theme_mode'] = 'light';
    } else if (_themeSetting == AppThemeSetting.light) {
      setState(() => _themeSetting = AppThemeSetting.rosePineDawn);
      settings['theme_mode'] = 'rose_pine_dawn';
    } else {
      setState(() => _themeSetting = AppThemeSetting.dark);
      settings['theme_mode'] = 'dark';
    }

    await _writeSettings(settings);
  }

  IconData get _currentThemeIcon {
    switch (_themeSetting) {
      case AppThemeSetting.dark:
        return Icons.dark_mode_rounded;
      case AppThemeSetting.light:
        return Icons.light_mode_rounded;
      case AppThemeSetting.rosePineDawn:
        return Icons.palette_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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
    };

    return MaterialApp(
      title: 'EverCal',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      home: CalendarHome(
        onThemeToggle: _cycleTheme,
        currentIcon: _currentThemeIcon,
      ),
    );
  }
}
