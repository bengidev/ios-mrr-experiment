#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MRRFeatureCoordinator <NSObject>

- (UIViewController *)rootViewController;

@end

@protocol MRRTabFeatureCoordinator <MRRFeatureCoordinator>

- (UITabBarItem *)tabBarItem;

@end

NS_ASSUME_NONNULL_END
