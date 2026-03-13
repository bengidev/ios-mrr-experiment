//
//  AppDelegate.m
//  MRR Project
//
//  Created for MRR Learning
//

#import "AppDelegate.h"
#import "MainMenuViewController.h"
#import "../Features/Onboarding/Data/OnboardingStateController.h"
#import "../Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface AppDelegate () <OnboardingViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *onboardingStateController;

@end

@implementation AppDelegate

- (instancetype)init {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  OnboardingStateController *onboardingStateController =
      [[[OnboardingStateController alloc] initWithUserDefaults:userDefaults] autorelease];
  return [self initWithOnboardingStateController:onboardingStateController];
}

- (instancetype)initWithOnboardingStateController:(OnboardingStateController *)onboardingStateController {
  NSParameterAssert(onboardingStateController != nil);

  self = [super init];
  if (self) {
    _onboardingStateController = [onboardingStateController retain];
  }

  return self;
}

#pragma mark - Memory Management

- (void)dealloc {
  [_onboardingStateController release];
  [_window release];
  [super dealloc];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
  [self setRootViewController:[self buildInitialRootViewController] animated:NO];
  if ([self shouldMakeWindowKeyAndVisible]) {
    [self.window makeKeyAndVisible];
  }
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, etc.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the active state
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate
}

#pragma mark - OnboardingViewControllerDelegate

- (void)onboardingViewControllerDidFinish:(OnboardingViewController *)viewController {
  [self.onboardingStateController markOnboardingCompleted];
  [self setRootViewController:[self buildMainMenuViewController] animated:[self shouldAnimateRootTransitions]];
}

#pragma mark - Root View Controller Builders

- (UIViewController *)buildInitialRootViewController {
  if ([self.onboardingStateController hasCompletedOnboarding]) {
    return [self buildMainMenuViewController];
  }

  return [self buildOnboardingViewController];
}

- (UIViewController *)buildOnboardingViewController {
  OnboardingViewController *viewController = [[[OnboardingViewController alloc] initWithStateController:self.onboardingStateController]
      autorelease];
  viewController.delegate = self;
  return viewController;
}

- (UIViewController *)buildMainMenuViewController {
  return [[[MainMenuViewController alloc] init] autorelease];
}

- (void)setRootViewController:(UIViewController *)rootViewController animated:(BOOL)animated {
  if (animated && self.window.rootViewController != nil) {
    [UIView transitionWithView:self.window
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
                      [UIView setAnimationsEnabled:NO];
                      self.window.rootViewController = rootViewController;
                      [UIView setAnimationsEnabled:animationsWereEnabled];
                    }
                    completion:nil];
    return;
  }

  self.window.rootViewController = rootViewController;
}

- (BOOL)shouldAnimateRootTransitions {
  return NSClassFromString(@"XCTestCase") == nil;
}

- (BOOL)shouldMakeWindowKeyAndVisible {
  return NSClassFromString(@"XCTestCase") == nil;
}

@end
