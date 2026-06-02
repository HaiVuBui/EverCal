/// dialogs.dart
///
/// Contains the dialog widgets used for Location/Weather settings and Adding Events.

import 'package:flutter/material.dart';
import 'models.dart';
import 'utils.dart';

InputDecoration _dialogInputDecor(ThemeData theme) => InputDecoration(
      filled: true,
      fillColor: theme.brightness == Brightness.light
          ? Colors.black.withOpacity(0.1)
          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

Widget _dialogFieldLabel(ThemeData theme, String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

// Dialog for Weather Location and Unit settings
class LocationSettingsDialog extends StatefulWidget {
  final WeatherUnit currentUnit;
  const LocationSettingsDialog({super.key, required this.currentUnit});

  @override
  State<LocationSettingsDialog> createState() => _LocationSettingsDialogState();
}

class _LocationSettingsDialogState extends State<LocationSettingsDialog> {
  late WeatherUnit tempUnit;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    tempUnit = widget.currentUnit;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final OutlineInputBorder borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        'Weather Settings',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CITY INPUT
          TextField(
            controller: controller,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: 'City Name',
              hintText: 'e.g. Vancouver, Tokyo',
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: borderStyle,
              enabledBorder: borderStyle,
              focusedBorder: borderStyle.copyWith(
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              suffixIcon:
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),

          // UNIT DROPDOWN LABEL
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Temperature Unit',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),

          // UNIT DROPDOWN
          DropdownButtonFormField<WeatherUnit>(
            value: tempUnit,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: borderStyle,
              enabledBorder: borderStyle,
              focusedBorder: borderStyle.copyWith(
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            dropdownColor: theme.colorScheme.surfaceContainerHigh,
            items: const [
              DropdownMenuItem(
                  value: WeatherUnit.celsius, child: Text('Celsius (°C)')),
              DropdownMenuItem(
                  value: WeatherUnit.fahrenheit,
                  child: Text('Fahrenheit (°F)')),
              DropdownMenuItem(
                  value: WeatherUnit.kelvin, child: Text('Kelvin (K)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => tempUnit = val);
            },
          ),
          const SizedBox(height: 24),

          // RESET BUTTON
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(context, {'useAuto': true, 'unit': tempUnit});
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon:
                const Icon(Icons.my_location, size: 15, color: Color(0xFFD69999)),
            label: const Text(
              'Reset to Auto-Detect',
              style: TextStyle(color: Color(0xFFD69999)),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, {'city': controller.text, 'unit': tempUnit}),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Dialog for Adding a New Event
class AddEventDialog extends StatefulWidget {
  final DateTime initialSelectedDate;
  final String Function(String input) fnv1aHex;
  final Function(DateTime, CalendarEvent) onSave;
  final CalendarEvent? existingEvent;

  const AddEventDialog({
    super.key,
    required this.initialSelectedDate,
    required this.fnv1aHex,
    required this.onSave,
    this.existingEvent,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedFreq = 'NONE';
  final freqOptions = {
    'NONE': 'Does not repeat',
    'DAILY': 'Daily',
    'WEEKLY': 'Weekly',
    'MONTHLY': 'Monthly',
    'YEARLY': 'Yearly',
  };

  late DateTime startDate;
  late TimeOfDay startTime;
  late DateTime endDate;
  late TimeOfDay endTime;

  bool get _isEditing => widget.existingEvent != null;
  bool get _isSingleOccurrenceEdit =>
      widget.existingEvent != null &&
      (((widget.existingEvent!.rrule != null &&
                  widget.existingEvent!.rrule!.isNotEmpty) ||
              widget.existingEvent!.isGenerated));

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    final now = DateTime.now();
    final base = widget.initialSelectedDate;

    DateTime start;
    DateTime end;

    if (existing != null) {
      titleController.text = existing.title;
      locationController.text = existing.location ?? '';
      descriptionController.text = existing.description ?? '';
      start = existing.startTime;
      end = existing.endTime;

      if (_isSingleOccurrenceEdit) {
        selectedFreq = 'NONE';
      } else if (existing.rrule != null && existing.rrule!.isNotEmpty) {
        final match = RegExp(r'FREQ=([^;]+)').firstMatch(existing.rrule!);
        selectedFreq = match?.group(1)?.toUpperCase() ?? 'NONE';
      }
    } else {
      final initialHour = base.hour > 0 ? base.hour : now.hour;
      start = DateTime(base.year, base.month, base.day, initialHour, base.minute);
      end = start.add(const Duration(hours: 1));
    }

    startDate = DateTime(start.year, start.month, start.day);
    startTime = TimeOfDay(hour: start.hour, minute: start.minute);

    endDate = DateTime(end.year, end.month, end.day);
    endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickDateTime(bool isStart) async {
    final initialDate = isStart ? startDate : endDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (pickedDate != null) {
      final initialTime = isStart ? startTime : endTime;
      final pickedTime =
          await showTimePicker(context: context, initialTime: initialTime);
      if (pickedTime != null) {
        setState(() {
          if (isStart) {
            startDate = pickedDate;
            startTime = pickedTime;
          } else {
            endDate = pickedDate;
            endTime = pickedTime;
          }
        });
      }
    }
  }

  Widget _buildDateTimeSelector(BuildContext context, String label,
      DateTime date, TimeOfDay time, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(fmtGridDay.format(date)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    time.format(context),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDecor = _dialogInputDecor(theme);

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Event' : 'New Event',
        textAlign: TextAlign.center,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),

      // CONTENT BOX
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45, // 45% of the window
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TITLE
              _dialogFieldLabel(theme,'Title'),
              TextField(
                controller: titleController,
                decoration: inputDecor,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // ROW: LOCATION + REPEAT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogFieldLabel(theme,'Location'),
                        TextField(
                          controller: locationController,
                          decoration: inputDecor,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogFieldLabel(theme,'Repeat'),
                        DropdownButtonFormField<String>(
                          value: selectedFreq,
                          decoration: inputDecor,
                          dropdownColor: theme.colorScheme.surfaceContainerHigh,
                          disabledHint: Text(
                            freqOptions[selectedFreq] ?? 'Does not repeat',
                            style: const TextStyle(fontSize: 14),
                          ),
                          items: freqOptions.entries.map((e) {
                            return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 14)));
                          }).toList(),
                          onChanged: _isSingleOccurrenceEdit
                              ? null
                              : (val) => setState(() => selectedFreq = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // ROW: STARTS + ENDS
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeSelector(
                        context, 'Starts', startDate, startTime,
                        () => pickDateTime(true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateTimeSelector(
                        context, 'Ends', endDate, endTime,
                        () => pickDateTime(false)),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // DESCRIPTION
              _dialogFieldLabel(theme,'Description'),
              TextField(
                controller: descriptionController,
                decoration: inputDecor,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (titleController.text.isEmpty) return;
            final s = DateTime(startDate.year, startDate.month, startDate.day,
                startTime.hour, startTime.minute);
            final e = DateTime(endDate.year, endDate.month, endDate.day,
                endTime.hour, endTime.minute);

            String? rrule;
            if (selectedFreq != null && selectedFreq != 'NONE') {
              rrule = 'FREQ=$selectedFreq';
            }

            final existing = widget.existingEvent;
            final sig = existing == null
                ? 'manual|${titleController.text}|${s.toIso8601String()}|${e.toIso8601String()}|$rrule'
                : 'manual_edit|${existing.id}|${titleController.text}|${s.toIso8601String()}|${e.toIso8601String()}|$rrule';
            final id = existing?.id ?? 'man_${widget.fnv1aHex(sig)}';

            final newEvent = CalendarEvent(
              id: id,
              title: titleController.text,
              startTime: s,
              endTime: e,
              location: locationController.text,
              description: descriptionController.text,
              sourceId: existing?.sourceId,
              rrule: rrule,
              exceptionDates: existing?.exceptionDates ?? const [],
              isHidden: existing?.isHidden ?? false,
            );

            widget.onSave(s, newEvent);
            Navigator.pop(context);
          },
          child: Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}

class AddGoalDialog extends StatefulWidget {
  final DateTime initialDate;
  final String Function(String) fnv1aHex;
  final Function(GoalItem) onSave;
  final GoalItem? existingGoal;

  const AddGoalDialog({
    super.key,
    required this.initialDate,
    required this.fnv1aHex,
    required this.onSave,
    this.existingGoal,
  });

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final _titleController = TextEditingController();
  bool _hasDate = false;
  late DateTime _date;
  bool _hasTime = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingGoal;
    if (existing != null) {
      _titleController.text = existing.title;
      _hasDate = existing.date != null;
      _date = existing.date != null
          ? DateTime(existing.date!.year, existing.date!.month, existing.date!.day)
          : DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
      _hasTime = existing.hasTime;
      if (existing.hasTime) _time = TimeOfDay(hour: existing.hour, minute: existing.minute);
    } else {
      _date = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDecor = _dialogInputDecor(theme);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Goal' : 'New Goal', textAlign: TextAlign.center),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dialogFieldLabel(theme, 'Title'),
              TextField(
                controller: _titleController,
                decoration: inputDecor,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _hasDate,
                    onChanged: (val) => setState(() => _hasDate = val),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Text('Set a target date',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              if (_hasDate) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('${fmtGridDay.format(_date)}, ${_date.year}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: _hasTime,
                      onChanged: (val) => setState(() => _hasTime = val),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    Text('Specify time',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (_hasTime) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: _pickTime,
                        child: Text(
                          _time.format(context),
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_titleController.text.isEmpty) return;
            final existing = widget.existingGoal;
            final now = DateTime.now();
            final id = existing?.id ??
                'goal_${widget.fnv1aHex('goal|${_titleController.text}|${_date.toIso8601String()}|${now.toIso8601String()}')}';
            widget.onSave(GoalItem(
              id: id,
              title: _titleController.text.trim(),
              isCompleted: existing?.isCompleted ?? false,
              date: _hasDate ? _date : null,
              hasTime: _hasDate && _hasTime,
              hour: _hasDate && _hasTime ? _time.hour : 0,
              minute: _hasDate && _hasTime ? _time.minute : 0,
              createdAt: existing?.createdAt ?? now,
            ));
            Navigator.pop(context);
          },
          child: Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}

class SearchDialog extends StatefulWidget {
  final Map<DateTime, List<CalendarEvent>> events;
  final ValueChanged<DateTime> onDateSelected;

  const SearchDialog({
    super.key,
    required this.events,
    required this.onDateSelected,
  });

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final _controller = TextEditingController();
  List<(DateTime, CalendarEvent)> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final q = query.toLowerCase();
    final found = <(DateTime, CalendarEvent)>[];
    for (final entry in widget.events.entries) {
      for (final event in entry.value) {
        if (event.isHidden) continue;
        if (event.title.toLowerCase().contains(q) ||
            (event.location?.toLowerCase().contains(q) ?? false) ||
            (event.description?.toLowerCase().contains(q) ?? false)) {
          found.add((entry.key, event));
        }
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    setState(() => _results = found.take(60).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search events…',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          border: InputBorder.none,
        ),
        onChanged: _search,
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45,
        height: 380,
        child: _results.isEmpty
            ? Center(
                child: Text(
                  _controller.text.isEmpty ? 'Start typing to search' : 'No results',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final (date, event) = _results[i];
                  return ListTile(
                    leading: Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(fmtSearchDate.format(date)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDateSelected(date);
                    },
                  );
                },
              ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
