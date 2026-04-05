#import "MRRLiquidGlassStyling.h"

static UIColor *MRRGlassDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return darkColor;
      }
      return lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRGlassNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRGlassDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRGlassAccentColor(void) {
  return MRRGlassNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRGlassPrimaryTextColor(void) {
  return MRRGlassNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRGlassCardSurfaceColor(void) {
  return MRRGlassNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.15 alpha:1.0]);
}

static UIColor *MRRGlassTranslucentSurfaceColor(CGFloat alpha) { return [MRRGlassCardSurfaceColor() colorWithAlphaComponent:alpha]; }

static NSAttributedString *MRRGlassAttributedTitle(NSString *title, UIFont *font, UIColor *color) {
  return [[[NSAttributedString alloc] initWithString:title
                                          attributes:@{NSFontAttributeName : font, NSForegroundColorAttributeName : color}] autorelease];
}

@implementation MRRLiquidGlassStyling

+ (BOOL)supportsNativeLiquidGlass {
  if (@available(iOS 26.0, *)) {
    return YES;
  }

  return NO;
}

+ (BOOL)shouldUseOpaqueFallbackForTransparency {
  return UIAccessibilityIsReduceTransparencyEnabled();
}

+ (void)applyButtonRole:(MRRGlassButtonRole)role toButton:(UIButton *)button {
  NSParameterAssert(button != nil);

  NSString *title = [button titleForState:UIControlStateNormal];
  if (title == nil) {
    title = @"";
  }

  [button setBackgroundImage:nil forState:UIControlStateNormal];
  button.tintColor = MRRGlassAccentColor();
  button.layer.shadowColor = [UIColor blackColor].CGColor;
  button.layer.shadowOpacity = 0.0f;
  button.layer.shadowRadius = 0.0f;
  button.layer.shadowOffset = CGSizeZero;
  button.layer.borderWidth = 0.0;
  button.layer.borderColor = nil;
  button.layer.cornerRadius = role == MRRGlassButtonRoleInline ? 0.0 : 18.0;
  button.clipsToBounds = NO;
  button.contentEdgeInsets = UIEdgeInsetsZero;
  button.titleLabel.font = [UIFont systemFontOfSize:role == MRRGlassButtonRoleInline ? 15.0 : 17.0
                                             weight:role == MRRGlassButtonRolePrimary ? UIFontWeightBold : UIFontWeightSemibold];

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *configuration = nil;
    BOOL usesNativeLiquidGlass = NO;
    if (@available(iOS 26.0, *)) {
      usesNativeLiquidGlass = YES;
      switch (role) {
        case MRRGlassButtonRolePrimary:
          configuration = [UIButtonConfiguration prominentGlassButtonConfiguration];
          break;
        case MRRGlassButtonRoleSecondary:
          configuration = [UIButtonConfiguration glassButtonConfiguration];
          break;
        case MRRGlassButtonRoleInline:
          configuration = [UIButtonConfiguration plainButtonConfiguration];
          break;
      }
    } else {
      switch (role) {
        case MRRGlassButtonRolePrimary:
          configuration = [UIButtonConfiguration filledButtonConfiguration];
          configuration.baseBackgroundColor = MRRGlassAccentColor();
          configuration.baseForegroundColor = [UIColor whiteColor];
          break;
        case MRRGlassButtonRoleSecondary:
          configuration = [UIButtonConfiguration borderedTintedButtonConfiguration];
          configuration.baseBackgroundColor = [MRRGlassAccentColor() colorWithAlphaComponent:0.14];
          configuration.baseForegroundColor = MRRGlassPrimaryTextColor();
          break;
        case MRRGlassButtonRoleInline:
          configuration = [UIButtonConfiguration plainButtonConfiguration];
          configuration.baseForegroundColor = MRRGlassAccentColor();
          break;
      }
    }

    configuration.title = title;
    configuration.buttonSize = UIButtonConfigurationSizeLarge;
    if (role == MRRGlassButtonRoleInline) {
      configuration.contentInsets = NSDirectionalEdgeInsetsMake(4.0, 0.0, 4.0, 0.0);
      configuration.background.backgroundColor = [UIColor clearColor];
    } else {
      configuration.contentInsets = NSDirectionalEdgeInsetsMake(14.0, 18.0, 14.0, 18.0);
    }

    UIFont *font = button.titleLabel.font ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    UIColor *foregroundColor = role == MRRGlassButtonRolePrimary && !usesNativeLiquidGlass ? [UIColor whiteColor] : nil;
    if (role == MRRGlassButtonRoleInline) {
      foregroundColor = MRRGlassAccentColor();
    }
    if (role == MRRGlassButtonRoleSecondary && !usesNativeLiquidGlass) {
      foregroundColor = MRRGlassPrimaryTextColor();
    }
    if (foregroundColor == nil) {
      foregroundColor = MRRGlassPrimaryTextColor();
    }
    configuration.attributedTitle = MRRGlassAttributedTitle(title, font, foregroundColor);
    button.configuration = configuration;
    [button setTitle:nil forState:UIControlStateNormal];
    [button setTitle:nil forState:UIControlStateHighlighted];
    button.backgroundColor = [UIColor clearColor];
    return;
  }

  switch (role) {
    case MRRGlassButtonRolePrimary:
      button.backgroundColor = MRRGlassAccentColor();
      [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
      [button setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.86] forState:UIControlStateHighlighted];
      button.layer.shadowOpacity = 0.16f;
      button.layer.shadowRadius = 16.0f;
      button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
      break;
    case MRRGlassButtonRoleSecondary:
      button.backgroundColor = [self shouldUseOpaqueFallbackForTransparency] ? MRRGlassCardSurfaceColor() : MRRGlassTranslucentSurfaceColor(0.78);
      [button setTitleColor:MRRGlassPrimaryTextColor() forState:UIControlStateNormal];
      [button setTitleColor:[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.78] forState:UIControlStateHighlighted];
      button.layer.borderWidth = 1.0;
      button.layer.borderColor = [[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.12] CGColor];
      button.layer.shadowOpacity = 0.10f;
      button.layer.shadowRadius = 12.0f;
      button.layer.shadowOffset = CGSizeMake(0.0, 8.0);
      break;
    case MRRGlassButtonRoleInline:
      button.backgroundColor = [UIColor clearColor];
      [button setTitleColor:MRRGlassAccentColor() forState:UIControlStateNormal];
      [button setTitleColor:[MRRGlassAccentColor() colorWithAlphaComponent:0.76] forState:UIControlStateHighlighted];
      button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
      break;
  }

  [button setTitle:title forState:UIControlStateNormal];
  [button setTitle:title forState:UIControlStateHighlighted];
}

+ (void)applySurfaceRole:(MRRGlassSurfaceRole)role toView:(UIView *)view {
  NSParameterAssert(view != nil);

  BOOL shouldUseOpaqueFallback = [self shouldUseOpaqueFallbackForTransparency];
  view.layer.borderColor = nil;
  view.layer.shadowColor = [UIColor blackColor].CGColor;
  view.layer.shadowOpacity = 0.0f;
  view.layer.shadowRadius = 0.0f;
  view.layer.shadowOffset = CGSizeZero;

  switch (role) {
    case MRRGlassSurfaceRoleElevatedCard:
      view.backgroundColor = shouldUseOpaqueFallback ? MRRGlassCardSurfaceColor() : MRRGlassTranslucentSurfaceColor(0.72);
      view.layer.cornerRadius = 28.0;
      view.layer.borderWidth = 1.0;
      view.layer.borderColor = [[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.12] CGColor];
      view.layer.shadowOpacity = 0.10f;
      view.layer.shadowRadius = 18.0f;
      view.layer.shadowOffset = CGSizeMake(0.0, 12.0);
      break;
    case MRRGlassSurfaceRoleOverlay:
      view.backgroundColor = shouldUseOpaqueFallback ? MRRGlassCardSurfaceColor() : MRRGlassTranslucentSurfaceColor(0.84);
      view.layer.cornerRadius = 22.0;
      view.layer.borderWidth = 1.0;
      view.layer.borderColor = [[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.14] CGColor];
      break;
    case MRRGlassSurfaceRoleBadge:
      view.backgroundColor =
          shouldUseOpaqueFallback ? [MRRGlassAccentColor() colorWithAlphaComponent:0.20] : [MRRGlassAccentColor() colorWithAlphaComponent:0.14];
      view.layer.cornerRadius = 16.0;
      view.layer.borderWidth = 1.0;
      view.layer.borderColor = [[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.08] CGColor];
      break;
  }
}

+ (void)applyTextFieldStyling:(UITextField *)textField {
  NSParameterAssert(textField != nil);

  textField.borderStyle = UITextBorderStyleNone;
  textField.backgroundColor = [self shouldUseOpaqueFallbackForTransparency] ? MRRGlassCardSurfaceColor() : MRRGlassTranslucentSurfaceColor(0.64);
  textField.textColor = MRRGlassPrimaryTextColor();
  textField.layer.cornerRadius = 16.0;
  textField.layer.borderWidth = 1.0;
  textField.layer.borderColor = [[MRRGlassPrimaryTextColor() colorWithAlphaComponent:0.10] CGColor];
  textField.clipsToBounds = YES;
}

@end
