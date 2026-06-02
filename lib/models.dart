/// models.dart
///
/// Contains all data models and enums used throughout the EverCal application.
/// This includes Theme settings, Weather units, and the core CalendarEvent class.

import 'package:flutter/material.dart'; // For IconData

// Enums
enum AppThemeSetting { dark, light, rosePineDawn }
enum WeatherUnit { celsius, fahrenheit, kelvin }
enum CalendarViewMode { month, week }
enum SidebarTab { events, todos, goals }

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

  TodoItem copyWith(
      {String? title,
      bool? isCompleted,
      String? linkedEventId,
      bool clearLink = false}) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedEventId: clearLink ? null : (linkedEventId ?? this.linkedEventId),
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

class GoalItem {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? date;   // null = no date/time (unscheduled)
  final bool hasTime;     // only meaningful when date != null
  final int hour;
  final int minute;
  final DateTime createdAt;

  const GoalItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.date,
    this.hasTime = false,
    this.hour = 0,
    this.minute = 0,
    required this.createdAt,
  });

  GoalItem copyWith({
    String? title,
    bool? isCompleted,
    DateTime? date,
    bool clearDate = false,
    bool? hasTime,
    int? hour,
    int? minute,
  }) {
    return GoalItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      date: clearDate ? null : (date ?? this.date),
      hasTime: hasTime ?? this.hasTime,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        if (date != null) 'date': date!.toIso8601String(),
        'hasTime': hasTime,
        if (hasTime) 'hour': hour,
        if (hasTime) 'minute': minute,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalItem.fromJson(Map<String, dynamic> json) {
    final hasTime = json['hasTime'] as bool? ?? false;
    return GoalItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      hasTime: hasTime,
      hour: hasTime ? (json['hour'] as int? ?? 0) : 0,
      minute: hasTime ? (json['minute'] as int? ?? 0) : 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
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
