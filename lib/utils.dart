/// utils.dart
///
/// Contains global static formatters and shared utility functions.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Global Static Formatters
final DateFormat fmtMonth = DateFormat('MMMM');
final DateFormat fmtYear = DateFormat('yyyy');
final DateFormat fmtDayNum = DateFormat('d');
final DateFormat fmtDayName = DateFormat('EEE');
final DateFormat fmtTime = DateFormat('h:mm a');
final DateFormat fmtIcsTime = DateFormat('yyyyMMdd\'T\'HHmm00');
final DateFormat fmtGridDay = DateFormat('MMM d');
final DateFormat fmtTime24 = DateFormat('HH:mm');
final DateFormat fmtSearchDate = DateFormat('MMM d, yyyy');

/// Days to subtract from [date] to reach the first column of its week.
/// Sunday-first by default; Monday-first when [mondayFirst] is true.
int weekStartOffset(DateTime date, {required bool mondayFirst}) =>
    mondayFirst ? (date.weekday - 1) % 7 : date.weekday % 7;

/// Deterministic event accent color derived from the event title.
const List<Color> _eventColors = [
  Color(0xFFE67E80), // Red
  Color(0xFFE69875), // Orange
  Color(0xFFDBBC7F), // Yellow
  Color(0xFFA7C080), // Green
  Color(0xFF83C092), // Mint
  Color(0xFF7FBBB3), // Teal
  Color(0xFF7FB4CA), // Lavender
  Color(0xFF938AA9), // Purple
  Color(0xFFD699B6), // Sakura
  Color(0xFF7A8490), // Slate
];

Color eventColor(String title) =>
    _eventColors[title.hashCode.abs() % _eventColors.length];

// Shared filesystem / settings helpers.

String homeDir() => Platform.environment['HOME'] ?? '';

String joinPath(List<String> parts) =>
    parts.where((p) => p.isNotEmpty).join(Platform.pathSeparator);

Directory baseDir() => Directory(joinPath([homeDir(), 'Documents', 'EverCal']));

File settingsFile() => File(joinPath([baseDir().path, 'settings.json']));

Future<Map<String, dynamic>> readSettings() async {
  try {
    final f = settingsFile();
    if (!await f.exists()) return {};
    final decoded = json.decode(await f.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return {};
}

Future<void> writeSettings(Map<String, dynamic> settings) async {
  try {
    final dir = baseDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    await settingsFile().writeAsString(json.encode(settings));
  } catch (_) {}
}

// Lunar calendar — Vietnamese/Chinese luni-solar calendar, UTC+7.
// Algorithm: Meeus "Astronomical Algorithms" Ch. 49 (accurate ±2 min).

int _toJDN(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final yr = y + 4800 - a;
  final mo = m + 12 * a - 3;
  return d + (153 * mo + 2) ~/ 5 + 365 * yr + yr ~/ 4 - yr ~/ 100 + yr ~/ 400 - 32045;
}

double _rad(double deg) {
  double d = deg % 360.0;
  if (d < 0) d += 360.0;
  return d * (math.pi / 180.0);
}

// Julian Ephemeris Day of the k-th new moon (k=0 ≈ Jan 6.3, 2000 UTC).
double _newMoonJDE(int k) {
  final double T = k / 1236.85;
  final double T2 = T * T;
  final double T3 = T2 * T;
  final double T4 = T3 * T;
  double jde = 2451550.09766
      + 29.530588861 * k
      + 0.00015437 * T2
      - 0.000000150 * T3
      + 0.00000000073 * T4;
  final double E = 1.0 - 0.002516 * T - 0.0000074 * T2;
  final double M = _rad(2.5534 + 29.10535670 * k - 0.0000014 * T2);
  final double Mp = _rad(201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3);
  final double F = _rad(160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3);
  final double Om = _rad(124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3);
  jde += -0.40720 * math.sin(Mp)
      + 0.17241 * E * math.sin(M)
      + 0.01608 * math.sin(2 * Mp)
      + 0.01039 * math.sin(2 * F)
      + 0.00739 * E * math.sin(Mp - M)
      - 0.00514 * E * math.sin(Mp + M)
      + 0.00208 * E * E * math.sin(2 * M)
      - 0.00111 * math.sin(Mp - 2 * F)
      - 0.00057 * math.sin(Mp + 2 * F)
      + 0.00056 * E * math.sin(2 * Mp + M)
      - 0.00042 * math.sin(3 * Mp)
      + 0.00042 * E * math.sin(M + 2 * F)
      + 0.00038 * E * math.sin(M - 2 * F)
      - 0.00024 * E * math.sin(2 * Mp - M)
      - 0.00017 * math.sin(Om)
      - 0.00007 * math.sin(Mp + 2 * M)
      + 0.00004 * math.sin(2 * Mp - 2 * F)
      + 0.00004 * math.sin(3 * M)
      + 0.00003 * math.sin(Mp + M - 2 * F)
      + 0.00003 * math.sin(2 * Mp + 2 * F)
      - 0.00003 * math.sin(Mp + M + 2 * F)
      + 0.00003 * math.sin(Mp - M + 2 * F)
      - 0.00002 * math.sin(Mp - M - 2 * F)
      - 0.00002 * math.sin(3 * Mp + M)
      + 0.00002 * math.sin(4 * Mp);
  return jde;
}

// JDE → Vietnam local calendar day (UTC+7).
// JDE epoch is noon UTC; +0.5 shifts to midnight UTC; +7/24 shifts to Hanoi midnight.
int _jdeToVnJDN(double jde) => (jde + 0.5 + 7.0 / 24.0).floor();

// k-index of the new moon at or immediately before jdn (Vietnam local day).
int _kForNewMoon(int jdn) {
  int k = ((jdn + 0.5 - 2451550.09766) / 29.530588861).floor();
  if (_jdeToVnJDN(_newMoonJDE(k)) > jdn) k--;
  return k;
}

final Map<int, int> _cnyCache = {};

// JDN of Vietnamese/Chinese New Year for a Gregorian year.
// New Year is the new moon falling between Jan 21 and Feb 20.
int _lunarNewYearJDN(int gregYear) {
  if (_cnyCache.containsKey(gregYear)) return _cnyCache[gregYear]!;
  final int jan21 = _toJDN(gregYear, 1, 21);
  final int feb20 = _toJDN(gregYear, 2, 20);
  int k = ((jan21 + 0.5 - 2451550.09766) / 29.530588861).ceil();
  for (int i = 0; i < 3; i++) {
    final int nm = _jdeToVnJDN(_newMoonJDE(k + i));
    if (nm >= jan21 && nm <= feb20) return _cnyCache[gregYear] = nm;
  }
  return _cnyCache[gregYear] = _jdeToVnJDN(_newMoonJDE(k));
}

final Map<int, ({int day, int month})> _lunarDateCache = {};

/// Lunar day (1–30) and month (1–12) for a Gregorian date.
/// Leap months are not tracked; month may be off by 1 in the months
/// following a leap month (occurs in roughly 1 of every 3 lunar years).
({int day, int month}) lunarDate(DateTime date) {
  final int jdn = _toJDN(date.year, date.month, date.day);
  if (_lunarDateCache.containsKey(jdn)) return _lunarDateCache[jdn]!;
  final int k = _kForNewMoon(jdn);
  final int nmJDN = _jdeToVnJDN(_newMoonJDE(k));
  final int day = jdn - nmJDN + 1;
  int gregYear = date.year;
  int cnyJDN = _lunarNewYearJDN(gregYear);
  if (nmJDN < cnyJDN) {
    gregYear--;
    cnyJDN = _lunarNewYearJDN(gregYear);
  }
  final int month = (k - _kForNewMoon(cnyJDN)) % 12 + 1;
  return _lunarDateCache[jdn] = (day: day, month: month);
}

// Format the lunar date for display. Shows "day/month" when showFull, else "day".
String lunarLabel(({int day, int month}) ld, {required bool showFull}) =>
    showFull ? '${ld.day}/${ld.month}' : '${ld.day}';

// True for new moon (day 1) and full moon (day 15) — visually highlighted.
bool lunarSpecial(({int day, int month}) ld) => ld.day == 1 || ld.day == 15;