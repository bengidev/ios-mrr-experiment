#import <XCTest/XCTest.h>

#import "../MRR Project/Layout/MRRLayoutScaling.h"

@interface MRRLayoutScalingTests : XCTestCase
@end

@implementation MRRLayoutScalingTests

- (void)testScreenScalingUsesRawViewportRatios {
  CGSize compactViewport = CGSizeMake(320.0, 568.0);

  CGFloat widthScaledValue = MRRLayoutScaledValue(100.0, compactViewport, MRRLayoutScaleAxisWidth);
  CGFloat heightScaledValue = MRRLayoutScaledValue(100.0, compactViewport, MRRLayoutScaleAxisHeight);

  XCTAssertEqualWithAccuracy(widthScaledValue, 82.1, 0.1);
  XCTAssertEqualWithAccuracy(heightScaledValue, 67.3, 0.1);
}

- (void)testScreenScalingUsesMinDimensionRatio {
  CGSize expandedViewport = CGSizeMake(430.0, 932.0);

  CGFloat scaledValue = MRRLayoutScaledValue(100.0, expandedViewport, MRRLayoutScaleAxisMinDimension);

  XCTAssertEqualWithAccuracy(scaledValue, 110.3, 0.1);
}

- (void)testInterpolationHelperRemainsDeterministicAcrossCommonViewports {
  NSArray<NSValue *> *viewports = @[
    [NSValue valueWithCGSize:CGSizeMake(375.0, 812.0)],
    [NSValue valueWithCGSize:CGSizeMake(414.0, 896.0)],
    [NSValue valueWithCGSize:CGSizeMake(430.0, 932.0)],
  ];
  NSArray<NSNumber *> *expectedInsets = @[ @22.3, @24.0, @24.0 ];

  for (NSUInteger index = 0; index < viewports.count; index++) {
    CGSize viewport = viewports[index].CGSizeValue;
    CGFloat inset = MRRLayoutRoundedMetric(MRRLayoutInterpolatedMetricForValue(viewport.width, 320.0, 414.0, 20.0, 24.0));
    XCTAssertEqualWithAccuracy(inset, expectedInsets[index].doubleValue, 0.1);
  }
}

@end
