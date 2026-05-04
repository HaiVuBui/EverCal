/// home_screen.dart
///
/// Contains the main Stateful implementation of the Calendar:
/// file I/O, parsing (ICS/JSON/Khal), recurrence generation,
/// weather fetching, and layout management.

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For LineSplitter

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
  Map<DateTime, List<CalendarEvent>> _khalEvents = {};

  WeatherData? _weather;
  bool _isLoading = true;
  String? _errorMessage;
  WeatherUnit _weatherUnit = WeatherUnit.celsius;

  // At Startup (the default scroll position)
  final ScrollController _weekScrollController =
      ScrollController(initialScrollOffset: 520); // 9 AM = 9 * 60

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadEvents();
    _loadWeather(); // Reads settings, so check view mode there
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

  Future<void> _ensureDirs() async {
    if (!await _baseDir().exists()) await _baseDir().create(recursive: true);
  }

  String _basename(String path) {
    final sep = Platform.pathSeparator;
    final parts = path.split(sep);
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

  // Toggle View Mode
  Future<void> _toggleViewMode() async {
    setState(() {
      _viewMode = _viewMode == CalendarViewMode.month
          ? CalendarViewMode.week
          : CalendarViewMode.month;
    });

    final settings = await _readSettings();
    settings['calendar_view'] = _viewMode.name;
    await _writeSettings(settings);
  }

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set to Auto-Location')));
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
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location set to ${loc['name']}')));
          } else {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('City not found')));
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

      _khalEvents = {};
      final khalConnectedNow = await _verifyKhalConnection();
      if (khalConnectedNow) {
        _khalEvents = await _loadKhalEventsFromVdir();
      }

      _events = _khalEvents;

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

  Map<DateTime, List<CalendarEvent>> _sortedCopy(
      Map<DateTime, List<CalendarEvent>> src) {
    final out = <DateTime, List<CalendarEvent>>{};
    for (final e in src.entries) {
      final list = List<CalendarEvent>.of(e.value);
      list.sort((x, y) => x.startTime.compareTo(y.startTime));
      out[e.key] = list;
    }
    return out;
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

  Future<bool> _verifyKhalConnection() async {
    try {
      final version = await Process.run('khal', ['--version']);
      if (version.exitCode != 0) return false;

      final cfgFile = await _findKhalConfigFile();
      if (cfgFile == null) return false;

      final raw = await cfgFile.readAsLines();
      final paths = _extractKhalCalendarPaths(raw);
      if (paths.isEmpty) return false;

      final expanded = <String>[];
      for (final p in paths) {
        expanded.addAll(await _expandCalendarPathPattern(p));
      }

      for (final p in expanded) {
        if (await Directory(p).exists()) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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

      for (final calPath in expanded) {
        final dir = Directory(calPath);
        if (!await dir.exists()) continue;

        final ents =
            await dir.list(recursive: false, followLinks: false).toList();
        final validFiles = ents
            .whereType<File>()
            .where((e) => e.path.toLowerCase().endsWith('.ics'));

        for (final file in validFiles) {
          try {
            final content = await file.readAsString();
            final parsed = _parseICS(
              content,
              sourceId: file.path,
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
      }
      for (final date in events.keys) {
        events[date]!.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
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
        // The theme inside the builder so it updates live
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Theme Switch Tile
              ListTile(
                leading: Icon(widget.currentIcon,
                    color: theme.colorScheme.onSurfaceVariant),
                title: const Text('Switch Theme'),
                onTap: () {
                  widget.onThemeToggle();
                },
              ),
              const Divider(), //divider

              ListTile(
                leading:
                    Icon(Icons.edit_calendar, color: theme.colorScheme.primary),
                title: const Text('Add Event'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEventDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddEventDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AddEventDialog(
              initialSelectedDate: _selectedDate,
              fnv1aHex: _fnv1aHex,
              onSave: _addEvent,
            );
          },
        );
      },
    );
  }

  Future<void> _showEditEventDialog(CalendarEvent event) async {
    if (!_isLocalKhalEvent(event)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Only local khal events can be edited.')));
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AddEventDialog(
              initialSelectedDate: event.startTime,
              existingEvent: event,
              fnv1aHex: _fnv1aHex,
              onSave: (date, updatedEvent) => _updateEvent(event, updatedEvent),
            );
          },
        );
      },
    );
  }

  Future<void> _addEvent(DateTime date, CalendarEvent event) async {
    final calPath = await _defaultKhalCalendarPath();
    if (calPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No khal calendar directory found.')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This calendar is read-only in EverCal.')));
      }
      return;
    }

    if (originalEvent.isGenerated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Editing generated recurring instances is not supported yet.')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This calendar is read-only in EverCal.')));
      }
      return;
    }

    if (event.isGenerated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Deleting generated recurring instances is not supported yet.')));
      }
      return;
    }

    final path = event.sourceId;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting khal event: $e')));
      }
    }
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
            isHidden: isMasterExcluded, // MARK HIDDEN IF EXCLUDED
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
          else if (keyPart.startsWith('DTSTART'))
            currentStart = _parseStrictDate(value);
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
    final date = DateTime(start.year, start.month, start.day);
    final dayEvents = events.putIfAbsent(date, () => []);
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

    return Scaffold(
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
                          // TOGGLE BETWEEN GRIDS
                          Expanded(
                            child: _viewMode == CalendarViewMode.month
                                ? MonthView(
                                    focusedMonth: _focusedMonth,
                                    selectedDate: _selectedDate,
                                    events: _events,
                                    onDateSelected: (d) => setState(() => _selectedDate = d),
                                  )
                                : WeekView(
                                    focusedMonth: _focusedMonth,
                                    selectedDate: _selectedDate,
                                    events: _events,
                                    scrollController: _weekScrollController,
                                    onDateSelected: (d) => setState(() => _selectedDate = d),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _buildCard(
                      theme,
                      _buildSidebar(theme),
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
                          Expanded(
                            child: _viewMode == CalendarViewMode.month
                                ? MonthView(
                                    focusedMonth: _focusedMonth,
                                    selectedDate: _selectedDate,
                                    events: _events,
                                    onDateSelected: (d) => setState(() => _selectedDate = d),
                                  )
                                : WeekView(
                                    focusedMonth: _focusedMonth,
                                    selectedDate: _selectedDate,
                                    events: _events,
                                    scrollController: _weekScrollController,
                                    onDateSelected: (d) => setState(() => _selectedDate = d),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 450,
                    child: _buildCard(
                      theme,
                      _buildSidebar(theme),
                      isVariant: true,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
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
          // CLICKABLE TITLE TO TOGGLE VIEW (will probably add a button in the futre)
          ViewSwitcher(
            title: fmtMonth.format(_focusedMonth),
            subtitle: fmtYear.format(_focusedMonth),
            isMonthView: _viewMode == CalendarViewMode.month,
            compact: compact, // 
            onTap: _toggleViewMode,
            theme: theme,
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_viewMode == CalendarViewMode.month) {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month - 1);
                    } else {
                      // Week View: Go back 7 days
                      _focusedMonth =
                          _focusedMonth.subtract(const Duration(days: 7));
                    }
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_viewMode == CalendarViewMode.month) {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month + 1);
                    } else {
                      // Week View: Go forward 7 days
                      _focusedMonth =
                          _focusedMonth.add(const Duration(days: 7));
                    }
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

//-----------------------------------------------------------------------------------------------------------------------------------

  Widget _buildSidebar(ThemeData theme) {
    final normalizedDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final events = (_events[normalizedDate] ?? const [])
        .where((e) => !e.isHidden)
        .toList();
    final isToday = _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

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
                const SizedBox(height: 16),

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
          child: events.isEmpty
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
                    onEdit: _isLocalKhalEvent(events[index])
                        ? () => _showEditEventDialog(events[index])
                        : null,
                    onDelete: () =>
                        _deleteEvent(_selectedDate, events[index]),
                  ),
                ),
        ),
      ],
    );
  }
}
