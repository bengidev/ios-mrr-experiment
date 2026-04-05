#import "MainMenuTabBarController.h"

static UIColor *MRRMainMenuDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRMainMenuNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRMainMenuDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRMainMenuSelectedTabColor(void) {
  return MRRMainMenuNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                               [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRMainMenuUnselectedTabColor(void) {
  return MRRMainMenuNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0], [UIColor colorWithWhite:0.63 alpha:1.0]);
}

static UIColor *MRRMainMenuTabBarBackgroundColor(void) {
  return MRRMainMenuNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.15 alpha:1.0]);
}

static NSDictionary<NSAttributedStringKey, id> *MRRMainMenuTitleAttributes(UIColor *titleColor) {
  return @{NSForegroundColorAttributeName : titleColor};
}

static void MRRMainMenuApplyItemAppearance(UITabBarItemAppearance *itemAppearance, UIColor *selectedIconColor, UIColor *unselectedColor)
    API_AVAILABLE(ios(13.0)) {
  itemAppearance.normal.iconColor = unselectedColor;
  itemAppearance.normal.titleTextAttributes = MRRMainMenuTitleAttributes(unselectedColor);
  itemAppearance.normal.titlePositionAdjustment = UIOffsetZero;
  itemAppearance.selected.iconColor = selectedIconColor;
  itemAppearance.selected.titleTextAttributes = MRRMainMenuTitleAttributes(selectedIconColor);
  itemAppearance.selected.titlePositionAdjustment = UIOffsetZero;
}

@implementation MainMenuTabBarController

- (instancetype)initWithTabViewControllers:(NSArray<UIViewController *> *)viewControllers {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.viewControllers = viewControllers;
    self.selectedIndex = 0;
  }

  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  UIColor *selectedIconColor = MRRMainMenuSelectedTabColor();
  UIColor *unselectedColor = MRRMainMenuUnselectedTabColor();
  UIColor *backgroundColor = MRRMainMenuTabBarBackgroundColor();

  self.tabBar.accessibilityIdentifier = @"mainMenu.tabBar";
  self.tabBar.tintColor = selectedIconColor;
  if (@available(iOS 10.0, *)) {
    self.tabBar.unselectedItemTintColor = unselectedColor;
  }
  self.tabBar.backgroundColor = backgroundColor;
  self.tabBar.barTintColor = backgroundColor;
  self.tabBar.translucent = NO;

  for (UITabBarItem *item in self.tabBar.items) {
    item.titlePositionAdjustment = UIOffsetZero;
    [item setTitleTextAttributes:MRRMainMenuTitleAttributes(unselectedColor) forState:UIControlStateNormal];
    [item setTitleTextAttributes:MRRMainMenuTitleAttributes(selectedIconColor) forState:UIControlStateSelected];
  }

  if (@available(iOS 13.0, *)) {
    UITabBarAppearance *appearance = [[[UITabBarAppearance alloc] init] autorelease];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = backgroundColor;
    appearance.shadowColor = [unselectedColor colorWithAlphaComponent:0.12];
    MRRMainMenuApplyItemAppearance(appearance.stackedLayoutAppearance, selectedIconColor, unselectedColor);
    MRRMainMenuApplyItemAppearance(appearance.inlineLayoutAppearance, selectedIconColor, unselectedColor);
    MRRMainMenuApplyItemAppearance(appearance.compactInlineLayoutAppearance, selectedIconColor, unselectedColor);
    self.tabBar.standardAppearance = appearance;
  }

  if (@available(iOS 15.0, *)) {
    self.tabBar.scrollEdgeAppearance = self.tabBar.standardAppearance;
  }
}

@end
