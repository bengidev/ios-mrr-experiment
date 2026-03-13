#import <XCTest/XCTest.h>

#import "../MRR Project/App/MainMenuViewController.h"

@interface MainMenuViewControllerTests : XCTestCase

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (NSDictionary<NSString *, NSNumber *> *)metricsForViewportSize:(CGSize)size;

@end

@implementation MainMenuViewControllerTests

- (void)testMainMenuExposesCoreAccessibilityIdentifiers {
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, 390.0, 844.0)];
  MainMenuViewController *viewController = [[MainMenuViewController alloc] init];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];
  [viewController loadViewIfNeeded];
  [viewController.view layoutIfNeeded];

  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"mainMenu.titleLabel" inView:viewController.view]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"mainMenu.summaryLabel" inView:viewController.view]);
}

- (void)testLayoutMetricsScaleWithViewportWidth {
  NSDictionary<NSString *, NSNumber *> *narrowMetrics = [self metricsForViewportSize:CGSizeMake(375.0, 812.0)];
  NSDictionary<NSString *, NSNumber *> *wideMetrics = [self metricsForViewportSize:CGSizeMake(430.0, 932.0)];

  XCTAssertGreaterThan(wideMetrics[@"horizontalInset"].doubleValue, narrowMetrics[@"horizontalInset"].doubleValue);
  XCTAssertGreaterThan(wideMetrics[@"titleFontSize"].doubleValue, narrowMetrics[@"titleFontSize"].doubleValue);
}

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view {
  if ([view.accessibilityIdentifier isEqualToString:identifier]) {
    return view;
  }

  for (UIView *subview in view.subviews) {
    UIView *matchingView = [self findViewWithAccessibilityIdentifier:identifier inView:subview];
    if (matchingView != nil) {
      return matchingView;
    }
  }

  return nil;
}

- (NSDictionary<NSString *, NSNumber *> *)metricsForViewportSize:(CGSize)size {
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
  MainMenuViewController *viewController = [[MainMenuViewController alloc] init];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];
  [viewController loadViewIfNeeded];
  viewController.view.frame = CGRectMake(0.0, 0.0, size.width, size.height);
  [window setNeedsLayout];
  [window layoutIfNeeded];
  [viewController.view setNeedsLayout];
  [viewController.view layoutIfNeeded];

  UILabel *titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"mainMenu.titleLabel" inView:viewController.view];
  CGRect titleFrame = [titleLabel convertRect:titleLabel.bounds toView:viewController.view];

  return @{
    @"titleFontSize" : @(titleLabel.font.pointSize),
    @"horizontalInset" : @(CGRectGetMinX(titleFrame)),
  };
}

@end
