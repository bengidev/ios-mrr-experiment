#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingStateController;
@class OnboardingViewController;

@protocol OnboardingViewControllerDelegate <NSObject>

- (void)onboardingViewControllerDidFinish:(OnboardingViewController *)viewController;

@end

@interface OnboardingViewController : UIViewController

@property(nonatomic, assign, nullable) id<OnboardingViewControllerDelegate> delegate;

- (instancetype)initWithStateController:(OnboardingStateController *)stateController;

@end

NS_ASSUME_NONNULL_END
