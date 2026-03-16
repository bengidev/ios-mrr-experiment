#import "SavedCoordinator.h"

#import "SavedViewController.h"

@interface SavedCoordinator ()

@property(nonatomic, retain, nullable) SavedViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation SavedCoordinator

- (void)dealloc {
  [_tabBarItemValue release];
  [_viewController release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[SavedViewController alloc] init] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"bookmark.fill"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Saved" image:image tag:1] autorelease];
  }

  return self.tabBarItemValue;
}

@end
