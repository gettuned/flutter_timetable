import 'package:flutter/widgets.dart';

class TimetablePageScrollPhysics extends PageScrollPhysics {
  const TimetablePageScrollPhysics({super.parent});

  @override
  TimetablePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TimetablePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if (velocity == 0) {
      //prevent returning to start of page
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

class TimetableHeavyScrollPhysics extends ScrollPhysics {
  const TimetableHeavyScrollPhysics(
      {ScrollPhysics? parent})
      : super(parent: parent);

  @override
  TimetableHeavyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TimetableHeavyScrollPhysics(
        parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 40;

  @override
  double get minFlingVelocity => double.infinity;

  @override
  double get maxFlingVelocity => double.infinity;

  @override
  double get minFlingDistance => double.infinity;
}
