#import "MRRLayoutScaling.h"

static CGFloat const MRRLayoutBaseViewportWidth = 390.0;
static CGFloat const MRRLayoutBaseViewportHeight = 844.0;

CGFloat MRRLayoutClampedFloat(CGFloat value, CGFloat minimumValue, CGFloat maximumValue) {
  return MIN(MAX(value, minimumValue), maximumValue);
}

CGFloat MRRLayoutRoundedMetric(CGFloat value) {
  return round(value * 10.0) / 10.0;
}

static CGFloat MRRLayoutNormalizedProgress(CGFloat value, CGFloat minimumValue, CGFloat maximumValue) {
  if (maximumValue <= minimumValue) {
    return 0.0;
  }

  return MRRLayoutClampedFloat((value - minimumValue) / (maximumValue - minimumValue), 0.0, 1.0);
}

CGFloat MRRLayoutInterpolatedMetricForValue(CGFloat value,
                                            CGFloat inputMinimum,
                                            CGFloat inputMaximum,
                                            CGFloat outputMinimum,
                                            CGFloat outputMaximum) {
  CGFloat progress = MRRLayoutNormalizedProgress(value, inputMinimum, inputMaximum);
  return outputMinimum + ((outputMaximum - outputMinimum) * progress);
}

CGFloat MRRLayoutScaleFactor(CGSize viewportSize, MRRLayoutScaleAxis axis) {
  CGFloat dimension = 1.0;
  CGFloat baseDimension = 1.0;

  switch (axis) {
    case MRRLayoutScaleAxisWidth:
      dimension = viewportSize.width;
      baseDimension = MRRLayoutBaseViewportWidth;
      break;
    case MRRLayoutScaleAxisHeight:
      dimension = viewportSize.height;
      baseDimension = MRRLayoutBaseViewportHeight;
      break;
    case MRRLayoutScaleAxisMinDimension:
      dimension = MIN(viewportSize.width, viewportSize.height);
      baseDimension = MIN(MRRLayoutBaseViewportWidth, MRRLayoutBaseViewportHeight);
      break;
  }

  if (dimension <= 0.0 || baseDimension <= 0.0) {
    return 1.0;
  }

  return dimension / baseDimension;
}

CGFloat MRRLayoutScaledValue(CGFloat baseValue, CGSize viewportSize, MRRLayoutScaleAxis axis) {
  return MRRLayoutRoundedMetric(baseValue * MRRLayoutScaleFactor(viewportSize, axis));
}
