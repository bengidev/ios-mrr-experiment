#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRRLayoutScaleAxis) {
  MRRLayoutScaleAxisWidth,
  MRRLayoutScaleAxisHeight,
  MRRLayoutScaleAxisMinDimension,
};

FOUNDATION_EXTERN CGFloat MRRLayoutClampedFloat(CGFloat value, CGFloat minimumValue, CGFloat maximumValue);
FOUNDATION_EXTERN CGFloat MRRLayoutRoundedMetric(CGFloat value);
FOUNDATION_EXTERN CGFloat MRRLayoutInterpolatedMetricForValue(CGFloat value,
                                                              CGFloat inputMinimum,
                                                              CGFloat inputMaximum,
                                                              CGFloat outputMinimum,
                                                              CGFloat outputMaximum);
FOUNDATION_EXTERN CGFloat MRRLayoutScaleFactor(CGSize viewportSize, MRRLayoutScaleAxis axis);
FOUNDATION_EXTERN CGFloat MRRLayoutScaledValue(CGFloat baseValue, CGSize viewportSize, MRRLayoutScaleAxis axis);

NS_ASSUME_NONNULL_END
