/// components.dart
///
/// Contains reusable UI widgets like buttons, the event card, and the view switcher.
/// i.e. ExpressiveButton, BouncyButton, EventCard, and ViewSwitcher.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'models.dart';
import 'utils.dart'; // for fmtTime
import 'package:url_launcher/url_launcher.dart';

final _editActionButtonStyle = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

Widget _menuRow(ThemeData theme, IconData icon, String label, Color iconColor) =>
    Row(children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              color: iconColor == theme.colorScheme.error ? iconColor : null)),
    ]);

// Button based on M3 expressive guidelines
class ExpressiveButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final bool isSelected;
  final double size;
  final BorderSide side;

  const ExpressiveButton({
    super.key,
    required this.child,
    this.onTap,
    required this.color,
    this.isSelected = false,
    this.size = 50,
    this.side = BorderSide.none,
  });

  @override
  State<ExpressiveButton> createState() => _ExpressiveButtonState();
}

class _ExpressiveButtonState extends State<ExpressiveButton> {
  bool _isPressed = false;

  late ShapeBorder _idleShape;
  late ShapeBorder _morphShape;

  static const BoxShadow _inactiveShadow = BoxShadow(
    color: Colors.transparent,
    blurRadius: 6,
    spreadRadius: -1,
    offset: Offset(0, 3),
  );

  static const BoxShadow _activeShadow = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 6,
    spreadRadius: -1,
    offset: Offset(0, 3),
  );

  @override
  void initState() {
    super.initState();
    _rebuildShapes();
  }

  @override
  void didUpdateWidget(covariant ExpressiveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side != widget.side) {
      _rebuildShapes();
    }
  }

  void _rebuildShapes() {
    _idleShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: widget.side,
    );

    _morphShape = StarBorder(
      points: 8,
      innerRadiusRatio: 0.85,
      pointRounding: 0.5,
      valleyRounding: 0.5,
      side: widget.side,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shape = _isPressed ? _morphShape : _idleShape;
    final shadow =
        (_isPressed || widget.isSelected) ? _activeShadow : _inactiveShadow;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: widget.size,
        height: widget.size,
        decoration: ShapeDecoration(
          color: widget.color,
          shape: shape,
          shadows: [shadow],
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

// Bouncy button effect for event cards in week view
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncyButton({super.key, required this.child, required this.onTap});

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90), // Quick, snappy duration
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        ),
      ),
    );
  }
}

class ViewSwitcher extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isMonthView;
  final bool compact;
  final VoidCallback onTap;
  final ThemeData theme;

  const ViewSwitcher({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isMonthView,
    required this.compact,
    required this.onTap,
    required this.theme,
  });

  @override
  State<ViewSwitcher> createState() => _ViewSwitcherState();
}

class _ViewSwitcherState extends State<ViewSwitcher> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final titleStyle = widget.compact
        ? widget.theme.textTheme.headlineMedium
        : widget.theme.textTheme.displayMedium;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.theme.colorScheme.onSurface.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: titleStyle?.copyWith(
                      height: 1.0, 
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      color: widget.theme.colorScheme.onSurface.withOpacity(0.5),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: widget.isMonthView ? 0 : 0.5,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: widget.compact ? 32 : 42,
                  color: _isHovered
                      ? widget.theme.colorScheme.primary
                      : widget.theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool use24Hour;

  const EventCard({
    super.key,
    required this.event,
    required this.onDelete,
    this.onEdit,
    this.use24Hour = false,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = eventColor(widget.event.title);

    final fmt = widget.use24Hour ? fmtTime24 : fmtTime;
    final timeLabel = widget.event.isAllDay
        ? 'All day'
        : '${fmt.format(widget.event.startTime)} – ${fmt.format(widget.event.endTime)}';

    return GestureDetector(
      onSecondaryTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        final offset = box?.localToGlobal(details.localPosition) ?? details.globalPosition;
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 1, offset.dy + 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          items: [
            if (widget.onEdit != null)
              PopupMenuItem(
                onTap: widget.onEdit,
                child: _menuRow(theme,Icons.edit_outlined, 'Edit', theme.colorScheme.primary),
              ),
            PopupMenuItem(
              onTap: widget.onDelete,
              child: _menuRow(theme,Icons.delete_outline, 'Delete', theme.colorScheme.error),
            ),
          ],
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  splashColor: color.withOpacity(0.3),
                  highlightColor: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.event.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Divider(
                          color: theme.colorScheme.outline.withOpacity(0.1)),
                      const SizedBox(height: 8),
                      if (widget.event.location != null &&
                          widget.event.location!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(widget.event.location!,
                                      style: TextStyle(
                                          color: theme.colorScheme
                                              .onSurfaceVariant))),
                            ],
                          ),
                        ),
                      if (widget.event.description != null &&
                          widget.event.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes, size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _EventDescriptionText(
                                text: widget.event.description!,
                                style: TextStyle(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                                linkStyle: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              )),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (widget.onEdit != null)
                              TextButton.icon(
                                onPressed: widget.onEdit,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                label: Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: theme.colorScheme.error),
                              label: Text('Delete',
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _EventDescriptionText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const _EventDescriptionText({
    required this.text,
    this.style,
    this.linkStyle,
  });

  @override
  State<_EventDescriptionText> createState() => _EventDescriptionTextState();
}

class _EventDescriptionTextState extends State<_EventDescriptionText> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final RegExp _urlPattern = RegExp(r'https?:\/\/[^\s]+');
  static final RegExp _trailingUrlPunctuation = RegExp(r'[.,;:!?\)\]]+$');

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  List<InlineSpan> _buildSpans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex, match.start),
          style: widget.style,
        ));
      }

      final rawUrl = match.group(0)!;
      final trimmedUrl = rawUrl.replaceFirst(_trailingUrlPunctuation, '');
      final trailingText = rawUrl.substring(trimmedUrl.length);
      final recognizer =
          TapGestureRecognizer()..onTap = () => _openUrl(trimmedUrl);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: trimmedUrl,
        style: widget.linkStyle ?? widget.style,
        recognizer: recognizer,
      ));

      if (trailingText.isNotEmpty) {
        spans.add(TextSpan(
          text: trailingText,
          style: widget.style,
        ));
      }

      currentIndex = match.end;
    }

    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(currentIndex),
        style: widget.style,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(children: _buildSpans(), style: widget.style),
    );
  }
}

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final CalendarEvent? linkedEvent;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onJumpToEvent;
  final VoidCallback? onAttachEvent;
  final VoidCallback? onRemoveEvent;
  final VoidCallback? onEdit;
  final bool isEditing;
  final TextEditingController? editController;
  final VoidCallback? onEditSubmit;
  final VoidCallback? onEditCancel;

  const TodoCard({
    super.key,
    required this.todo,
    this.linkedEvent,
    required this.onToggle,
    required this.onDelete,
    this.onJumpToEvent,
    this.onAttachEvent,
    this.onRemoveEvent,
    this.onEdit,
    this.isEditing = false,
    this.editController,
    this.onEditSubmit,
    this.onEditCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = todo.isCompleted;

    return GestureDetector(
      onSecondaryTapUp: isEditing
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              final offset = box?.localToGlobal(details.localPosition) ??
                  details.globalPosition;
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                    offset.dx, offset.dy, offset.dx + 1, offset.dy + 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                items: [
                  if (onEdit != null)
                    PopupMenuItem(
                      onTap: onEdit,
                      child: _menuRow(theme, Icons.edit_outlined, 'Edit',
                          theme.colorScheme.onSurface),
                    ),
                  if (onAttachEvent != null)
                    PopupMenuItem(
                      onTap: onAttachEvent,
                      child: _menuRow(
                          theme,
                          Icons.event_outlined,
                          linkedEvent != null ? 'Change event' : 'Attach event',
                          theme.colorScheme.primary),
                    ),
                  if (linkedEvent != null && onRemoveEvent != null)
                    PopupMenuItem(
                      onTap: onRemoveEvent,
                      child: _menuRow(theme, Icons.link_off, 'Remove event',
                          theme.colorScheme.onSurfaceVariant),
                    ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: _menuRow(theme, Icons.delete_outline, 'Delete',
                        theme.colorScheme.error),
                  ),
                ],
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: done,
              onChanged: isEditing ? null : (_) => onToggle(),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextField(
                        controller: editController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onSubmitted: (_) => onEditSubmit?.call(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        todo.title,
                        style: TextStyle(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? theme.colorScheme.onSurface.withOpacity(0.4)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: onEditSubmit,
                            style: _editActionButtonStyle,
                            child: const Text('Save',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: onEditCancel,
                            style: _editActionButtonStyle,
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  if (!isEditing && linkedEvent != null)
                    Builder(builder: (_) {
                      final color = eventColor(linkedEvent!.title);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: GestureDetector(
                          onTap: onJumpToEvent,
                          child: MouseRegion(
                            cursor: onJumpToEvent != null
                                ? SystemMouseCursors.click
                                : MouseCursor.defer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_outlined,
                                      size: 12, color: color),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      linkedEvent!.title,
                                      style: TextStyle(
                                          fontSize: 11, color: color),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodosPanel extends StatefulWidget {
  final List<TodoItem> todos;
  final List<CalendarEvent> dayEvents;
  final Map<DateTime, List<CalendarEvent>> allEvents;
  final Function(String title, String? linkedEventId) onAdd;
  final Function(String id) onToggle;
  final Function(String id) onDelete;
  final Function(CalendarEvent event) onJumpToEvent;
  final Function(String todoId, String? eventId) onLink;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(String id, String newTitle) onEdit;

  const TodosPanel({
    super.key,
    required this.todos,
    required this.dayEvents,
    required this.allEvents,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.onJumpToEvent,
    required this.onLink,
    required this.onReorder,
    required this.onEdit,
  });

  @override
  State<TodosPanel> createState() => _TodosPanelState();
}

class _TodosPanelState extends State<TodosPanel> {
  final _controller = TextEditingController();
  final _editController = TextEditingController();
  String? _selectedEventId;
  String? _editingTodoId;
  late Map<String, CalendarEvent> _eventById;

  @override
  void initState() {
    super.initState();
    _eventById = _buildEventMap();
  }

  @override
  void didUpdateWidget(TodosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.allEvents, widget.allEvents)) {
      _eventById = _buildEventMap();
    }
  }

  Map<String, CalendarEvent> _buildEventMap() => {
        for (final events in widget.allEvents.values)
          for (final e in events) e.id: e,
      };

  void _startEdit(TodoItem todo) {
    _editController.text = todo.title;
    setState(() => _editingTodoId = todo.id);
  }

  void _submitEdit(String todoId) {
    final newTitle = _editController.text.trim();
    if (newTitle.isNotEmpty) widget.onEdit(todoId, newTitle);
    setState(() => _editingTodoId = null);
  }

  void _cancelEdit() {
    setState(() => _editingTodoId = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _showEventPicker(
      BuildContext context, String todoId) async {
    if (widget.dayEvents.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Attach Event', textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.4,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.dayEvents.length,
              itemBuilder: (_, i) {
                final event = widget.dayEvents[i];
                return ListTile(
                  leading: Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: eventColor(event.title),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(event.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    event.isAllDay ? 'All day' : fmtTime.format(event.startTime),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onLink(todoId, event.id);
                  },
                );
              },
            ),
          ),
          actionsPadding: EdgeInsets.zero,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title, _selectedEventId);
    _controller.clear();
    setState(() => _selectedEventId = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDecor = InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    );

    return Column(
      children: [
        Expanded(
          child: widget.todos.isEmpty
              ? Center(
                  child: Text(
                    'No Todos',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.5)),
                  ),
                )
              : ReorderableListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: widget.todos.length,
                  onReorder: widget.onReorder,
                  itemBuilder: (context, i) {
                    final todo = widget.todos[i];
                    final linked = todo.linkedEventId != null
                        ? _eventById[todo.linkedEventId]
                        : null;
                    final editing = _editingTodoId == todo.id;
                    return TodoCard(
                      key: ValueKey(todo.id),
                      todo: todo,
                      linkedEvent: linked,
                      onToggle: () => widget.onToggle(todo.id),
                      onDelete: () => widget.onDelete(todo.id),
                      onJumpToEvent:
                          linked != null ? () => widget.onJumpToEvent(linked) : null,
                      onAttachEvent: () =>
                          _showEventPicker(context, todo.id),
                      onRemoveEvent: linked != null
                          ? () => widget.onLink(todo.id, null)
                          : null,
                      onEdit: () => _startEdit(todo),
                      isEditing: editing,
                      editController: _editController,
                      onEditSubmit: () => _submitEdit(todo.id),
                      onEditCancel: _cancelEdit,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.dayEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String?>(
                    value: widget.dayEvents.any((e) => e.id == _selectedEventId)
                        ? _selectedEventId
                        : null,
                    hint: Text(
                      'Attach event (optional)',
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.6)),
                    ),
                    decoration: inputDecor,
                    dropdownColor: theme.colorScheme.surfaceContainerHigh,
                    style: TextStyle(
                        fontSize: 13, color: theme.colorScheme.onSurface),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('None')),
                      ...widget.dayEvents.map((e) => DropdownMenuItem<String?>(
                            value: e.id,
                            child: Text(e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedEventId = val),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: inputDecor.copyWith(
                        hintText: 'New todo...',
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                            fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submit,
                    icon:
                        Icon(Icons.add_circle, color: theme.colorScheme.primary),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
