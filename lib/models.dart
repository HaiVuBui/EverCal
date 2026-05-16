import 'package:flutter/material.dart';

enum AppThemeSetting { dark, light, rosePineDawn }
enum WeatherUnit { celsius, fahrenheit, kelvin }
enum CalendarViewMode { month, week }

class WeatherData {
  final double temp;
  final String description;
  final IconData icon;
  const WeatherData(
      {required this.temp, required this.description, required this.icon});
}

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final String? sourceId;
  final String? rrule;
  final bool isGenerated;
  final List<DateTime> exceptionDates;
  final bool isHidden;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.sourceId,
    this.rrule,
    this.isGenerated = false,
    this.exceptionDates = const [],
    this.isHidden = false,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    String? sourceId,
    String? rrule,
    bool? isGenerated,
    List<DateTime>? exceptionDates,
    bool? isHidden,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      description: description ?? this.description,
      sourceId: sourceId ?? this.sourceId,
      rrule: rrule ?? this.rrule,
      isGenerated: isGenerated ?? this.isGenerated,
      exceptionDates: exceptionDates ?? this.exceptionDates,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
