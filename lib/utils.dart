/// utils.dart
///
/// Contains global static formatters and shared utility functions.

import 'dart:convert';
import 'dart:io';
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