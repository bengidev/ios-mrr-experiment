#import "MainMenuTabBarController.h"

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

  self.tabBar.accessibilityIdentifier = @"mainMenu.tabBar";
  if (@available(iOS 15.0, *)) {
    self.tabBar.scrollEdgeAppearance = self.tabBar.standardAppearance;
  }
}

@end
