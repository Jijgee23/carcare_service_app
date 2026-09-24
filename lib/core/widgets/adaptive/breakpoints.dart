import 'package:flutter/widgets.dart';

/// Width tiers used by the tenant application.
enum AdaptiveSize { phone, compactTablet, tablet }

abstract final class AdaptiveBreakpoints {
  static const double compact = 600;
  static const double expanded = 840;

  /// Width from which the navigation rail shows labels (extended).
  static const double extendedRail = 1200;

  static AdaptiveSize ofWidth(double width) {
    if (width < compact) return AdaptiveSize.phone;
    if (width < expanded) return AdaptiveSize.compactTablet;
    return AdaptiveSize.tablet;
  }

  static AdaptiveSize of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);
}
