#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MRRAuthenticationController;
@protocol MRROnboardingRecipeCataloging;
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
- (instancetype)initWithStateController:(OnboardingStateController *)stateController
               authenticationController:(id<MRRAuthenticationController>)authenticationController
                          recipeCatalog:(id<MRROnboardingRecipeCataloging>)recipeCatalog;

@end

NS_ASSUME_NONNULL_END
