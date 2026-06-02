/// home_screen.dart
///
/// Contains the main Stateful implementation of the Calendar:
/// file I/O, parsing (ICS/JSON/Khal), recurrence generation,
/// weather fetching, and layout management.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'utils.dart';
import 'components.dart';
import 'calendar_views.dart';
import 'dialogs.dart';

class CalendarHome extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final IconData currentIcon;

  const CalendarHome({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.currentIcon,
  });

  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome> {
  late DateTime _selectedDate;
  DateTime _focusedMonth = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month; // Default view (month)

  Map<DateTime, List<CalendarEvent>> _events = {};
  List<TodoItem> _todos = [];
  List<GoalItem> _goals = [];
  SidebarTab _sidebarTab = SidebarTab.events;

  WeatherData? _weather;
  bool _isLoading = true;
  String? _errorMessage;
  WeatherUnit _weatherUnit = WeatherUnit.celsius;

  bool _weekStartsMonday = false;
  bool _use24Hour = false;
  Set<String> _hiddenCalendarPaths = {};
  List<String> _calendarPaths = [];
  CalendarEvent? _lastDeletedEvent;

  // At Startup (the default scroll position)
  final ScrollController _weekScrollController =
      ScrollController(initialScrollOffset: 520); // 9 AM = 9 * 60

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadEvents();
    _loadWeather();
    _loadTodos();
    _loadGoals();
  }

  // Stable hash (FNV-1a 32-bit) for deterministic IDs
  String _fnv1aHex(String input) {
    const int fnvPrime = 16777619;
    const int offsetBasis = 2166136261;
    int hash = offsetBasis;

    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _homeDir() => Platform.environment['HOME'] ?? '';

  String _joinPath(List<String> parts) {
    final sep = Platform.pathSeparator;
    return parts.where((p) => p.isNotEmpty).join(sep);
  }

  Directory _baseDir() =>
      Directory(_joinPath([_homeDir(), 'Documents', 'EverCal']));
  File _settingsFile() => File(_joinPath([_baseDir().path, 'settings.json']));
  File _todosFile() => File(_joinPath([_baseDir().path, 'todos.json']));
  File _goalsFile() => File(_joinPath([_baseDir().path, 'goals.json']));

  Future<void> _ensureDirs() async {
    if (!await _baseDir().exists()) await _baseDir().create(recursive: true);
  }

  String _normDir(String path) {
    final sep = Platform.pathSeparator;
    var p = path;
    while (p.length > 1 && p.endsWith(sep)) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  String _basename(String path) {
    final sep = Platform.pathSeparator;
    final parts = _normDir(path).split(sep);
    return parts.isEmpty ? path : parts.last;
  }

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
      await _settingsFile().writeAsString(json.encode(settings));
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Toggle View Mode
  Future<void> _toggleViewMode() => _setViewMode(
        _viewMode == CalendarViewMode.month
            ? CalendarViewMode.week
            : CalendarViewMode.month,
      );

  // Weather with configurable temperature units
  Future<void> _loadWeather() async {
    try {
      // Load Settings & Unit
      final settings = await _readSettings();

      // Load View Mode
      final savedView = settings['calendar_view'];
      if (savedView == 'week') {
        _viewMode = CalendarViewMode.week;
      } else {
        _viewMode = CalendarViewMode.month;
      }

      // Restore Unit
      final savedUnit = settings['weather_unit'];
      if (savedUnit == 'fahrenheit') {
        _weatherUnit = WeatherUnit.fahrenheit;
      } else if (savedUnit == 'kelvin') {
        _weatherUnit = WeatherUnit.kelvin;
      } else {
        _weatherUnit = WeatherUnit.celsius;
      }

      _weekStartsMonday = settings['week_starts_monday'] == true;
      _use24Hour = settings['use_24hour'] == true;

      final hiddenList = settings['hidden_calendars'];
      if (hiddenList is List) {
        _hiddenCalendarPaths =
            hiddenList.whereType<String>().map(_normDir).toSet();
      }

      double? lat;
      double? lon;

      if (settings['weather_lat'] != null && settings['weather_lon'] != null) {
        lat = settings['weather_lat'];
        lon = settings['weather_lon'];
      } else {
        // Auto-detect via IP
        try {
          final ipRes = await http.get(Uri.parse('http://ip-api.com/json'));
          if (ipRes.statusCode == 200) {
            final data = json.decode(ipRes.body);
            lat = (data['lat'] as num).toDouble();
            lon = (data['lon'] as num).toDouble();
          }
        } catch (_) {}
      }

      // If nothing works enjoy Toronto's weather
      lat ??= 43.6617;
      lon ??= -79.3951;

      // Fetch Weather
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&temperature_unit=celsius';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current']['temperature_2m'];
        final code = data['current']['weather_code'];

        String desc = 'Clear';
        IconData icon = Icons.wb_sunny_rounded;

        if (code <= 1) {
          desc = 'Clear Sky';
          icon = Icons.wb_sunny_rounded;
        } else if (code <= 3) {
          desc = 'Partly Cloudy';
          icon = Icons.cloud_rounded;
        } else if (code <= 48) {
          desc = 'Foggy';
          icon = Icons.dehaze_rounded;
        } else if (code <= 65) {
          desc = 'Rain';
          icon = Icons.grain_rounded;
        } else if (code <= 75) {
          desc = 'Snow';
          icon = Icons.ac_unit_rounded;
        } else if (code <= 99) {
          desc = 'Thunderstorm';
          icon = Icons.thunderstorm_rounded;
        }

        if (mounted) {
          setState(() {
            _weather = WeatherData(
              temp: (temp as num).toDouble(),
              description: desc,
              icon: icon,
            );
          });
        }
      }
    } catch (_) {
      /* silent fail */
    }
  }

  Future<void> _showLocationSearch() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return LocationSettingsDialog(currentUnit: _weatherUnit);
        },
      ),
    );

    if (result == null) return;

    // PROCESS RESULTS
    final settings = await _readSettings();
    bool needsRefresh = false;

    // Save Unit
    if (result['unit'] is WeatherUnit) {
      _weatherUnit = result['unit'];
      settings['weather_unit'] = _weatherUnit.name;
      setState(() {});
    }

    // For Auto-Detect Flag
    if (result['useAuto'] == true) {
      settings.remove('weather_lat');
      settings.remove('weather_lon');
      needsRefresh = true;
      _snack('Set to Auto-Location');
    }
    // City Search
    else if (result['city'] != null && result['city'].toString().isNotEmpty) {
      final cityName = result['city'];
      try {
        final url =
            'https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=1&format=json';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['results'] != null && data['results'].isNotEmpty) {
            final loc = data['results'][0];
            settings['weather_lat'] = loc['latitude'];
            settings['weather_lon'] = loc['longitude'];
            needsRefresh = true;
            _snack('Location set to ${loc['name']}');
          } else {
            _snack('City not found');
          }
        }
      } catch (_) {}
    }

    await _writeSettings(settings);
    if (needsRefresh) _loadWeather();
  }

  // Load + merge events
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _ensureDirs();

      _events = await _loadKhalEventsFromVdir();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading calendar: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodos() async {
    try {
      await _ensureDirs();
      final f = _todosFile();
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final decoded = json.decode(raw);
      if (decoded is List) {
        setState(() {
          _todos = decoded
              .whereType<Map<String, dynamic>>()
              .map(TodoItem.fromJson)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTodos() async {
    try {
      await _todosFile()
          .writeAsString(json.encode(_todos.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  void _addTodo(String title, String? linkedEventId) {
    final now = DateTime.now();
    final id = 'todo_${_fnv1aHex('todo|$title|${now.toIso8601String()}')}';
    setState(() {
      _todos.add(TodoItem(
        id: id,
        title: title,
        linkedEventId: linkedEventId,
        createdAt: now,
      ));
    });
    _saveTodos();
  }

  void _toggleTodo(String id) {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    setState(() {
      _todos[idx] = _todos[idx].copyWith(isCompleted: !_todos[idx].isCompleted);
    });
    _saveTodos();
  }

  void _deleteTodo(String id) {
    setState(() => _todos.removeWhere((t) => t.id == id));
    _saveTodos();
  }

  void _linkTodoEvent(String todoId, String? eventId) {
    final idx = _todos.indexWhere((t) => t.id == todoId);
    if (idx == -1) return;
    setState(() {
      _todos[idx] = _todos[idx]
          .copyWith(linkedEventId: eventId, clearLink: eventId == null);
    });
    _saveTodos();
  }

  void _reorderTodos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final t = _todos.removeAt(oldIndex);
      _todos.insert(newIndex, t);
    });
    _saveTodos();
  }

  void _editTodo(String id, String newTitle) {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    setState(() {
      _todos[idx] = _todos[idx].copyWith(title: newTitle);
    });
    _saveTodos();
  }

  Future<void> _loadGoals() async {
    try {
      await _ensureDirs();
      final f = _goalsFile();
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final decoded = json.decode(raw);
      if (decoded is List) {
        setState(() {
          _goals = decoded
              .whereType<Map<String, dynamic>>()
              .map(GoalItem.fromJson)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveGoals() async {
    try {
      await _goalsFile()
          .writeAsString(json.encode(_goals.map((g) => g.toJson()).toList()));
    } catch (_) {}
  }

  void _addGoal(GoalItem goal) {
    setState(() => _goals.add(goal));
    _saveGoals();
  }

  void _toggleGoal(String id) {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    setState(() => _goals[idx] = _goals[idx].copyWith(isCompleted: !_goals[idx].isCompleted));
    _saveGoals();
  }

  void _deleteGoal(String id) {
    setState(() => _goals.removeWhere((g) => g.id == id));
    _saveGoals();
  }

  void _editGoal(String id, GoalItem updated) {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    setState(() => _goals[idx] = updated);
    _saveGoals();
  }

  List<GoalItem> get _sortedGoals {
    final dated = <GoalItem>[], undated = <GoalItem>[];
    for (final g in _goals) {
      (g.date != null ? dated : undated).add(g);
    }
    dated.sort((a, b) {
      final dayA = DateTime(a.date!.year, a.date!.month, a.date!.day);
      final dayB = DateTime(b.date!.year, b.date!.month, b.date!.day);
      final cmp = dayA.compareTo(dayB);
      if (cmp != 0) return cmp;
      if (a.hasTime != b.hasTime) return a.hasTime ? -1 : 1;
      if (a.hasTime) return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
      return 0;
    });
    undated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [...dated, ...undated];
  }

  Map<DateTime, List<CalendarEvent>> _addGoalsToEvents(
      Map<DateTime, List<CalendarEvent>> base) {
    if (_goals.every((g) => g.isCompleted || g.date == null)) return base;
    final result = <DateTime, List<CalendarEvent>>{};
    for (final entry in base.entries) {
      result[entry.key] = List.from(entry.value);
    }
    final modifiedDays = <DateTime>{};
    for (final goal in _goals) {
      if (goal.isCompleted || goal.date == null) continue;
      final start = goal.hasTime
          ? DateTime(goal.date!.year, goal.date!.month, goal.date!.day, goal.hour, goal.minute)
          : DateTime(goal.date!.year, goal.date!.month, goal.date!.day);
      final dayKey = _normalizeDate(start);
      result.putIfAbsent(dayKey, () => []).add(CalendarEvent(
        id: 'goal_${goal.id}',
        title: goal.title,
        startTime: start,
        endTime: goal.hasTime ? start.add(const Duration(hours: 1)) : start,
        sourceId: 'goal:${goal.id}',
        isAllDay: !goal.hasTime,
      ));
      modifiedDays.add(dayKey);
    }
    for (final day in modifiedDays) {
      result[day]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return result;
  }

  // Khal Utils

  String _xdgConfigHome() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.trim().isNotEmpty) return xdg.trim();
    return _joinPath([_homeDir(), '.config']);
  }

  Future<File?> _findKhalConfigFile() async {
    final cfgHome = _xdgConfigHome();
    final candidates = [
      _joinPath([cfgHome, 'khal', 'config']),
      _joinPath([cfgHome, 'khal', 'config.ini']),
      _joinPath([_homeDir(), '.khal', 'khal.conf']),
    ];

    for (final p in candidates) {
      final f = File(p);
      if (await f.exists()) return f;
    }
    return null;
  }

  List<String> _extractKhalCalendarPaths(List<String> lines) {
    final out = <String>[];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';'))
        continue;

      final m = RegExp(r'^\s*path\s*=\s*(.+)$', caseSensitive: false)
          .firstMatch(line);
      if (m != null) {
        var val = m.group(1)!.trim();
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        val = _expandHomeAndEnv(val);
        out.add(val);
      }
    }
    return out;
  }

  String _expandHomeAndEnv(String path) {
    var p = path.trim();
    final home = _homeDir();
    if (p.startsWith('~')) {
      p = home + p.substring(1);
    }
    p = p.replaceAll('\$HOME', home);
    p = p.replaceAll('{HOME}', home);
    p = p.replaceAll('\${HOME}', home);
    return p;
  }

  Future<List<String>> _expandCalendarPathPattern(String pathPattern) async {
    if (!pathPattern.contains('*') && !pathPattern.contains('?')) {
      return [pathPattern];
    }

    final sep = Platform.pathSeparator;
    final wildcardIndex = pathPattern.indexOf(RegExp(r'[\*\?]'));
    final lastSepBeforeWildcard = pathPattern.lastIndexOf(sep, wildcardIndex);
    if (lastSepBeforeWildcard == -1) return [];

    final parent = pathPattern.substring(0, lastSepBeforeWildcard);
    final patternSegment = pathPattern.substring(lastSepBeforeWildcard + 1);

    final parentDir = Directory(parent);
    if (!await parentDir.exists()) return [];

    final escaped = RegExp.escape(patternSegment)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    final rx = RegExp('^$escaped\$');

    final matches = <String>[];
    final entries =
        await parentDir.list(recursive: false, followLinks: false).toList();
    for (final ent in entries) {
      final name = _basename(ent.path);
      if (rx.hasMatch(name) && ent is Directory) {
        matches.add(ent.path);
      }
    }
    return matches;
  }

  Future<Map<DateTime, List<CalendarEvent>>> _loadKhalEventsFromVdir() async {
    final events = <DateTime, List<CalendarEvent>>{};
    final discoveredPaths = <String>[];
    try {
      final cfgFile = await _findKhalConfigFile();
      if (cfgFile == null) return events;

      final raw = await cfgFile.readAsLines();
      final paths = _extractKhalCalendarPaths(raw);

      final expanded = <String>[];
      for (final p in paths) {
        expanded.addAll(await _expandCalendarPathPattern(p));
      }

      final now = DateTime.now();
      final minViewable = DateTime(now.year - 1, 1, 1);
      final maxDate = DateTime(now.year + 2, 12, 31);

      final validFiles = <File>[];
      for (final calPath in expanded) {
        final dir = Directory(calPath);
        if (!await dir.exists()) continue;
        discoveredPaths.add(_normDir(calPath));

        final ents =
            await dir.list(recursive: false, followLinks: false).toList();
        validFiles.addAll(ents
            .whereType<File>()
            .where((e) => e.path.toLowerCase().endsWith('.ics')));
      }

      final contents = await Future.wait(validFiles.map((f) async {
        try {
          return await f.readAsString();
        } catch (_) {
          return null;
        }
      }));

      for (var i = 0; i < validFiles.length; i++) {
        final content = contents[i];
        if (content == null) continue;
        try {
          final parsed = _parseICS(
            content,
            sourceId: validFiles[i].path,
            minViewable: minViewable,
            maxDate: maxDate,
          );
          for (final list in parsed.values) {
            for (final event in list) {
              _addEventToMap(events, event.startTime, event);
            }
          }
        } catch (_) {}
      }
      for (final date in events.keys) {
        events[date]!.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
      _calendarPaths = discoveredPaths;
    } catch (_) {}
    return events;
  }

  Future<String?> _defaultKhalCalendarPath() async {
    final dir = Directory(_localKhalCalendarPath());
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  String _localKhalCalendarPath() =>
      _joinPath([_homeDir(), '.calendars', 'local']);

  bool _isLocalKhalEvent(CalendarEvent event) {
    final sourceId = event.sourceId;
    if (sourceId == null) return false;

    final localPath = _localKhalCalendarPath();
    return sourceId == localPath ||
        sourceId.startsWith('$localPath${Platform.pathSeparator}');
  }

  String _escapeIcsText(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');

  String _eventToIcs(CalendarEvent event) {
    final buffer = StringBuffer();
    buffer.writeln(
        'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//EverCal Khal Frontend//EN');
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:${event.id}');
    buffer.writeln('SUMMARY:${_escapeIcsText(event.title)}');
    buffer.writeln('DTSTART:${fmtIcsTime.format(event.startTime)}');
    buffer.writeln('DTEND:${fmtIcsTime.format(event.endTime)}');
    if (event.location != null && event.location!.isNotEmpty) {
      buffer.writeln('LOCATION:${_escapeIcsText(event.location!)}');
    }
    if (event.description != null && event.description!.isNotEmpty) {
      buffer.writeln('DESCRIPTION:${_escapeIcsText(event.description!)}');
    }
    if (event.rrule != null && event.rrule!.isNotEmpty) {
      buffer.writeln('RRULE:${event.rrule}');
    }
    for (final ex in event.exceptionDates) {
      buffer.writeln('EXDATE:${fmtIcsTime.format(ex)}');
    }
    buffer.writeln('END:VEVENT');
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  Future<File?> _writeKhalEvent(CalendarEvent event, {String? path}) async {
    final targetPath = path ?? event.sourceId;
    if (targetPath == null || targetPath.isEmpty) return null;

    final file = File(targetPath);
    await file.writeAsString(_eventToIcs(event));
    return file;
  }

  Future<void> _showAddMenu() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            return Container(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(widget.currentIcon,
                        color: theme.colorScheme.onSurfaceVariant),
                    title: const Text('Switch Theme'),
                    onTap: widget.onThemeToggle,
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.edit_calendar,
                        color: theme.colorScheme.primary),
                    title: const Text('Add Event'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddEventDialog();
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    secondary: const Icon(Icons.calendar_view_week_outlined),
                    title: const Text('Week starts on Monday'),
                    value: _weekStartsMonday,
                    onChanged: (val) {
                      setSheetState(() {});
                      _toggleWeekStart(val);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.schedule_outlined),
                    title: const Text('24-hour time'),
                    value: _use24Hour,
                    onChanged: (val) {
                      setSheetState(() {});
                      _toggleTimeFormat(val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddEventDialog({DateTime? initialDateTime}) async {
    final date = initialDateTime ?? _selectedDate;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AddEventDialog(
          initialSelectedDate: date,
          fnv1aHex: _fnv1aHex,
          onSave: _addEvent,
        ),
      ),
    );
  }

  Future<void> _showEditEventDialog(CalendarEvent event) async {
    if (!_isLocalKhalEvent(event)) {
      _snack('Only local khal events can be edited.');
      return;
    }

    if (event.isGenerated) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Edit recurring event', textAlign: TextAlign.center),
          content: const Text('Which events do you want to edit?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            OutlinedButton(
                onPressed: () => Navigator.pop(context, 'all'),
                child: const Text('All events')),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'this'),
                child: const Text('This event')),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'this') await _editThisOccurrence(event);
      if (choice == 'all') await _editAllOccurrences(event);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AddEventDialog(
          initialSelectedDate: event.startTime,
          existingEvent: event,
          fnv1aHex: _fnv1aHex,
          onSave: (date, updatedEvent) => _updateEvent(event, updatedEvent),
        ),
      ),
    );
  }

  CalendarEvent? _findMasterEvent(String sourceId) {
    for (final evts in _events.values) {
      for (final e in evts) {
        if (e.sourceId == sourceId && !e.isGenerated) return e;
      }
    }
    return null;
  }

  Future<void> _editThisOccurrence(CalendarEvent instance) async {
    CalendarEvent? edited;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AddEventDialog(
          initialSelectedDate: instance.startTime,
          existingEvent: instance.copyWith(rrule: null, isGenerated: false),
          fnv1aHex: _fnv1aHex,
          onSave: (_, ev) => edited = ev,
        ),
      ),
    );
    if (edited == null) return;

    // Add EXDATE to master ICS
    final masterPath = instance.sourceId;
    if (masterPath != null) {
      try {
        final f = File(masterPath);
        if (await f.exists()) {
          final content = await f.readAsString();
          final exdate = 'EXDATE:${fmtIcsTime.format(instance.startTime)}';
          await f.writeAsString(
              content.replaceFirst('END:VEVENT', '$exdate\nEND:VEVENT'));
        }
      } catch (_) {}
    }

    // Write new standalone event
    await _addEvent(edited!.startTime, edited!.copyWith(
      rrule: null,
      exceptionDates: const [],
      isGenerated: false,
    ));
  }

  Future<void> _editAllOccurrences(CalendarEvent instance) async {
    final master = _findMasterEvent(instance.sourceId ?? '');
    if (master == null) {
      _snack('Could not find the master event.');
      return;
    }
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AddEventDialog(
          initialSelectedDate: master.startTime,
          existingEvent: master,
          fnv1aHex: _fnv1aHex,
          onSave: (date, updated) => _updateEvent(master, updated),
        ),
      ),
    );
  }

  Future<void> _addEvent(DateTime date, CalendarEvent event) async {
    final calPath = await _defaultKhalCalendarPath();
    if (calPath == null) {
      _snack('No khal calendar directory found.');
      return;
    }

    final uid = event.id.startsWith('khal_')
        ? event.id
        : 'khal_${_fnv1aHex('${event.title}|'
            '${event.startTime.toIso8601String()}|'
            '${event.endTime.toIso8601String()}|'
            '${DateTime.now().microsecondsSinceEpoch}')}';
    final filePath = _joinPath([calPath, '$uid.ics']);
    final khalEvent = event.copyWith(
      id: uid,
      sourceId: filePath,
      isGenerated: false,
    );

    await _writeKhalEvent(khalEvent, path: filePath);
    await _loadEvents();
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _updateEvent(
      CalendarEvent originalEvent, CalendarEvent updatedEvent) async {
    if (!_isLocalKhalEvent(originalEvent)) {
      _snack('This calendar is read-only in EverCal.');
      return;
    }

    if (originalEvent.isGenerated) {
      _snack('Editing generated recurring instances is not supported yet.');
      return;
    }

    final path = originalEvent.sourceId;
    if (path == null || path.isEmpty) return;
    final khalEvent = updatedEvent.copyWith(
      id: originalEvent.id,
      sourceId: path,
      isGenerated: false,
    );
    await _writeKhalEvent(khalEvent, path: path);
    _selectedDate = _normalizeDate(khalEvent.startTime);
    _focusedMonth = _selectedDate;
    await _loadEvents();
  }

  Future<void> _deleteEvent(DateTime date, CalendarEvent event) async {
    if (!_isLocalKhalEvent(event)) {
      _snack('This calendar is read-only in EverCal.');
      return;
    }

    if (event.isGenerated) {
      _snack('Deleting generated recurring instances is not supported yet.');
      return;
    }

    final path = event.sourceId;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      _lastDeletedEvent = event;
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Event deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: _undoDelete),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      _snack('Error deleting khal event: $e');
    }
  }

  Future<void> _undoDelete() async {
    final event = _lastDeletedEvent;
    if (event == null) return;
    _lastDeletedEvent = null;
    final path = event.sourceId;
    if (path == null || path.isEmpty) return;
    await _writeKhalEvent(event, path: path);
    await _loadEvents();
  }

  // Calendar visibility helpers

  String _calendarDirForEvent(CalendarEvent event) {
    final src = event.sourceId;
    if (src == null) return '';
    return _normDir(File(src).parent.path);
  }

  Map<DateTime, List<CalendarEvent>> get _filteredEvents {
    final result = <DateTime, List<CalendarEvent>>{};
    for (final entry in _events.entries) {
      final filtered = entry.value
          .where((e) =>
              !e.isHidden &&
              (_hiddenCalendarPaths.isEmpty ||
                  !_hiddenCalendarPaths.contains(_calendarDirForEvent(e))))
          .toList();
      if (filtered.isNotEmpty) result[entry.key] = filtered;
    }
    return result;
  }

  Future<void> _patchSetting(String key, dynamic value) async {
    final settings = await _readSettings();
    settings[key] = value;
    await _writeSettings(settings);
  }

  Future<void> _toggleCalendar(String path, bool hide) async {
    setState(() {
      if (hide) _hiddenCalendarPaths.add(path);
      else _hiddenCalendarPaths.remove(path);
    });
    await _patchSetting('hidden_calendars', _hiddenCalendarPaths.toList());
  }

  // Navigation helpers

  void _goToToday() {
    setState(() {
      _selectedDate = _normalizeDate(DateTime.now());
      _focusedMonth = _selectedDate;
    });
  }

  void _shiftPeriod(int dir) {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + dir);
      } else {
        _focusedMonth = _focusedMonth.add(Duration(days: 7 * dir));
      }
    });
  }

  void _prevPeriod() => _shiftPeriod(-1);
  void _nextPeriod() => _shiftPeriod(1);

  Future<void> _setViewMode(CalendarViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await _patchSetting('calendar_view', mode.name);
  }

  // Settings toggles

  Future<void> _toggleWeekStart(bool value) async {
    setState(() => _weekStartsMonday = value);
    await _patchSetting('week_starts_monday', value);
  }

  Future<void> _toggleTimeFormat(bool value) async {
    setState(() => _use24Hour = value);
    await _patchSetting('use_24hour', value);
  }

  // Search

  Future<void> _showSearchDialog() async {
    await showDialog(
      context: context,
      builder: (context) => SearchDialog(
        events: _events,
        onDateSelected: (date) => setState(() {
          _selectedDate = date;
          _focusedMonth = date;
        }),
      ),
    );
  }

  // ICS Parsing

  List<String> _unfoldLines(String content) {
    if (content.isEmpty) return const [];
    final unfolded = <String>[];

    for (final raw in LineSplitter.split(content)) {
      var line = raw.replaceAll('\r', '');
      if (line.isEmpty) continue;

      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfolded.isNotEmpty) unfolded.last += line.trimLeft();
      } else {
        unfolded.add(line.trim());
      }
    }
    return unfolded;
  }

  Map<DateTime, List<CalendarEvent>> _parseICS(
    String content, {
    String? sourceId,
    DateTime? minViewable,
    DateTime? maxDate,
  }) {
    final events = <DateTime, List<CalendarEvent>>{};
    final lines = _unfoldLines(content);

    String? currentSummary;
    DateTime? currentStart;
    DateTime? currentEnd;
    String? currentLocation;
    String? currentDescription;
    String? currentUid;
    DateTime? currentRecurrenceId;
    String? rrule;
    bool currentIsAllDay = false;

    List<DateTime> currentExDates = [];
    bool inEvent = false;

    // Deterministic disambiguation
    final sigCounts = <String, int>{};
    final recurrenceOverridesByUid = <String, Set<DateTime>>{};
    final recurringMasters = <({CalendarEvent event, String? uid})>[];

    final now = DateTime.now();
    final localMin = minViewable ?? DateTime(now.year - 1, 1, 1);
    final localMax = maxDate ?? DateTime(now.year + 2, 12, 31);

    for (var line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        currentSummary = null;
        currentStart = null;
        currentEnd = null;
        currentLocation = null;
        currentDescription = null;
        currentUid = null;
        currentRecurrenceId = null;
        rrule = null;
        currentIsAllDay = false;

        currentExDates = [];
      } else if (line == 'END:VEVENT' && inEvent) {
        if (currentSummary != null && currentStart != null) {
          final endTime =
              currentEnd ?? currentStart!.add(const Duration(hours: 1));

          final uid = currentUid;
          final recurrenceId = currentRecurrenceId;
          if (uid != null && recurrenceId != null) {
            recurrenceOverridesByUid
                .putIfAbsent(uid, () => <DateTime>{})
                .add(recurrenceId);
          }

          final signature = uid != null && uid.isNotEmpty
              ? '${sourceId ?? "khal"}|$uid'
              : '${sourceId ?? "khal"}|${currentSummary!}|${currentStart!.toIso8601String()}|${endTime.toIso8601String()}|${currentLocation ?? ""}';
          final baseHash = _fnv1aHex(signature);

          final seen = (sigCounts[baseHash] ?? 0) + 1;
          sigCounts[baseHash] = seen;

          final baseId =
              uid != null && uid.isNotEmpty ? uid : 'khal_${baseHash}_$seen';

          // Check if the Master Event itself is an exception
          bool isMasterExcluded = currentExDates.any((ex) =>
              ex.year == currentStart!.year &&
              ex.month == currentStart!.month &&
              ex.day == currentStart!.day); 

          final baseEvent = CalendarEvent(
            id: baseId,
            title: currentSummary!,
            startTime: currentStart!,
            endTime: endTime,
            location: currentLocation,
            description: currentDescription,
            sourceId: sourceId,
            rrule: rrule,
            isGenerated: false,
            exceptionDates: currentExDates,
            isHidden: isMasterExcluded,
            isAllDay: currentIsAllDay,
          );

          if (!baseEvent.startTime.isBefore(localMin) &&
              !baseEvent.startTime.isAfter(localMax)) {
            _addEventToMap(events, currentStart!, baseEvent);
          }

          if (rrule != null && recurrenceId == null) {
            recurringMasters.add((event: baseEvent, uid: uid));
          }
        }
        inEvent = false;
      } else if (inEvent) {
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
          final keyPart = line.substring(0, colonIndex).toUpperCase();
          final value = line.substring(colonIndex + 1);

          if (keyPart.startsWith('SUMMARY'))
            currentSummary = value;
          else if (keyPart.startsWith('DTSTART')) {
            currentStart = _parseStrictDate(value);
            if (!value.contains('T')) currentIsAllDay = true;
          }
          else if (keyPart.startsWith('DTEND'))
            currentEnd = _parseStrictDate(value);
          else if (keyPart.startsWith('LOCATION'))
            currentLocation = value;
          else if (keyPart.startsWith('DESCRIPTION')) {
            currentDescription = value
                .replaceAll('\\n', '\n')
                .replaceAll('\\,', ',')
                .replaceAll('\\;', ';');
          } else if (keyPart.startsWith('UID')) {
            currentUid = value;
          } else if (keyPart.startsWith('RECURRENCE-ID')) {
            currentRecurrenceId = _parseStrictDate(value);
          } else if (keyPart.startsWith('RRULE')) {
            final val = value.trim();
            if (val.isNotEmpty) rrule = val;
          } else if (keyPart.startsWith('EXDATE')) {
            final dt = _parseStrictDate(value.trim());
            if (dt != null) currentExDates.add(dt);
          }
        }
      }
    }

    for (final master in recurringMasters) {
      _generateSafeRecurrences(
        events,
        master.event,
        master.event.rrule!,
        localMin,
        localMax,
        skipStarts:
            master.uid == null ? null : recurrenceOverridesByUid[master.uid],
      );
    }

    return events;
  }

  void _addEventToMap(Map<DateTime, List<CalendarEvent>> events, DateTime start,
      CalendarEvent event) {
    final dayEvents = events.putIfAbsent(_normalizeDate(start), () => []);
    if (!dayEvents.any((e) => e.id == event.id)) dayEvents.add(event);
  }

  DateTime? _parseStrictDate(String value) {
    try {
      String dateStr = value.trim();
      bool isUtc = dateStr.endsWith('Z');
      if (isUtc) dateStr = dateStr.substring(0, dateStr.length - 1);

      if (dateStr.contains('T')) {
        final parts = dateStr.split('T');
        final d = parts[0];
        final t = parts[1];
        if (d.length == 8 && t.length >= 4) {
          final year = int.parse(d.substring(0, 4));
          final month = int.parse(d.substring(4, 6));
          final day = int.parse(d.substring(6, 8));
          final hour = int.parse(t.substring(0, 2));
          final minute = int.parse(t.substring(2, 4));
          if (isUtc)
            return DateTime.utc(year, month, day, hour, minute).toLocal();
          return DateTime(year, month, day, hour, minute);
        }
      }

      if (dateStr.length == 8) {
        return DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  int _getWeekdayIndex(String day) {
    switch (day.toUpperCase()) {
      case 'MO': return DateTime.monday;
      case 'TU': return DateTime.tuesday;
      case 'WE': return DateTime.wednesday;
      case 'TH': return DateTime.thursday;
      case 'FR': return DateTime.friday;
      case 'SA': return DateTime.saturday;
      case 'SU': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  // Recurrences
  void _generateSafeRecurrences(
    Map<DateTime, List<CalendarEvent>> events,
    CalendarEvent original,
    String rrule,
    DateTime minViewable,
    DateTime maxDate, {
    Set<DateTime>? skipStarts,
  }) {
    // Parse RRULE
    final parts = rrule.split(';');
    final map = <String, String>{};
    for (final p in parts) {
      final idx = p.indexOf('=');
      if (idx <= 0) continue;
      map[p.substring(0, idx).toUpperCase().trim()] =
          p.substring(idx + 1).trim();
    }

    final freq = (map['FREQ'] ?? '').toUpperCase();
    final interval = int.tryParse(map['INTERVAL'] ?? '1') ?? 1;
    final countLimit = int.tryParse(map['COUNT'] ?? '');
    DateTime? until;
    if (map.containsKey('UNTIL')) {
      until = _parseStrictDate(map['UNTIL']!);
    }

    // Parse BYDAY (e.g. "MO,WE,FR" or "1FR")
    final List<String> byDayParts =
        map.containsKey('BYDAY') ? map['BYDAY']!.split(',') : [];

    // Cap instances hard limit
    const int maxInstances = 500;

    // Setup Cursor
    DateTime cursor = original.startTime;
    final Duration duration = original.endTime.difference(original.startTime);

    int generatedCount = 0;
    int safetyLoop = 0;

    // **Need to improve**
    while (generatedCount < maxInstances && safetyLoop < 1000) {
      safetyLoop++;

      // Stop if cursor goes beyond max limits
      if (cursor.isAfter(maxDate)) break;

      // Generate Candidates for this Interval
      List<DateTime> candidates = [];

      if (freq == 'WEEKLY' && byDayParts.isNotEmpty) {
        // Find the Monday of this week, then add offsets
        final int currentWeekday = cursor.weekday;
        final DateTime monday =
            cursor.subtract(Duration(days: currentWeekday - 1));

        for (final part in byDayParts) {
          final wdIndex = _getWeekdayIndex(part);
          DateTime candidate = monday.add(Duration(days: wdIndex - 1));

          // Restore Time
          candidate = DateTime(candidate.year, candidate.month, candidate.day,
              original.startTime.hour, original.startTime.minute);

          candidates.add(candidate);
        }
      } else if (freq == 'MONTHLY' && byDayParts.isNotEmpty) {
        // Expand Nth Weekday (e.g. 1FR, -1MO)
        for (final part in byDayParts) {
          final RegExp reg = RegExp(r'^([-\d]+)?([A-Z]{2})$');
          final match = reg.firstMatch(part);
          if (match != null) {
            final posStr = match.group(1);
            final dayStr = match.group(2)!;
            final targetWd = _getWeekdayIndex(dayStr);

            if (posStr != null) {
              // Nth occurrence
              final int pos = int.parse(posStr);
              List<DateTime> monthDays = [];
              DateTime d = DateTime(cursor.year, cursor.month, 1,
                  original.startTime.hour, original.startTime.minute);
              while (d.month == cursor.month) {
                if (d.weekday == targetWd) monthDays.add(d);
                d = d.add(const Duration(days: 1));
              }

              if (pos > 0) {
                if (pos <= monthDays.length) candidates.add(monthDays[pos - 1]);
              } else if (pos < 0) {
                if (monthDays.length + pos >= 0)
                  candidates.add(monthDays[monthDays.length + pos]);
              }
            } else {
              // No position -> implied "Every X"
              DateTime d = DateTime(cursor.year, cursor.month, 1,
                  original.startTime.hour, original.startTime.minute);
              while (d.month == cursor.month) {
                if (d.weekday == targetWd) candidates.add(d);
                d = d.add(const Duration(days: 1));
              }
            }
          }
        }
      } else {
        // Default: Just the cursor itself
        candidates.add(cursor);
      }

      // Validate and Add Candidates
      candidates.sort();

      for (final start in candidates) {
        if (until != null && start.isAfter(until)) return;
        if (countLimit != null && generatedCount >= countLimit) return;
        if (start.isBefore(original.startTime)) continue;

        bool isExcluded = original.exceptionDates.any((ex) =>
            ex.year == start.year &&
            ex.month == start.month &&
            ex.day == start.day);

        generatedCount++;

        if (isExcluded) continue;

        if (skipStarts != null &&
            skipStarts.any((d) => d.isAtSameMomentAs(start))) {
          continue;
        }

        if (start.isAfter(minViewable) && start.isBefore(maxDate)) {
          // Skip if it's the exact original instance
          if (start.isAtSameMomentAs(original.startTime)) continue;

          _addEventToMap(
            events,
            start,
            CalendarEvent(
              id: '${original.id}_r$generatedCount',
              title: original.title,
              startTime: start,
              endTime: start.add(duration),
              location: original.location,
              description: original.description,
              sourceId: original.sourceId,
              rrule: original.rrule,
              isGenerated: true,
              isAllDay: original.isAllDay,
            ),
          );
        }
      }

      // Advance Cursor
      if (freq == 'DAILY') {
        cursor = cursor.add(Duration(days: interval));
      } else if (freq == 'WEEKLY') {
        cursor = cursor.add(Duration(days: 7 * interval));
      } else if (freq == 'MONTHLY') {
        int newMonth = cursor.month + interval;
        int newYear = cursor.year + ((newMonth - 1) ~/ 12);
        newMonth = ((newMonth - 1) % 12) + 1;
        int newDay = cursor.day;
        final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        if (newDay > daysInNewMonth) newDay = daysInNewMonth;
        cursor =
            DateTime(newYear, newMonth, newDay, cursor.hour, cursor.minute);
      } else if (freq == 'YEARLY') {
        cursor = DateTime(cursor.year + interval, cursor.month, cursor.day,
            cursor.hour, cursor.minute);
      } else {
        break;
      }
    }
  }

  // UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading)
      return Scaffold(
          body: Center(
              child: CircularProgressIndicator(
                  color: theme.colorScheme.primary)));
    if (_errorMessage != null)
      return Scaffold(body: Center(child: Text(_errorMessage!)));

    final filteredEvents = _filteredEvents;
    final calendarEvents = _addGoalsToEvents(filteredEvents);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Only handle when this root node has focus (no dialog/text field active)
        if (FocusManager.instance.primaryFocus != node) return KeyEventResult.ignored;

        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        if (isCtrl) {
          if (event.logicalKey == LogicalKeyboardKey.keyN) {
            _showAddEventDialog();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _showSearchDialog();
            return KeyEventResult.handled;
          }
        } else {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prevPeriod();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextPeriod();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyT) {
            _goToToday();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _setViewMode(CalendarViewMode.month);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyW) {
            _setViewMode(CalendarViewMode.week);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      floatingActionButton: ExpressiveButton(
        size: 56,
        color: theme.colorScheme.primary,
        onTap: _showAddMenu,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildCard(
                      theme,
                      Column(
                        children: [
                          _buildHeader(theme, compact: false),
                          Expanded(child: _buildCalendarView(calendarEvents)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _buildCard(
                      theme,
                      _buildSidebar(theme, filteredEvents),
                      isVariant: true,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 450,
                    child: _buildCard(
                      theme,
                      Column(
                        children: [
                          _buildHeader(theme, compact: true),
                          Expanded(child: _buildCalendarView(calendarEvents)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 450,
                    child: _buildCard(
                      theme,
                      _buildSidebar(theme, filteredEvents),
                      isVariant: true,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    ),
    );
  }

  Widget _buildCalendarView(
      Map<DateTime, List<CalendarEvent>> filteredEvents) {
    if (_viewMode == CalendarViewMode.month) {
      return MonthView(
        focusedMonth: _focusedMonth,
        selectedDate: _selectedDate,
        events: filteredEvents,
        weekStartsOnMonday: _weekStartsMonday,
        onDateSelected: (d) => setState(() => _selectedDate = d),
      );
    }
    return WeekView(
      focusedMonth: _focusedMonth,
      selectedDate: _selectedDate,
      events: filteredEvents,
      scrollController: _weekScrollController,
      weekStartsOnMonday: _weekStartsMonday,
      use24Hour: _use24Hour,
      onTimeSlotTapped: (dt) => _showAddEventDialog(initialDateTime: dt),
      onDateSelected: (d) => setState(() => _selectedDate = d),
    );
  }

  Widget _buildCard(ThemeData theme, Widget child, {bool isVariant = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isVariant
            ? theme.colorScheme.surfaceVariant
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _buildHeader(ThemeData theme, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.only(
        left: compact ? 16 : 32,
        top: compact ? 16 : 32,
        right: compact ? 16 : 32,
        // In Month mode keep 32/16. In Week mode, cut it to 0 or 8.
        bottom: _viewMode == CalendarViewMode.week ? 8 : (compact ? 16 : 32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ViewSwitcher(
            title: fmtMonth.format(_focusedMonth),
            subtitle: fmtYear.format(_focusedMonth),
            isMonthView: _viewMode == CalendarViewMode.month,
            compact: compact,
            onTap: _toggleViewMode,
            theme: theme,
          ),
          Row(
            children: [
              IconButton(onPressed: _prevPeriod, icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: _nextPeriod, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
      ThemeData theme, Map<DateTime, List<CalendarEvent>> filteredEvents) {
    final normalizedDate = _normalizeDate(_selectedDate);
    final events = (filteredEvents[normalizedDate] ?? const []).toList();
    final isToday = normalizedDate == _normalizeDate(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmtDayName.format(_selectedDate).toUpperCase(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    fontSize: 24,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmtDayNum.format(_selectedDate),
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onBackground,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Calendar visibility chips
                if (_calendarPaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _calendarPaths.map((path) {
                        final name = _basename(path);
                        final isHidden = _hiddenCalendarPaths.contains(path);
                        return FilterChip(
                          label: Text(name,
                              style: const TextStyle(fontSize: 11)),
                          selected: !isHidden,
                          onSelected: (selected) =>
                              _toggleCalendar(path, !selected),
                          selectedColor:
                              theme.colorScheme.primaryContainer,
                          checkmarkColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ),

                // EVENTS / TODOS / GOALS TOGGLE
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SegmentedButton<SidebarTab>(
                    segments: const [
                      ButtonSegment(
                        value: SidebarTab.events,
                        label: Text('Events'),
                        icon: Icon(Icons.event_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: SidebarTab.todos,
                        label: Text('Todos'),
                        icon: Icon(Icons.checklist_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: SidebarTab.goals,
                        label: Text('Goals'),
                        icon: Icon(Icons.flag_outlined, size: 16),
                      ),
                    ],
                    selected: {_sidebarTab},
                    onSelectionChanged: (s) =>
                        setState(() => _sidebarTab = s.first),
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.12),
                      selectedForegroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                // WEATHER WIDGET
                if (_weather != null)
                  Builder(builder: (context) {
                    // include units
                    double displayTemp = _weather!.temp;
                    String unitSym = '°C';

                    if (_weatherUnit == WeatherUnit.fahrenheit) {
                      displayTemp = (displayTemp * 9 / 5) + 32;
                      unitSym = '°F';
                    } else if (_weatherUnit == WeatherUnit.kelvin) {
                      displayTemp = displayTemp + 273.15;
                      unitSym = 'K';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 16), // Add spacing before the list
                      child: Material(
                        color: theme.brightness == Brightness.dark
                            ? Colors.black12
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _showLocationSearch,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_weather!.icon,
                                    size: 24,
                                    color:
                                        theme.colorScheme.onPrimaryContainer),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${displayTemp.round()}$unitSym',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    Text(
                                      _weather!.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_sidebarTab) {
            SidebarTab.todos => TodosPanel(
                todos: _todos,
                dayEvents: events,
                allEvents: filteredEvents,
                onAdd: _addTodo,
                onToggle: _toggleTodo,
                onDelete: _deleteTodo,
                onLink: _linkTodoEvent,
                onReorder: _reorderTodos,
                onEdit: _editTodo,
                onJumpToEvent: (event) => setState(() {
                  _selectedDate = _normalizeDate(event.startTime);
                  _focusedMonth = _normalizeDate(event.startTime);
                  _sidebarTab = SidebarTab.events;
                }),
              ),
            SidebarTab.goals => GoalsPanel(
                goals: _sortedGoals,
                fnv1aHex: _fnv1aHex,
                onAdd: _addGoal,
                onToggle: _toggleGoal,
                onDelete: _deleteGoal,
                onEdit: _editGoal,
              ),
            SidebarTab.events => events.isEmpty
                ? Center(
                    child: Text('No Events',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: events.length,
                    itemBuilder: (context, index) => EventCard(
                      event: events[index],
                      use24Hour: _use24Hour,
                      onEdit: _isLocalKhalEvent(events[index])
                          ? () => _showEditEventDialog(events[index])
                          : null,
                      onDelete: () =>
                          _deleteEvent(_selectedDate, events[index]),
                    ),
                  ),
          },
        ),
      ],
    );
  }
}
