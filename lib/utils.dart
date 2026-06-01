/// utils.dart
///
/// Contains global static formatters and shared utility functions.

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