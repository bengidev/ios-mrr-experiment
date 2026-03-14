#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRREmailAuthenticationViewController.h"
#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface OnboardingAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *sessionToReturn;
@property(nonatomic, strong, nullable) NSError *nextEmailError;
@property(nonatomic, strong, nullable) NSError *nextGoogleError;
@property(nonatomic, strong, nullable) NSError *nextLinkError;
@property(nonatomic, assign) BOOL hasPendingCredentialLinkStub;
@property(nonatomic, copy, nullable) NSString *pendingLinkEmailStub;
@property(nonatomic, assign) NSInteger googleSignInCallCount;

@end

@implementation OnboardingAuthenticationControllerSpy

- (MRRAuthSession *)currentSession {
  return self.sessionToReturn;
}

- (BOOL)hasPendingCredentialLink {
  return self.hasPendingCredentialLinkStub;
}

- (NSString *)pendingLinkEmail {
  return self.pendingLinkEmailStub;
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(self.sessionToReturn, self.nextEmailError);
}

- (void)signInWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(self.sessionToReturn, self.nextEmailError);
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  self.googleSignInCallCount += 1;
  completion(self.sessionToReturn, self.nextGoogleError);
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  if (self.nextLinkError == nil) {
    self.hasPendingCredentialLinkStub = NO;
    self.pendingLinkEmailStub = nil;
  }

  completion(self.nextLinkError);
}

- (BOOL)signOut:(NSError *__autoreleasing  _Nullable *)error {
  return YES;
}

@end

@interface OnboardingAuthDelegateSpy : NSObject <OnboardingViewControllerDelegate>

@property(nonatomic, assign) BOOL didAuthenticate;

@end

@implementation OnboardingAuthDelegateSpy

- (void)onboardingViewControllerDidAuthenticate:(OnboardingViewController *)viewController {
  self.didAuthenticate = YES;
}

@end

@interface OnboardingAuthFlowTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) OnboardingStateController *stateController;
@property(nonatomic, strong) OnboardingAuthenticationControllerSpy *authenticationController;
@property(nonatomic, strong) OnboardingViewController *viewController;
@property(nonatomic, strong) OnboardingAuthDelegateSpy *delegateSpy;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)spinMainRunLoop;

@end

@implementation OnboardingAuthFlowTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"OnboardingAuthFlowTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  self.authenticationController = [[OnboardingAuthenticationControllerSpy alloc] init];
  self.viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController
                                                          authenticationController:self.authenticationController];
  self.delegateSpy = [[OnboardingAuthDelegateSpy alloc] init];
  self.viewController.delegate = self.delegateSpy;
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.viewController;
  [self.window makeKeyAndVisible];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.window.hidden = YES;
  self.window = nil;
  self.delegateSpy = nil;
  self.viewController = nil;
  self.authenticationController = nil;
  self.stateController = nil;
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testEmailButtonPresentsEmailAuthenticationModal {
  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  XCTAssertNotNil(emailButton);

  [emailButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[MRREmailAuthenticationViewController class]]);
  UISegmentedControl *modeControl = (UISegmentedControl *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.modeControl"
                                                                                              inView:self.viewController.presentedViewController.view];
  XCTAssertEqual(modeControl.selectedSegmentIndex, 0);
}

- (void)testSigninLabelPresentsEmailAuthenticationModalInSignInMode {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  XCTAssertNotNil(signinButton);

  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[MRREmailAuthenticationViewController class]]);
  UISegmentedControl *modeControl = (UISegmentedControl *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.modeControl"
                                                                                              inView:self.viewController.presentedViewController.view];
  XCTAssertEqual(modeControl.selectedSegmentIndex, 1);
}

- (void)testSubmittingEmailSignupAuthenticatesAndDismissesModal {
  self.authenticationController.sessionToReturn =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Email Cook"
                                providerType:MRRAuthProviderTypeEmail];

  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  [emailButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  UIView *modalView = self.viewController.presentedViewController.view;
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.emailField" inView:modalView];
  UITextField *passwordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.passwordField" inView:modalView];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.submitButton" inView:modalView];
  emailField.text = @"cook@example.com";
  passwordField.text = @"password123";

  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(self.delegateSpy.didAuthenticate);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testGoogleSuccessAuthenticatesWithoutPresentingModal {
  self.authenticationController.sessionToReturn =
      [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                       email:@"cook@example.com"
                                 displayName:@"Google Cook"
                                providerType:MRRAuthProviderTypeGoogle];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertTrue(self.delegateSpy.didAuthenticate);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testGoogleConflictPresentsLinkingEmailModal {
  self.authenticationController.hasPendingCredentialLinkStub = YES;
  self.authenticationController.pendingLinkEmailStub = @"cook@example.com";
  self.authenticationController.nextGoogleError =
      [NSError errorWithDomain:MRRAuthenticationErrorDomain
                          code:MRRAuthenticationErrorCodeRequiresAccountLinking
                      userInfo:@{MRRAuthPendingLinkEmailUserInfoKey : @"cook@example.com"}];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[MRREmailAuthenticationViewController class]]);
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailModal.emailField"
                                                                               inView:self.viewController.presentedViewController.view];
  XCTAssertEqualObjects(emailField.text, @"cook@example.com");
}

- (void)testAppleButtonPresentsStubAlert {
  UIButton *appleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.appleButton" inView:self.viewController.view];
  [appleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"onboarding.appleStubAlert");
}

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view {
  if ([view.accessibilityIdentifier isEqualToString:identifier]) {
    return view;
  }

  for (UIView *subview in view.subviews) {
    UIView *matchingView = [self findViewWithAccessibilityIdentifier:identifier inView:subview];
    if (matchingView != nil) {
      return matchingView;
    }
  }

  return nil;
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
