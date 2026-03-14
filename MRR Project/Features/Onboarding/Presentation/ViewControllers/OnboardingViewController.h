#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MRRAuthenticationController;
@class OnboardingStateController;
@class OnboardingViewController;

@protocol OnboardingViewControllerDelegate <NSObject>

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController;

@end

@interface OnboardingViewController : UIViewController

@property(nonatomic, assign, nullable) id<OnboardingViewControllerDelegate> delegate;

- (instancetype)initWithStateController:(OnboardingStateController *)stateController;
- (instancetype)initWithStateController:(OnboardingStateController *)stateController
                authenticationController:(id<MRRAuthenticationController>)authenticationController;

@end

NS_ASSUME_NONNULL_END
