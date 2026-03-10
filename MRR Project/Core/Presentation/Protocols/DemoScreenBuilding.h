#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DemoScreenBuilding <NSObject>

- (UIViewController *)detailViewControllerForDemoIdentifier:(NSString *)demoIdentifier;

@end

NS_ASSUME_NONNULL_END
