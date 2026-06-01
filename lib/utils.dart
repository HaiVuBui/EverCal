/// utils.dart
///
/// Contains global static formatters and shared utility functions.

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