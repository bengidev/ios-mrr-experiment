#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingViewController;

@protocol OnboardingViewControllerDelegate <NSObject>

- (void)onboardingViewControllerDidFinish:(OnboardingViewController *)viewController;

@end

@interface OnboardingViewController : UIViewController

@property(nonatomic, assign, nullable) id<OnboardingViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
