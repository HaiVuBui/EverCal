/// calendar_views.dart
///
/// Contains the visual implementations of the Calendar Grids.


import 'package:flutter/material.dart';
import 'models.dart';
import 'utils.dart';
import 'components.dart';

// Month view
class MonthView extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, List<CalendarEvent>> events;
  final ValueChanged<DateTime> onDateSelected;

  const MonthView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final totalCells = ((daysInMonth + startingWeekday) / 7).ceil() * 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double gridHeight = constraints.maxHeight;
        final double gridWidth = constraints.maxWidth;
        final double cellHeight =
            ((gridHeight - 32) / 6).clamp(1.0, double.infinity);
        final double cellWidth = (gridWidth - 16) / 7;
        final double childAspectRatio = cellWidth / cellHeight;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  final dayNumber = index - startingWeekday + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth)
                    return const SizedBox();
                  final date = DateTime(
                      focusedMonth.year, focusedMonth.month, dayNumber);

                  final isSelected = date.day == selectedDate.day &&
                      date.month == selectedDate.month &&
                      date.year == selectedDate.year;
                  final isToday = date == today;
                  final dayEvents =
                      (events[DateTime(date.year, date.month, date.day)] ??
                          const []).where((e) => !e.isHidden).toList();

                  return Center(
                    child: ExpressiveButton(
                      size: cellHeight < 50 ? cellHeight : 50,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      isSelected: isSelected,
                      side: isToday && !isSelected
                          ? BorderSide(
                              color: theme.colorScheme.primary, width: 1)
                          : BorderSide.none,
                      onTap: () => onDateSelected(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (dayEvents.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
// Week View
class WeekView extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, List<CalendarEvent>> events;
  final ValueChanged<DateTime> onDateSelected;
  final ScrollController scrollController;

  const WeekView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final int daysFromMonday = focusedMonth.weekday - 1;
    final DateTime weekStart =
        focusedMonth.subtract(Duration(days: daysFromMonday));
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));

    const double hourHeight = 60.0;
    const double timeColWidth = 50.0;
    const int totalHours = 24;

    return Column(
      children: [
        // HEADER
        Container(
          padding: const EdgeInsets.only(left: timeColWidth, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1))),
          ),
          child: Row(
            children: List.generate(7, (index) {
              final day = weekStart.add(Duration(days: index));
              final isToday = day.day == now.day &&
                  day.month == now.month &&
                  day.year == now.year;
              final isSelected = day.day == selectedDate.day &&
                  day.month == selectedDate.month &&
                  day.year == selectedDate.year;

              return Expanded(
                child: Center(
                  child: ExpressiveButton(
                    onTap: () => onDateSelected(day),
                    isSelected: isSelected,
                    size: 45,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmtDayName.format(day).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : (isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : (isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // GRID
        Expanded(
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TIME COLUMN
                  SizedBox(
                    width: timeColWidth,
                    child: Column(
                      children: List.generate(totalHours, (hour) {
                        return SizedBox(
                          height: hourHeight,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _formatHour(hour),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // DAYS COLUMNS + EVENTS
                  Expanded(
                    child: Stack(
                      children: [
                        // Grid Lines
                        Column(
                          children: List.generate(totalHours, (index) {
                            return Container(
                              height: hourHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.15),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        // Vertical Dividers
                        Row(
                          children: List.generate(7, (index) {
                            return Expanded(
                              child: Container(
                                height: totalHours * hourHeight,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.07),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        // EVENTS LAYERS
                        ...List.generate(7, (dayIndex) {
                          final dayDate = weekStart.add(Duration(days: dayIndex));
                          final dayEvents = events[DateTime(
                                  dayDate.year, dayDate.month, dayDate.day)] ??
                              [];

                          if (dayEvents.isEmpty) return const SizedBox();

                          return Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Row(
                              children: [
                                ...List.generate(dayIndex, (_) => const Spacer()),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // DO NOT render if width is not yet determined
                                      if (constraints.maxWidth <= 0) {
                                        return const SizedBox(); 
                                      }
                                      return Stack(
                                        children: _buildDayEvents(
                                          dayEvents,
                                          hourHeight,
                                          constraints.maxWidth,
                                          theme,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                ...List.generate(6 - dayIndex, (_) => const Spacer()),
                              ],
                            ),
                          );
                        }),

                        // CURRENT TIME INDICATOR
                        if (now.isAfter(weekStart) && now.isBefore(weekEnd))
                          _buildCurrentTimeIndicator(
                              now, weekStart, hourHeight, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  List<Widget> _buildDayEvents(List<CalendarEvent> events, double hourHeight,
      double colWidth, ThemeData theme) {
    final widgets = <Widget>[];
    
    // Filter hidden & Create a copy to sort. 
    // ndo not sort the original 'events' list in place inside build().
    final visibleEvents = events.where((e) => !e.isHidden).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Basic overlap detection
    List<List<CalendarEvent>> lanes = [];

    for (var event in visibleEvents) {
      bool placed = false;
      for (var lane in lanes) {
        if (lane.isEmpty) {
          lane.add(event);
          placed = true;
          break;
        }
        final last = lane.last;
        if (event.startTime.isAfter(last.endTime) ||
            event.startTime.isAtSameMomentAs(last.endTime)) {
          lane.add(event);
          placed = true;
          break;
        }
      }
      if (!placed) {
        lanes.add([event]);
      }
    }

    final int totalLanes = lanes.length;
    // Safety check against divide by zero just in case
    final double eventWidth = totalLanes > 0 ? colWidth / totalLanes : colWidth;

    for (int laneIdx = 0; laneIdx < totalLanes; laneIdx++) {
      for (var event in lanes[laneIdx]) {
        final double start =
            event.startTime.hour + (event.startTime.minute / 60.0);
        final double end =
            event.endTime.hour + (event.endTime.minute / 60.0);
        final double duration = end - start;

        final double top = start * hourHeight;
        final double height = duration * hourHeight;

        final bool isCompact = height < 50 || eventWidth < 60;
        final color = _getRandomColor(event.title);

        widgets.add(Positioned(
          top: top,
          left: laneIdx * eventWidth,
          width: eventWidth,
          height: height,
          child: BouncyButton(
            onTap: () {
              onDateSelected(event.startTime);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 2, bottom: 2),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        maxLines: duration < 1.0 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (!isCompact && event.location != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            event.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }

    return widgets;
  }

  Color _getRandomColor(String title) {
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

  Widget _buildCurrentTimeIndicator(
      DateTime now, DateTime weekStart, double hourHeight, ThemeData theme) {
    final dayIndex = now.difference(weekStart).inDays;
    if (dayIndex < 0 || dayIndex > 6) return const SizedBox();

    final double top = (now.hour + (now.minute / 60.0)) * hourHeight;

    return Positioned(
        left: 0,
        right: 0,
        top: top,
        child: Row(
          children: [
            ...List.generate(dayIndex, (_) => const Spacer()),
            Expanded(
                child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 2, color: theme.colorScheme.error),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.error, shape: BoxShape.circle),
                ),
              ],
            )),
            ...List.generate(6 - dayIndex, (_) => const Spacer()),
          ],
        ));
  }
}