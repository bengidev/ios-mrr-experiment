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
#import "../Features/MainMenu/MainMenuCoordinator.h"
#import "../Features/MainMenu/MainMenuTabBarController.h"
#import "../Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"
#import "../Persistence/CoreData/MRRCoreDataStack.h"
#import "../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../Persistence/SavedRecipes/Sync/MRRNoOpSavedRecipesSyncEngine.h"
#import "../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "../Persistence/SavedRecipes/Sync/MRRSavedRecipesSyncEngine.h"
#import "../Persistence/SavedRecipes/Sync/MRRSyncingLogoutController.h"
#import "../Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../Persistence/UserRecipes/Sync/MRRNoOpUserRecipesSyncEngine.h"
#import "../Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"
#import "../Persistence/UserRecipes/Sync/MRRUserRecipesSyncEngine.h"

#import <GoogleSignIn/GoogleSignIn.h>

@class AppDelegate;

@interface MRRAppDelegateObservationTarget : NSObject

@property(nonatomic, assign, nullable) AppDelegate *target;

@end

@implementation MRRAppDelegateObservationTarget
@end

@interface AppDelegate () <OnboardingViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *onboardingStateController;
@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain, nullable) MRRCoreDataStack *coreDataStack;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) MRRUserRecipesStore *userRecipesStore;
@property(nonatomic, retain) id<MRRSavedRecipesCloudSyncing> savedRecipesSyncEngine;
@property(nonatomic, retain) id<MRRUserRecipesCloudSyncing> userRecipesSyncEngine;
@property(nonatomic, retain, nullable) id<MRRLogoutCoordinating> logoutController;
@property(nonatomic, retain, nullable) id<MRRAuthStateObservation> authStateObservation;
@property(nonatomic, retain) MRRAppDelegateObservationTarget *authObservationTarget;
@property(nonatomic, retain, nullable) MainMenuCoordinator *mainMenuCoordinator;
@property(nonatomic, copy, nullable) NSString *visibleAuthenticatedUserID;
@property(nonatomic, assign) UIBackgroundTaskIdentifier savedRecipesBackgroundTaskIdentifier;

- (void)configureSavedRecipesInfrastructure;
- (void)startObservingAuthenticationState;
- (void)handleObservedAuthenticationSession:(nullable MRRAuthSession *)session;
- (void)updateRootForSession:(nullable MRRAuthSession *)session animated:(BOOL)animated;
- (UIViewController *)buildRootViewControllerForSession:(nullable MRRAuthSession *)session;
- (UIViewController *)buildMainMenuViewControllerWithSession:(MRRAuthSession *)session;
- (void)startSavedRecipesSyncForSessionIfNeeded:(nullable MRRAuthSession *)session;
- (void)flushSavedRecipesSyncForApplication:(UIApplication *)application;
- (void)endSavedRecipesBackgroundTaskIfNeededForApplication:(UIApplication *)application;
- (BOOL)isShowingOnboardingRoot;
- (BOOL)isShowingMainMenuRoot;

@end

@implementation AppDelegate

- (instancetype)init {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  OnboardingStateController *onboardingStateController = [[[OnboardingStateController alloc] initWithUserDefaults:userDefaults] autorelease];
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
    _authObservationTarget = [[MRRAppDelegateObservationTarget alloc] init];
    _authObservationTarget.target = self;
    _savedRecipesBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
  }

  return self;
}

#pragma mark - Memory Management

- (void)dealloc {
  self.authObservationTarget.target = nil;
  [self.authStateObservation invalidate];
  [_logoutController release];
  [_userRecipesSyncEngine release];
  [_userRecipesStore release];
  [_savedRecipesSyncEngine release];
  [_savedRecipesStore release];
  [_coreDataStack release];
  [_visibleAuthenticatedUserID release];
  [_mainMenuCoordinator release];
  [_authObservationTarget release];
  [_authStateObservation release];
  [_authenticationController release];
  [_onboardingStateController release];
  [_window release];
  [super dealloc];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self configureSavedRecipesInfrastructure];

  self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
  self.window.rootViewController = [self buildInitialRootViewController];
  [self startObservingAuthenticationState];
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
  [self flushSavedRecipesSyncForApplication:application];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the active state
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [self endSavedRecipesBackgroundTaskIfNeededForApplication:application];
  if (self.visibleAuthenticatedUserID.length > 0) {
    [self.savedRecipesSyncEngine requestImmediateSyncForUserID:self.visibleAuthenticatedUserID];
    [self.userRecipesSyncEngine requestImmediateSyncForUserID:self.visibleAuthenticatedUserID];
  }
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [self flushSavedRecipesSyncForApplication:application];
}

#pragma mark - Root Flow Delegate Events

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController {
  MRRAuthSession *session = [self.authenticationController currentSession];
  if (session == nil) {
    return;
  }

  [self updateRootForSession:session animated:[self shouldAnimateRootTransitions]];
}

#pragma mark - Root View Controller Builders

- (void)configureSavedRecipesInfrastructure {
  NSError *coreDataError = nil;
  self.coreDataStack = [[[MRRCoreDataStack alloc] initWithInMemoryStore:NO error:&coreDataError] autorelease];
  if (self.coreDataStack == nil || coreDataError != nil) {
    NSLog(@"[SavedRecipes] Core Data unavailable: %@", coreDataError);
    self.savedRecipesStore = nil;
    self.userRecipesStore = nil;
    self.savedRecipesSyncEngine = [[[MRRNoOpSavedRecipesSyncEngine alloc] init] autorelease];
    self.userRecipesSyncEngine = [[[MRRNoOpUserRecipesSyncEngine alloc] init] autorelease];
    self.logoutController = [[[MRRSyncingLogoutController alloc] initWithAuthenticationController:self.authenticationController
                                                                           savedRecipesSyncEngine:self.savedRecipesSyncEngine
                                                                            userRecipesSyncEngine:self.userRecipesSyncEngine] autorelease];
    return;
  }

  self.savedRecipesStore = [[[MRRSavedRecipesStore alloc] initWithCoreDataStack:self.coreDataStack] autorelease];
  self.userRecipesStore = [[[MRRUserRecipesStore alloc] initWithCoreDataStack:self.coreDataStack] autorelease];

  BOOL firebaseConfigured = NO;
  if ([self.authenticationController isKindOfClass:[MRRFirebaseAuthenticationController class]]) {
    firebaseConfigured = [MRRFirebaseAuthenticationController configureFirebaseIfPossible];
  }

  if (firebaseConfigured && self.savedRecipesStore != nil) {
    self.savedRecipesSyncEngine = [[[MRRSavedRecipesSyncEngine alloc] initWithStore:self.savedRecipesStore] autorelease];
  } else {
    self.savedRecipesSyncEngine = [[[MRRNoOpSavedRecipesSyncEngine alloc] init] autorelease];
  }
  if (firebaseConfigured && self.userRecipesStore != nil) {
    self.userRecipesSyncEngine = [[[MRRUserRecipesSyncEngine alloc] initWithStore:self.userRecipesStore] autorelease];
  } else {
    self.userRecipesSyncEngine = [[[MRRNoOpUserRecipesSyncEngine alloc] init] autorelease];
  }

  self.logoutController = [[[MRRSyncingLogoutController alloc] initWithAuthenticationController:self.authenticationController
                                                                         savedRecipesSyncEngine:self.savedRecipesSyncEngine
                                                                          userRecipesSyncEngine:self.userRecipesSyncEngine] autorelease];
}

- (UIViewController *)buildInitialRootViewController {
  return [self buildRootViewControllerForSession:[self.authenticationController currentSession]];
}

- (UIViewController *)buildOnboardingViewController {
  self.mainMenuCoordinator = nil;
  self.visibleAuthenticatedUserID = nil;
  [self.savedRecipesSyncEngine stopSync];
  [self.userRecipesSyncEngine stopSync];

  OnboardingViewController *viewController = [[[OnboardingViewController alloc] initWithStateController:self.onboardingStateController
                                                                               authenticationController:self.authenticationController] autorelease];
  viewController.delegate = self;

  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:viewController] autorelease];
  navigationController.navigationBarHidden = YES;
  return navigationController;
}

- (UIViewController *)buildRootViewControllerForSession:(MRRAuthSession *)session {
  if (session != nil) {
    self.visibleAuthenticatedUserID = session.userID;
    [self startSavedRecipesSyncForSessionIfNeeded:session];
    return [self buildMainMenuViewControllerWithSession:session];
  }

  return [self buildOnboardingViewController];
}

- (UIViewController *)buildMainMenuViewControllerWithSession:(MRRAuthSession *)session {
  self.mainMenuCoordinator = [[[MainMenuCoordinator alloc] initWithAuthenticationController:self.authenticationController
                                                                                    session:session
                                                                          savedRecipesStore:self.savedRecipesStore
                                                                                 syncEngine:self.savedRecipesSyncEngine
                                                                           userRecipesStore:self.userRecipesStore
                                                                             userSyncEngine:self.userRecipesSyncEngine
                                                                           logoutController:self.logoutController] autorelease];
  return [self.mainMenuCoordinator rootViewController];
}

- (void)startSavedRecipesSyncForSessionIfNeeded:(MRRAuthSession *)session {
  if (session.userID.length == 0) {
    [self.savedRecipesSyncEngine stopSync];
    [self.userRecipesSyncEngine stopSync];
    return;
  }

  [self.savedRecipesSyncEngine startSyncForUserID:session.userID completion:nil];
  [self.userRecipesSyncEngine startSyncForUserID:session.userID completion:nil];
}

- (void)flushSavedRecipesSyncForApplication:(UIApplication *)application {
  if (self.visibleAuthenticatedUserID.length == 0) {
    return;
  }

  [self endSavedRecipesBackgroundTaskIfNeededForApplication:application];
  self.savedRecipesBackgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self endSavedRecipesBackgroundTaskIfNeededForApplication:application];
    });
  }];

  NSString *userID = [[self.visibleAuthenticatedUserID copy] autorelease];
  AppDelegate *strongSelf = self;
  [self.savedRecipesSyncEngine
      flushPendingChangesForUserID:userID
                        completion:^(__unused NSError *error) {
                          [strongSelf.userRecipesSyncEngine
                              flushPendingChangesForUserID:userID
                                                completion:^(__unused NSError *userError) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                    [strongSelf endSavedRecipesBackgroundTaskIfNeededForApplication:application];
                                                  });
                                                }];
                        }];
}

- (void)endSavedRecipesBackgroundTaskIfNeededForApplication:(UIApplication *)application {
  if (self.savedRecipesBackgroundTaskIdentifier == UIBackgroundTaskInvalid) {
    return;
  }

  UIBackgroundTaskIdentifier backgroundTaskIdentifier = self.savedRecipesBackgroundTaskIdentifier;
  self.savedRecipesBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
  [application endBackgroundTask:backgroundTaskIdentifier];
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

#pragma mark - Auth State Observation

- (void)startObservingAuthenticationState {
  if (self.authStateObservation != nil) {
    return;
  }

  MRRAppDelegateObservationTarget *targetBox = [[self.authObservationTarget retain] autorelease];
  self.authStateObservation = [[self.authenticationController observeAuthStateWithHandler:^(MRRAuthSession *_Nullable session) {
    AppDelegate *target = targetBox.target;
    if (target == nil) {
      return;
    }

    if ([NSThread isMainThread]) {
      [target handleObservedAuthenticationSession:session];
      return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      AppDelegate *mainThreadTarget = targetBox.target;
      if (mainThreadTarget == nil) {
        return;
      }

      [mainThreadTarget handleObservedAuthenticationSession:session];
    });
  }] retain];
}

- (void)handleObservedAuthenticationSession:(MRRAuthSession *)session {
  if (self.window == nil) {
    return;
  }

  [self updateRootForSession:session animated:[self shouldAnimateRootTransitions]];
}

- (void)updateRootForSession:(MRRAuthSession *)session animated:(BOOL)animated {
  if (session == nil) {
    if ([self isShowingOnboardingRoot] && self.visibleAuthenticatedUserID == nil) {
      return;
    }

    [self setRootViewController:[self buildOnboardingViewController] animated:animated];
    return;
  }

  if ([self isShowingMainMenuRoot] && [self.visibleAuthenticatedUserID isEqualToString:session.userID]) {
    return;
  }

  [self setRootViewController:[self buildRootViewControllerForSession:session] animated:animated];
}

- (BOOL)isShowingOnboardingRoot {
  if (![self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
    return NO;
  }

  UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
  return [navigationController.topViewController isKindOfClass:[OnboardingViewController class]];
}

- (BOOL)isShowingMainMenuRoot {
  return [self.window.rootViewController isKindOfClass:[MainMenuTabBarController class]];
}

@end
