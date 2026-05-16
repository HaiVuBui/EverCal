import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat fmtMonth = DateFormat('MMMM');
final DateFormat fmtYear = DateFormat('yyyy');
final DateFormat fmtDayNum = DateFormat('d');
final DateFormat fmtDayName = DateFormat('EEE');
final DateFormat fmtTime = DateFormat('h:mm a');
final DateFormat fmtIcsTime = DateFormat('yyyyMMdd\'T\'HHmm00');
final DateFormat fmtGridDay = DateFormat('MMM d');

Color eventColor(String title) {
  const colors = [
    Color(0xFFE67E80),
    Color(0xFFE69875),
    Color(0xFFDBBC7F),
    Color(0xFFA7C080),
    Color(0xFF83C092),
    Color(0xFF7FBBB3),
    Color(0xFF7FB4CA),
    Color(0xFF938AA9),
    Color(0xFFD699B6),
    Color(0xFF7A8490),
  ];
  return colors[title.hashCode.abs() % colors.length];
}
