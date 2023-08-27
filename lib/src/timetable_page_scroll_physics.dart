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
    if (velocity == 0) { //prevent returning to start of page
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
