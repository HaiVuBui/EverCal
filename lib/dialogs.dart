import 'package:flutter/material.dart';
import 'models.dart';
import 'utils.dart';

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
      ((widget.existingEvent!.rrule != null &&
              widget.existingEvent!.rrule!.isNotEmpty) ||
          widget.existingEvent!.isGenerated);

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
      start = DateTime(base.year, base.month, base.day, now.hour, 0);
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

  Widget _buildLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _pickDateTime(bool isStart) async {
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
    final isLight = theme.brightness == Brightness.light;
    final inputDecor = InputDecoration(
      filled: true,
      fillColor: isLight
          ? Colors.black.withOpacity(0.1)
          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Event' : 'New Event',
        textAlign: TextAlign.center,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLabel(context, 'Title'),
              TextField(
                controller: titleController,
                decoration: inputDecor,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(context, 'Location'),
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
                        _buildLabel(context, 'Repeat'),
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
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeSelector(
                        context, 'Starts', startDate, startTime,
                        () => _pickDateTime(true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateTimeSelector(
                        context, 'Ends', endDate, endTime,
                        () => _pickDateTime(false)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLabel(context, 'Description'),
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
