import 'dart:math';

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
  const TimetableHeavyScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  TimetableHeavyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TimetableHeavyScrollPhysics(parent: buildParent(ancestor));
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

class TimetableMediumScrollPhysics extends ClampingScrollPhysics {
  const TimetableMediumScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  TimetableMediumScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TimetableMediumScrollPhysics(parent: buildParent(ancestor));
  }

  // @override
  // double get dragStartDistanceMotionThreshold => 10;

  // @override
  // double get minFlingVelocity => 5;

  @override
  double get maxFlingVelocity => 1300;

  // @override
  // double get minFlingDistance => 10;

  //copied from ClampingScrollPhysics, only updated friction
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        end!,
        min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
      friction: 0.4
    );
  }
}
