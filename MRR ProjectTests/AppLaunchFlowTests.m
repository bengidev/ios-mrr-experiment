#import <XCTest/XCTest.h>
#import "../MRR Project/App/AppDelegate.h"
#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/MainMenu/MainMenuTabBarController.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface AppLaunchFlowAuthStateObservationSpy : NSObject <MRRAuthStateObservation>

@property(nonatomic, assign) BOOL invalidated;

@end

@implementation AppLaunchFlowAuthStateObservationSpy

- (void)invalidate {
  self.invalidated = YES;
}

@end

@interface AppDelegate (Testing)

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController;

@end

@interface AppLaunchFlowAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *stubSession;
@property(nonatomic, assign) NSInteger signOutCallCount;
@property(nonatomic, copy, nullable) MRRAuthStateChangeHandler authStateHandler;
@property(nonatomic, strong, nullable) AppLaunchFlowAuthStateObservationSpy *observation;

- (void)emitObservedSession:(nullable MRRAuthSession *)session;

@end

@implementation AppLaunchFlowAuthenticationControllerSpy

- (MRRAuthSession *)currentSession {
  return self.stubSession;
}

- (id<MRRAuthStateObservation>)observeAuthStateWithHandler:(MRRAuthStateChangeHandler)handler {
  self.authStateHandler = handler;
  self.observation = [[AppLaunchFlowAuthStateObservationSpy alloc] init];
  return self.observation;
}

- (BOOL)hasPendingCredentialLink {
  return NO;
}

- (NSString *)pendingLinkEmail {
  return nil;
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(self.stubSession, nil);
}

- (void)signInWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(self.stubSession, nil);
}

- (void)sendPasswordResetForEmail:(NSString *)email completion:(MRRAuthCompletion)completion {
  completion(nil);
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  completion(self.stubSession, nil);
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  completion(nil);
}

- (BOOL)signOut:(NSError *__autoreleasing _Nullable *)error {
  self.signOutCallCount += 1;
  self.stubSession = nil;
  if (self.authStateHandler != nil) {
    self.authStateHandler(nil);
  }
  return YES;
}

- (void)emitObservedSession:(MRRAuthSession *)session {
  self.stubSession = session;
  if (self.authStateHandler != nil) {
    self.authStateHandler(session);
  }
}

@end

@interface AppLaunchFlowTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;

- (OnboardingViewController *)onboardingViewControllerFromRootViewController:(UIViewController *)rootViewController;
- (MainMenuTabBarController *)mainMenuTabBarControllerFromRootViewController:(UIViewController *)rootViewController;

@end

@implementation AppLaunchFlowTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"AppLaunchFlowTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
}

- (void)tearDown {
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testFirstLaunchShowsOnboarding {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  XCTAssertNotNil([self onboardingViewControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testLoggedInLaunchShowsMainMenu {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                          email:@"cook@example.com"
                                                                    displayName:@"Test Cook"
                                                                   providerType:MRRAuthProviderTypeGoogle
                                                                  emailVerified:YES];

  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];
  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  XCTAssertNotNil([self mainMenuTabBarControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testLoggedInLaunchShowsTabBarController {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                          email:@"cook@example.com"
                                                                    displayName:@"Test Cook"
                                                                   providerType:MRRAuthProviderTypeEmail
                                                                  emailVerified:NO];

  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];
  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[MainMenuTabBarController class]]);
}

- (void)testLegacyStoredLayoutScalingPreferenceDoesNotAffectLaunchFlow {
  [self.userDefaults setObject:@"guarded" forKey:@"mrr.layoutScalingMode"];
  [self.userDefaults synchronize];
  OnboardingStateController *stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate = [[AppDelegate alloc] initWithOnboardingStateController:stateController
                                                           authenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  XCTAssertNotNil([self onboardingViewControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testAuthenticatingFromOnboardingReplacesRootWithMainMenu {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  OnboardingViewController *onboardingViewController = [self onboardingViewControllerFromRootViewController:appDelegate.window.rootViewController];
  XCTAssertNotNil(onboardingViewController);

  authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                          email:@"cook@example.com"
                                                                    displayName:@"Test Cook"
                                                                   providerType:MRRAuthProviderTypeGoogle
                                                                  emailVerified:YES];
  [appDelegate onboardingViewControllerDidAuthenticate:onboardingViewController];

  XCTAssertNotNil([self mainMenuTabBarControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testObservedSessionLossReplacesMainMenuWithOnboarding {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                          email:@"cook@example.com"
                                                                    displayName:@"Test Cook"
                                                                   providerType:MRRAuthProviderTypeGoogle
                                                                  emailVerified:YES];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  XCTAssertNotNil([self mainMenuTabBarControllerFromRootViewController:appDelegate.window.rootViewController]);

  [authenticationController emitObservedSession:nil];

  XCTAssertNotNil([self onboardingViewControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testObservedActiveSessionReplacesOnboardingWithMainMenu {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  XCTAssertNotNil([self onboardingViewControllerFromRootViewController:appDelegate.window.rootViewController]);

  MRRAuthSession *session = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                             email:@"cook@example.com"
                                                       displayName:@"Test Cook"
                                                      providerType:MRRAuthProviderTypeEmail
                                                     emailVerified:NO];
  [authenticationController emitObservedSession:session];

  XCTAssertNotNil([self mainMenuTabBarControllerFromRootViewController:appDelegate.window.rootViewController]);
}

- (void)testDuplicateObservedActiveSessionDoesNotRebuildMainMenuRoot {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  MRRAuthSession *session = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                             email:@"cook@example.com"
                                                       displayName:@"Test Cook"
                                                      providerType:MRRAuthProviderTypeGoogle
                                                     emailVerified:YES];
  authenticationController.stubSession = session;
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  UIViewController *initialRootViewController = appDelegate.window.rootViewController;
  XCTAssertNotNil([self mainMenuTabBarControllerFromRootViewController:initialRootViewController]);

  [authenticationController emitObservedSession:session];

  XCTAssertEqual(appDelegate.window.rootViewController, initialRootViewController);
}

- (AppDelegate *)makeAppDelegateWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController {
  OnboardingStateController *stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  AppDelegate *appDelegate = [[AppDelegate alloc] initWithOnboardingStateController:stateController
                                                           authenticationController:authenticationController];
  return appDelegate;
}

- (OnboardingViewController *)onboardingViewControllerFromRootViewController:(UIViewController *)rootViewController {
  XCTAssertTrue([rootViewController isKindOfClass:[UINavigationController class]]);
  UINavigationController *navigationController = (UINavigationController *)rootViewController;
  XCTAssertTrue([navigationController.topViewController isKindOfClass:[OnboardingViewController class]]);
  return (OnboardingViewController *)navigationController.topViewController;
}

- (MainMenuTabBarController *)mainMenuTabBarControllerFromRootViewController:(UIViewController *)rootViewController {
  XCTAssertTrue([rootViewController isKindOfClass:[MainMenuTabBarController class]]);
  return (MainMenuTabBarController *)rootViewController;
}

@end
