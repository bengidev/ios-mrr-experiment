//
//  AppDelegate.m
//  MRR Project
//
//  Created for MRR Learning
//

#import "AppDelegate.h"
#import "../Features/Onboarding/Data/OnboardingStateController.h"
#import "../Features/Authentication/MRRFirebaseAuthenticationController.h"
#import "../Features/Authentication/MRRAuthSession.h"
#import "../Features/Home/HomeViewController.h"
#import "../Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

#import <GoogleSignIn/GoogleSignIn.h>

@interface AppDelegate () <HomeViewControllerDelegate, OnboardingViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *onboardingStateController;
@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;

@end

@implementation AppDelegate

- (instancetype)init {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  OnboardingStateController *onboardingStateController =
      [[[OnboardingStateController alloc] initWithUserDefaults:userDefaults] autorelease];
  id<MRRAuthenticationController> authenticationController = [[[MRRFirebaseAuthenticationController alloc] init] autorelease];
  return [self initWithOnboardingStateController:onboardingStateController authenticationController:authenticationController];
}

- (instancetype)initWithOnboardingStateController:(OnboardingStateController *)onboardingStateController {
  id<MRRAuthenticationController> authenticationController = [[[MRRFirebaseAuthenticationController alloc] init] autorelease];
  return [self initWithOnboardingStateController:onboardingStateController authenticationController:authenticationController];
}

- (instancetype)initWithOnboardingStateController:(OnboardingStateController *)onboardingStateController
                          authenticationController:(id<MRRAuthenticationController>)authenticationController {
  NSParameterAssert(onboardingStateController != nil);
  NSParameterAssert(authenticationController != nil);

  self = [super init];
  if (self) {
    _onboardingStateController = [onboardingStateController retain];
    _authenticationController = [authenticationController retain];
  }

  return self;
}

#pragma mark - Memory Management

- (void)dealloc {
  [_authenticationController release];
  [_onboardingStateController release];
  [_window release];
  [super dealloc];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  if ([self.authenticationController isKindOfClass:[MRRFirebaseAuthenticationController class]]) {
    [MRRFirebaseAuthenticationController configureFirebaseIfPossible];
  }

  self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
  self.window.rootViewController = [self buildInitialRootViewController];
  if ([self shouldMakeWindowKeyAndVisible]) {
    [self.window makeKeyAndVisible];
  }
  return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  return [[GIDSignIn sharedInstance] handleURL:url];
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

#pragma mark - Root Flow Delegate Events

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController {
  MRRAuthSession *session = [self.authenticationController currentSession];
  if (session == nil) {
    return;
  }

  [self setRootViewController:[self buildHomeViewControllerWithSession:session] animated:[self shouldAnimateRootTransitions]];
}

- (void)homeViewControllerDidSignOut:(HomeViewController *)viewController {
  [self setRootViewController:[self buildOnboardingViewController] animated:[self shouldAnimateRootTransitions]];
}

#pragma mark - Root View Controller Builders

- (UIViewController *)buildInitialRootViewController {
  MRRAuthSession *session = [self.authenticationController currentSession];
  if (session != nil) {
    return [self buildHomeViewControllerWithSession:session];
  }

  return [self buildOnboardingViewController];
}

- (UIViewController *)buildOnboardingViewController {
  OnboardingViewController *viewController =
      [[[OnboardingViewController alloc] initWithStateController:self.onboardingStateController
                                         authenticationController:self.authenticationController] autorelease];
  viewController.delegate = self;
  return viewController;
}

- (UIViewController *)buildHomeViewControllerWithSession:(MRRAuthSession *)session {
  HomeViewController *viewController =
      [[[HomeViewController alloc] initWithAuthenticationController:self.authenticationController session:session] autorelease];
  viewController.delegate = self;
  return viewController;
}

- (void)setRootViewController:(UIViewController *)rootViewController animated:(BOOL)animated {
  if (!animated || self.window.rootViewController == nil) {
    self.window.rootViewController = rootViewController;
    return;
  }

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
}

- (BOOL)shouldAnimateRootTransitions {
  return NSClassFromString(@"XCTestCase") == nil;
}

- (BOOL)shouldMakeWindowKeyAndVisible {
  return NSClassFromString(@"XCTestCase") == nil;
}

@end
