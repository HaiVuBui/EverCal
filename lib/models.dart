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

class TodoItem {
  final String id;
  final String title;
  final bool isCompleted;
  final String? linkedEventId;
  final DateTime createdAt;

  const TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.linkedEventId,
    required this.createdAt,
  });

  TodoItem copyWith({bool? isCompleted}) {
    return TodoItem(
      id: id,
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedEventId: linkedEventId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        if (linkedEventId != null) 'linkedEventId': linkedEventId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        title: json['title'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        linkedEventId: json['linkedEventId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
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
  final bool isAllDay;

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
    this.isAllDay = false,
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
    bool? isAllDay,
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
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }
}
