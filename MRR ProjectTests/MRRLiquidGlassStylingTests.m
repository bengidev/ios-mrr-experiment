#import <XCTest/XCTest.h>

#import "../MRR Project/Layout/MRRLiquidGlassStyling.h"

@interface MRRLiquidGlassStylingTests : XCTestCase

- (NSString *)displayedTitleForButton:(UIButton *)button;

@end

@implementation MRRLiquidGlassStylingTests

- (void)testSupportsNativeLiquidGlassMatchesRuntimeAvailability {
  if (@available(iOS 26.0, *)) {
    XCTAssertTrue([MRRLiquidGlassStyling supportsNativeLiquidGlass]);
    return;
  }

  XCTAssertFalse([MRRLiquidGlassStyling supportsNativeLiquidGlass]);
}

- (void)testApplyButtonRoleConfiguresPrimarySecondaryAndInlineButtons {
  NSArray<NSNumber *> *roles = @[ @(MRRGlassButtonRolePrimary), @(MRRGlassButtonRoleSecondary), @(MRRGlassButtonRoleInline) ];
  NSArray<NSString *> *titles = @[ @"Primary", @"Secondary", @"Inline" ];

  for (NSUInteger index = 0; index < roles.count; index++) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:titles[index] forState:UIControlStateNormal];

    [MRRLiquidGlassStyling applyButtonRole:(MRRGlassButtonRole)roles[index].integerValue toButton:button];

    XCTAssertEqualObjects([self displayedTitleForButton:button], titles[index]);
    if (@available(iOS 15.0, *)) {
      XCTAssertNotNil(button.configuration);
    } else {
      XCTAssertNotNil(button.backgroundColor);
    }
  }
}

- (void)testApplySurfaceRoleConfiguresKnownSurfaceTokens {
  UIView *cardView = [[UIView alloc] init];
  UIView *overlayView = [[UIView alloc] init];
  UIView *badgeView = [[UIView alloc] init];

  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:cardView];
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:overlayView];
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleBadge toView:badgeView];

  XCTAssertEqualWithAccuracy(cardView.layer.cornerRadius, 28.0, 0.001);
  XCTAssertEqualWithAccuracy(overlayView.layer.cornerRadius, 22.0, 0.001);
  XCTAssertEqualWithAccuracy(badgeView.layer.cornerRadius, 16.0, 0.001);
  XCTAssertNotNil(cardView.backgroundColor);
  XCTAssertNotNil(overlayView.backgroundColor);
  XCTAssertNotNil(badgeView.backgroundColor);
}

- (void)testApplyTextFieldStylingConfiguresRoundedSurface {
  UITextField *textField = [[UITextField alloc] init];

  [MRRLiquidGlassStyling applyTextFieldStyling:textField];

  XCTAssertEqual(textField.borderStyle, UITextBorderStyleNone);
  XCTAssertEqualWithAccuracy(textField.layer.cornerRadius, 16.0, 0.001);
  XCTAssertEqualWithAccuracy(textField.layer.borderWidth, 1.0, 0.001);
  XCTAssertNotNil(textField.backgroundColor);
}

- (void)testTransparencyFallbackTracksAccessibilitySetting {
  XCTAssertEqual([MRRLiquidGlassStyling shouldUseOpaqueFallbackForTransparency], UIAccessibilityIsReduceTransparencyEnabled());
}

- (NSString *)displayedTitleForButton:(UIButton *)button {
  if (@available(iOS 15.0, *)) {
    if (button.configuration.attributedTitle.length > 0) {
      return button.configuration.attributedTitle.string;
    }
    if (button.configuration.title.length > 0) {
      return button.configuration.title;
    }
  }

  return [button titleForState:UIControlStateNormal];
}

@end
