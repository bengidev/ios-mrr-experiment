//
//  AppDelegate.m
//  MRR Project
//
//  Created for MRR Learning
//

#import "AppDelegate.h"
#import "../Features/Onboarding/Data/OnboardingStateController.h"
#import "../Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface AppDelegate ()

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
  self.window.rootViewController = [self buildOnboardingViewController];
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

#pragma mark - Root View Controller Builders

- (UIViewController *)buildOnboardingViewController {
  OnboardingViewController *viewController = [[[OnboardingViewController alloc] initWithStateController:self.onboardingStateController]
      autorelease];
  return viewController;
}

- (BOOL)shouldMakeWindowKeyAndVisible {
  return NSClassFromString(@"XCTestCase") == nil;
}

@end
