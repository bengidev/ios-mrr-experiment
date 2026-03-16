#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MainMenuTabBarController : UITabBarController

- (instancetype)initWithTabViewControllers:(NSArray<UIViewController *> *)viewControllers;

@end

NS_ASSUME_NONNULL_END
