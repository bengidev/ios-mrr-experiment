//
//  AppDelegate.h
//  MRR Project
//
//  Created for MRR Learning
//

#import <UIKit/UIKit.h>

@class OnboardingStateController;
@protocol MRRAuthenticationController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, retain) UIWindow *window;

- (instancetype)initWithOnboardingStateController:(OnboardingStateController *)onboardingStateController;
- (instancetype)initWithOnboardingStateController:(OnboardingStateController *)onboardingStateController
                          authenticationController:(id<MRRAuthenticationController>)authenticationController;

@end
