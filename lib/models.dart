/// models.dart
///
/// Contains all data models and enums used throughout the EverCal application.
/// This includes Theme settings, Weather units, and the core CalendarEvent class.

import 'package:flutter/material.dart'; // For IconData

// Enums
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
  final String id; // stable ID given to each events
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final String? sourceId; // Owning vdir .ics path
  final String? rrule; // Stores "FREQ=YEARLY" etc.
  final bool isGenerated; // True if this is a repeat instance
  final List<DateTime> exceptionDates; // List of dates to skip
  final bool isHidden; // Hides event in a reccuring event (instead of deleting)

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
    this.isHidden = false, // DEFAULT FALSE
  });

  // Helper copyWith
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
