#import <XCTest/XCTest.h>
#import "../MRR Project/App/AppDelegate.h"
#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeViewController.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface AppDelegate (Testing)

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController;
- (void)homeViewControllerDidSignOut:(HomeViewController *)viewController;

@end

@interface AppLaunchFlowAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *stubSession;
@property(nonatomic, assign) NSInteger signOutCallCount;

@end

@implementation AppLaunchFlowAuthenticationControllerSpy

- (MRRAuthSession *)currentSession {
  return self.stubSession;
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

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  completion(self.stubSession, nil);
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  completion(nil);
}

- (BOOL)signOut:(NSError *__autoreleasing  _Nullable *)error {
  self.signOutCallCount += 1;
  self.stubSession = nil;
  return YES;
}

@end

@interface AppLaunchFlowTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;

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
  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[OnboardingViewController class]]);
}

- (void)testLoggedInLaunchShowsHome {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Test Cook"
                                providerType:MRRAuthProviderTypeGoogle];

  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];
  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[HomeViewController class]]);
}

- (void)testLoggedInLaunchDoesNotShowTabBarController {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Test Cook"
                                providerType:MRRAuthProviderTypeEmail];

  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];
  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  XCTAssertFalse([appDelegate.window.rootViewController isKindOfClass:[UITabBarController class]]);
}

- (void)testLegacyStoredLayoutScalingPreferenceDoesNotAffectLaunchFlow {
  [self.userDefaults setObject:@"guarded" forKey:@"mrr.layoutScalingMode"];
  [self.userDefaults synchronize];
  OnboardingStateController *stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate =
      [[AppDelegate alloc] initWithOnboardingStateController:stateController authenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);

  OnboardingViewController *onboardingViewController = (OnboardingViewController *)appDelegate.window.rootViewController;
  XCTAssertTrue([onboardingViewController isKindOfClass:[OnboardingViewController class]]);
}

- (void)testAuthenticatingFromOnboardingReplacesRootWithHome {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[OnboardingViewController class]]);

  authenticationController.stubSession =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Test Cook"
                                providerType:MRRAuthProviderTypeGoogle];
  [appDelegate onboardingViewControllerDidAuthenticate:(OnboardingViewController *)appDelegate.window.rootViewController];

  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[HomeViewController class]]);
}

- (void)testSigningOutFromHomeReplacesRootWithOnboarding {
  AppLaunchFlowAuthenticationControllerSpy *authenticationController = [[AppLaunchFlowAuthenticationControllerSpy alloc] init];
  authenticationController.stubSession =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Test Cook"
                                providerType:MRRAuthProviderTypeGoogle];
  AppDelegate *appDelegate = [self makeAppDelegateWithAuthenticationController:authenticationController];

  XCTAssertTrue([appDelegate application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil]);
  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[HomeViewController class]]);

  authenticationController.stubSession = nil;
  [appDelegate homeViewControllerDidSignOut:(HomeViewController *)appDelegate.window.rootViewController];

  XCTAssertTrue([appDelegate.window.rootViewController isKindOfClass:[OnboardingViewController class]]);
}

- (AppDelegate *)makeAppDelegateWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController {
  OnboardingStateController *stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  AppDelegate *appDelegate =
      [[AppDelegate alloc] initWithOnboardingStateController:stateController authenticationController:authenticationController];
  return appDelegate;
}

@end
