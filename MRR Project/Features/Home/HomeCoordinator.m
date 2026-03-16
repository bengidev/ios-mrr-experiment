#import "HomeCoordinator.h"

#import "HomeViewController.h"

@interface HomeCoordinator ()

@property(nonatomic, retain, nullable) HomeViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation HomeCoordinator

- (void)dealloc {
  [_tabBarItemValue release];
  [_viewController release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[HomeViewController alloc] init] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"house.fill"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Home" image:image tag:0] autorelease];
  }

  return self.tabBarItemValue;
}

@end
