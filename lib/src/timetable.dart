import 'package:flutter/material.dart';
import 'package:flutter_timetable/src/timetable_scroll_physics.dart';
import 'package:intl/intl.dart';

import '../flutter_timetable.dart';

enum ScrollType { heavy, medium, page, none }

/// The [Timetable] widget displays calendar like view of the events that scrolls
/// horizontally through the days and vertical through the hours.
/// <img src="https://github.com/gettuned/flutter_timetable/raw/main/images/default.gif" width="400" />
class Timetable<T> extends StatefulWidget {
  /// [TimetableController] is the controller that also initialize the timetable.
  final TimetableController? controller;

  /// Renders for the cells the represent each hour that provides that [DateTime] for that hour
  final Widget Function(DateTime)? cellBuilder;

  /// Renders for the header that provides the [DateTime] for the day
  final Widget Function(DateTime)? headerCellBuilder;

  /// Timetable items to display in the timetable
  final List<TimetableItem<T>> items;

  /// Renders event card from `TimetableItem<T>` for each item
  final Widget Function(TimetableItem<T>)? itemBuilder;

  /// Renders hour label given [TimeOfDay] for each hour
  final Widget Function(TimeOfDay time)? hourLabelBuilder;

  /// Renders upper left corner of the timetable given the first visible date
  final Widget Function(DateTime current)? cornerBuilder;

  /// Snap to hour column. Default is `true`.
  final bool snapToDay;

  /// Snap animation curve. Default is `Curves.bounceOut`
  final Curve snapAnimationCurve;

  /// Snap animation duration. Default is 300 ms
  final Duration snapAnimationDuration;

  /// Color of indicator line that shows the current time. Default is `Theme.indicatorColor`.
  final Color? nowIndicatorColor;

  /// ScrollType to use
  final ScrollType? scrollType;

  final Future<void> Function()? onRefresh;

  /// The [Timetable] widget displays calendar like view of the events that scrolls
  /// horizontally through the days and vertical through the hours.
  /// <img src="https://github.com/gettuned/flutter_timetable/raw/main/images/default.gif" width="400" />
  const Timetable(
      {Key? key,
      this.controller,
      this.cellBuilder,
      this.headerCellBuilder,
      this.items = const [],
      this.itemBuilder,
      this.hourLabelBuilder,
      this.nowIndicatorColor,
      this.cornerBuilder,
      this.snapToDay = true,
      this.snapAnimationDuration = const Duration(milliseconds: 300),
      this.snapAnimationCurve = Curves.bounceOut,
      this.scrollType = ScrollType.none,
      this.onRefresh})
      : super(key: key);

  @override
  State<Timetable<T>> createState() => _TimetableState<T>();
}

class _TimetableState<T> extends State<Timetable<T>> {
  final _dayScrollController = ScrollController();
  final _dayHeadingScrollController = ScrollController();
  final _timeScrollController = ScrollController();

  double columnWidth = 0.0;
  TimetableController controller = TimetableController();
  final _key = GlobalKey();

  ScrollPhysics? _horizontalScrollPhysics;

  Color get nowIndicatorColor => widget.nowIndicatorColor ?? Theme.of(context).indicatorColor;
  int? _listenerId;
  @override
  void initState() {
    controller = widget.controller ?? controller;
    _listenerId = controller.addListener(_eventHandler);
    _horizontalScrollPhysics = _getHorizontalScrollPhysics();

    if (widget.items.isNotEmpty) {
      widget.items.sort((a, b) => a.start.compareTo(b.start));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => adjustColumnWidth());

    super.initState();
  }

  ScrollPhysics? _getHorizontalScrollPhysics() {
    switch (widget.scrollType) {
      case ScrollType.heavy:
        return const TimetableHeavyScrollPhysics();

      case ScrollType.medium:
        return const TimetableMediumScrollPhysics();

      case ScrollType.page:
        return const TimetablePageScrollPhysics();
      case ScrollType.none:
      case null:
        return null;
    }
  }

  @override
  void dispose() {
    if (_listenerId != null) {
      controller.removeListener(_listenerId!);
    }
    _dayScrollController.dispose();
    _dayHeadingScrollController.dispose();
    _timeScrollController.dispose();
    super.dispose();
  }

  _eventHandler(TimetableControllerEvent event) async {
    if (event is TimetableJumpToRequested) {
      _jumpTo(event.date, animationDuration: event.animationDuration);
    }

    if (event is TimetableColumnsChanged) {
      final prev = controller.visibleDateStart;
      final now = DateTime.now().toUtc().add(controller.timeZoneOffset);
      await adjustColumnWidth();
      _jumpTo(DateTime.utc(prev.year, prev.month, prev.day, now.hour, now.minute));
      return;
    }

    if (mounted) setState(() {});
  }

  Future adjustColumnWidth() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    if (box.hasSize) {
      final size = box.size;
      final layoutWidth = size.width;
      final width = (layoutWidth - controller.timelineWidth) / controller.columns;
      if (width != columnWidth) {
        columnWidth = width;
        await Future.microtask(() => null);
        setState(() {});
      }
    }
  }

  bool _isTableScrolling = false;
  bool _isHeaderScrolling = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      key: _key,
      builder: (context, contraints) {
        final now = DateTime.now().toUtc().add(controller.timeZoneOffset);
        return Column(
          children: [
            SizedBox(
              height: controller.headerHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: controller.timelineWidth,
                    height: controller.headerHeight,
                    child: _buildCorner(),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (_isTableScrolling) return false;
                        if (notification is ScrollEndNotification) {
                          _snapToClosest();
                          _updateVisibleDate();
                          _isHeaderScrolling = false;
                          return true;
                        } else if (notification is ScrollUpdateNotification) {
                          _isHeaderScrolling = true;
                          _dayScrollController.jumpTo(_dayHeadingScrollController.position.pixels);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: _horizontalScrollPhysics,
                        controller: _dayHeadingScrollController,
                        itemExtent: columnWidth,
                        itemBuilder: (context, i) => SizedBox(
                          width: columnWidth,
                          child: _buildHeaderCell(i),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_isHeaderScrolling) return false;
                  if (notification is ScrollEndNotification) {
                    _snapToClosest();
                    _updateVisibleDate();
                    _isTableScrolling = false;
                    return true;
                  } else if (notification is ScrollUpdateNotification &&
                      (notification.metrics.axisDirection == AxisDirection.right ||
                          notification.metrics.axisDirection == AxisDirection.left)) {
                    _isTableScrolling = true;
                    _dayHeadingScrollController.jumpTo(_dayScrollController.position.pixels);
                  }
                  return true;
                },
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (widget.onRefresh != null) {
                      await widget.onRefresh!();
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _timeScrollController,
                    child: SizedBox(
                      height: controller.cellHeight * 24.0,
                      child: Row(
                        children: [
                          SizedBox(
                            width: controller.timelineWidth,
                            height: controller.cellHeight * 24.0,
                            child: Column(
                              children: [
                                SizedBox(height: controller.cellHeight / 2),
                                for (var i = 1; i < 24; i++) //
                                  SizedBox(
                                    height: controller.cellHeight,
                                    child: Center(child: _buildHour(TimeOfDay(hour: i, minute: 0))),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              // cacheExtent: 10000.0,
                              itemExtent: columnWidth,
                              controller: _dayScrollController,
                              physics: _horizontalScrollPhysics,
                              itemBuilder: (context, index) {
                                final date = controller.start.add(Duration(days: index));
                                final events =
                                    widget.items.where((event) => DateUtils.isSameDay(date, event.start)).toList();
                                final groupedOverlappingEvents = _getGroupedOverlappingEvents(events);
                                final isToday = DateUtils.isSameDay(date, now);
                                return Container(
                                  clipBehavior: Clip.none,
                                  width: columnWidth,
                                  height: controller.cellHeight * 24.0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Column(
                                        children: [
                                          for (int i = 0; i < 24; i++)
                                            SizedBox(
                                              width: columnWidth,
                                              height: controller.cellHeight,
                                              child: Center(
                                                child: _buildCell(date.add(Duration(hours: i))),
                                              ),
                                            ),
                                        ],
                                      ),
                                      for (final List<TimetableItem<T>> eventGroup in groupedOverlappingEvents)
                                        ...eventGroup.asMap().entries.map<Widget>((eventGroupEntry) {
                                          final i = eventGroupEntry.key;
                                          final top = (eventGroup[i].start.hour + (eventGroup[i].start.minute / 60)) *
                                              controller.cellHeight;
                                          var height = eventGroup[i].duration.inMinutes * controller.cellHeight / 60;
                                          if (top + height > controller.cellHeight * 24.0) {
                                            // if the event exceeds the bottom of the table
                                            height = controller.cellHeight * 24.0 - top;
                                          }
                                          return Positioned(
                                            top: top,
                                            height: height,
                                            left: columnWidth / eventGroup.length * i,
                                            width: columnWidth / eventGroup.length,
                                            child: _buildEvent(eventGroup[i]),
                                          );
                                        }).toList(),
                                      if (isToday)
                                        Positioned(
                                          top: ((now.hour + (now.minute / 60.0)) * controller.cellHeight) - 1,
                                          width: columnWidth,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                clipBehavior: Clip.none,
                                                color: nowIndicatorColor,
                                                height: 2,
                                                width: columnWidth + 1,
                                              ),
                                              Positioned(
                                                top: -2,
                                                left: -2,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: nowIndicatorColor,
                                                  ),
                                                  height: 6,
                                                  width: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      });

  final _dateFormatter = DateFormat('MMM\nd');

  Widget _buildHeaderCell(int i) {
    final date = controller.start.add(Duration(days: i));
    if (widget.headerCellBuilder != null) {
      return widget.headerCellBuilder!(date);
    }
    final weight = DateUtils.isSameDay(date, DateTime.now().toUtc().add(controller.timeZoneOffset))
        ? FontWeight.bold
        : FontWeight.normal;
    return Center(
      child: Text(
        _dateFormatter.format(date),
        style: TextStyle(fontSize: 12, fontWeight: weight),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCell(DateTime date) {
    if (widget.cellBuilder != null) return widget.cellBuilder!(date);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildHour(TimeOfDay time) {
    if (widget.hourLabelBuilder != null) return widget.hourLabelBuilder!(time);
    return Text(time.format(context), style: const TextStyle(fontSize: 11));
  }

  Widget _buildCorner() {
    if (widget.cornerBuilder != null) {
      return widget.cornerBuilder!(controller.visibleDateStart);
    }
    return Center(
      child: Text(
        "${controller.visibleDateStart.year}",
        textAlign: TextAlign.center,
      ),
    );
  }

  final _hmma = DateFormat("h:mm a");
  Widget _buildEvent(TimetableItem<T> event) {
    if (widget.itemBuilder != null) return widget.itemBuilder!(event);
    bool extendsBeyondMidnight = event.end.hour < event.start.hour;
    final borderSide = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 0.5,
    );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
            bottomLeft: extendsBeyondMidnight ? const Radius.circular(0) : const Radius.circular(8),
            bottomRight: extendsBeyondMidnight ? const Radius.circular(0) : const Radius.circular(8),
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8)),
        border: Border(
            top: borderSide,
            bottom: extendsBeyondMidnight ? BorderSide.none : borderSide,
            left: borderSide,
            right: borderSide),
      ),
      child: Text(
        "${_hmma.format(event.start)} - ${_hmma.format(event.end)}",
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  bool _isSnapping = false;
  Future _snapToClosest() async {
    if (_isSnapping || !widget.snapToDay) return;
    _isSnapping = true;
    await Future.microtask(() => null);
    if (!_dayScrollController.hasClients || !_dayHeadingScrollController.hasClients) {
      return;
    }
    final snapWidth =
        widget.scrollType == ScrollType.page ? columnWidth * (widget.controller?.columns ?? 1) : columnWidth;
    final snapPosition = ((_dayScrollController.offset) / snapWidth).round() * snapWidth;
    _dayScrollController.animateTo(
      snapPosition,
      duration: widget.snapAnimationDuration,
      curve: widget.snapAnimationCurve,
    );
    _dayHeadingScrollController.animateTo(
      snapPosition,
      duration: widget.snapAnimationDuration,
      curve: widget.snapAnimationCurve,
    );
    _isSnapping = false;
  }

  _updateVisibleDate() async {
    final date = controller.start.add(Duration(
      days: (_dayHeadingScrollController.position.pixels / columnWidth).round(),
      hours: _timeScrollController.position.pixels ~/ controller.cellHeight,
    ));
    if (date != controller.visibleDateStart) {
      controller.updateVisibleDate(date);
      setState(() {});
    }
  }

  Future _jumpTo(DateTime date, {Duration? animationDuration}) async {
    if (!_dayScrollController.hasClients || !_dayHeadingScrollController.hasClients) {
      return;
    }
    final duration = animationDuration ?? const Duration(microseconds: 1);
    final datePosition = (date.difference(controller.start).inDays) * columnWidth;
    final hourPosition = ((date.hour) * controller.cellHeight) - (controller.cellHeight / 2);
    _isSnapping = true;
    await Future.wait([
      _dayScrollController.animateTo(datePosition, duration: duration, curve: Curves.linear),
      _timeScrollController.animateTo(hourPosition, duration: duration, curve: Curves.linear)
    ]);
    _isSnapping = false;
    _snapToClosest();
  }

  List<List<TimetableItem<T>>> _getGroupedOverlappingEvents(List<TimetableItem<T>> events) {
    events.sort((a, b) => a.start.compareTo(b.start));
    List<List<TimetableItem<T>>> overlappingList = [];
    for (var element in events) {
      if (overlappingList.isEmpty) {
        overlappingList.add(List.of([element]));
        continue;
      }
      if (overlappingList.last.any((prev) => element.start.compareTo(prev.end) < 0)) {
        overlappingList.last.add(element);
      } else {
        overlappingList.add(List.of([element]));
      }
    }
    return overlappingList;
  }
}
