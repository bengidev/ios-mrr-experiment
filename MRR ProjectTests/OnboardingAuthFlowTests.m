#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/MRREmailAuthenticationViewController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/MRRForgotPasswordViewController.h"
#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface MRRForgotPasswordViewController (Testing)

- (void)handleSuccessAlertAcknowledged;

@end

@interface OnboardingAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *sessionToReturn;
@property(nonatomic, strong, nullable) NSError *nextEmailError;
@property(nonatomic, strong, nullable) NSError *nextPasswordResetError;
@property(nonatomic, strong, nullable) NSError *nextGoogleError;
@property(nonatomic, strong, nullable) NSError *nextLinkError;
@property(nonatomic, assign) BOOL hasPendingCredentialLinkStub;
@property(nonatomic, assign) BOOL delaysGoogleCompletion;
@property(nonatomic, copy, nullable) NSString *pendingLinkEmailStub;
@property(nonatomic, assign) NSInteger googleSignInCallCount;
@property(nonatomic, assign) NSInteger passwordResetCallCount;
@property(nonatomic, copy, nullable) NSString *lastPasswordResetEmail;
@property(nonatomic, strong, nullable) UIViewController *lastGooglePresentingViewController;
@property(nonatomic, copy, nullable) MRRAuthSessionCompletion pendingGoogleCompletion;

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

- (void)sendPasswordResetForEmail:(NSString *)email completion:(MRRAuthCompletion)completion {
  self.passwordResetCallCount += 1;
  self.lastPasswordResetEmail = email;
  if ([self.nextPasswordResetError.domain isEqualToString:@"FIRAuthErrorDomain"] && self.nextPasswordResetError.code == 17011) {
    completion(nil);
    return;
  }

  completion(self.nextPasswordResetError);
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  self.googleSignInCallCount += 1;
  self.lastGooglePresentingViewController = viewController;
  if (self.delaysGoogleCompletion) {
    self.pendingGoogleCompletion = completion;
    return;
  }

  completion(self.sessionToReturn, self.nextGoogleError);
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  if (self.nextLinkError == nil) {
    self.hasPendingCredentialLinkStub = NO;
    self.pendingLinkEmailStub = nil;
  }

  completion(self.nextLinkError);
}

- (BOOL)signOut:(NSError *__autoreleasing _Nullable *)error {
  return YES;
}

- (void)completePendingGoogleSignIn {
  MRRAuthSessionCompletion completion = self.pendingGoogleCompletion;
  self.pendingGoogleCompletion = nil;
  if (completion != nil) {
    completion(self.sessionToReturn, self.nextGoogleError);
  }
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
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) OnboardingAuthDelegateSpy *delegateSpy;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (MRREmailAuthenticationViewController *)topAuthenticationViewController;
- (MRRForgotPasswordViewController *)topForgotPasswordViewController;
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
  self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
  self.navigationController.navigationBarHidden = YES;
  self.delegateSpy = [[OnboardingAuthDelegateSpy alloc] init];
  self.viewController.delegate = self.delegateSpy;
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  [self.navigationController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.window.hidden = YES;
  self.window = nil;
  self.navigationController = nil;
  self.delegateSpy = nil;
  self.viewController = nil;
  self.authenticationController = nil;
  self.stateController = nil;
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testEmailButtonPushesSignUpScreen {
  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  XCTAssertNotNil(emailButton);

  [emailButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  XCTAssertNotNil(authenticationViewController);
  XCTAssertEqualObjects(authenticationViewController.view.accessibilityIdentifier, @"auth.signUp.view");
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"auth.signUp.firstNameField" inView:authenticationViewController.view]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"auth.signUp.lastNameField" inView:authenticationViewController.view]);
}

- (void)testSigninLabelPushesSignInScreen {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  XCTAssertNotNil(signinButton);

  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  XCTAssertNotNil(authenticationViewController);
  XCTAssertEqualObjects(authenticationViewController.view.accessibilityIdentifier, @"auth.signIn.view");

  UIView *authView = authenticationViewController.view;
  [authView layoutIfNeeded];
  UITextField *passwordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.passwordField" inView:authView];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton" inView:authView];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.submitButton" inView:authView];
  UIStackView *footerStackView = (UIStackView *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.footerStack" inView:authView];
  CGRect passwordFrame = [passwordField convertRect:passwordField.bounds toView:authView];
  CGRect forgotPasswordFrame = [forgotPasswordButton convertRect:forgotPasswordButton.bounds toView:authView];
  CGRect submitButtonFrame = [submitButton convertRect:submitButton.bounds toView:authView];
  CGRect footerFrame = [footerStackView convertRect:footerStackView.bounds toView:authView];
  XCTAssertGreaterThan(CGRectGetMinY(forgotPasswordFrame), CGRectGetMaxY(passwordFrame));
  XCTAssertLessThanOrEqual(CGRectGetMinY(footerFrame) - CGRectGetMaxY(submitButtonFrame), 20.0);
  XCTAssertGreaterThan(CGRectGetMaxY(footerFrame), CGRectGetHeight(authView.bounds) - 80.0);
}

- (void)testForgotPasswordPushesResetScreenWithPrefilledEmail {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField"
                                                                              inView:authenticationViewController.view];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  emailField.text = @"cook@example.com";

  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UITextField *resetEmailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.emailField"
                                                                                   inView:forgotPasswordViewController.view];

  XCTAssertEqualObjects(forgotPasswordViewController.view.accessibilityIdentifier, @"auth.resetPassword.view");
  XCTAssertEqualObjects(resetEmailField.text, @"cook@example.com");
}

- (void)testForgotPasswordRejectsInvalidEmailInline {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UITextField *resetEmailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.emailField"
                                                                                   inView:forgotPasswordViewController.view];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.submitButton"
                                                                          inView:forgotPasswordViewController.view];
  UILabel *errorLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.errorLabel"
                                                                      inView:forgotPasswordViewController.view];

  resetEmailField.text = @"invalid-email";
  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.passwordResetCallCount, 0);
  XCTAssertFalse(errorLabel.hidden);
  XCTAssertEqualObjects(errorLabel.text, @"Please enter a valid email address to continue.");
}

- (void)testForgotPasswordSuccessPresentsAlertAndReturnsToOnboardingRoot {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField"
                                                                              inView:authenticationViewController.view];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  emailField.text = @"cook@example.com";
  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.submitButton"
                                                                          inView:forgotPasswordViewController.view];
  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.passwordResetCallCount, 1);
  XCTAssertEqualObjects(self.authenticationController.lastPasswordResetEmail, @"cook@example.com");
  XCTAssertTrue([forgotPasswordViewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(forgotPasswordViewController.presentedViewController.view.accessibilityIdentifier, @"auth.resetPassword.successAlert");

  [forgotPasswordViewController handleSuccessAlertAcknowledged];
  [self spinMainRunLoop];

  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[OnboardingViewController class]]);
}

- (void)testForgotPasswordUserNotFoundStillShowsGenericSuccessAlert {
  self.authenticationController.nextPasswordResetError = [NSError errorWithDomain:@"FIRAuthErrorDomain"
                                                                             code:17011
                                                                         userInfo:@{NSLocalizedDescriptionKey : @"User not found"}];

  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UITextField *resetEmailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.emailField"
                                                                                   inView:forgotPasswordViewController.view];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.submitButton"
                                                                          inView:forgotPasswordViewController.view];
  resetEmailField.text = @"missing@example.com";

  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([forgotPasswordViewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(forgotPasswordViewController.presentedViewController.view.accessibilityIdentifier, @"auth.resetPassword.successAlert");
}

- (void)testForgotPasswordRealErrorStaysOnResetScreen {
  self.authenticationController.nextPasswordResetError = [NSError errorWithDomain:@"FIRAuthErrorDomain"
                                                                             code:17020
                                                                         userInfo:@{NSLocalizedDescriptionKey : @"Network issue"}];

  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UITextField *resetEmailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.emailField"
                                                                                   inView:forgotPasswordViewController.view];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.submitButton"
                                                                          inView:forgotPasswordViewController.view];
  UILabel *errorLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.errorLabel"
                                                                      inView:forgotPasswordViewController.view];
  resetEmailField.text = @"cook@example.com";

  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertNil(forgotPasswordViewController.presentedViewController);
  XCTAssertFalse(errorLabel.hidden);
  XCTAssertEqualObjects(errorLabel.text, @"Koneksi jaringan sedang bermasalah. Coba lagi sebentar lagi.");
}

- (void)testForgotPasswordSuccessReturnsToFreshSignInFlow {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [signinButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField"
                                                                              inView:authenticationViewController.view];
  UITextField *passwordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.passwordField"
                                                                                 inView:authenticationViewController.view];
  UIButton *forgotPasswordButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.signIn.forgotPasswordButton"
                                                                                  inView:authenticationViewController.view];
  emailField.text = @"cook@example.com";
  passwordField.text = @"password123";
  [forgotPasswordButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRForgotPasswordViewController *forgotPasswordViewController = [self topForgotPasswordViewController];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.resetPassword.submitButton"
                                                                          inView:forgotPasswordViewController.view];
  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];
  [forgotPasswordViewController handleSuccessAlertAcknowledged];
  [self spinMainRunLoop];

  UIButton *reopenedSigninButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  [reopenedSigninButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *freshSignInViewController = [self topAuthenticationViewController];
  UITextField *freshEmailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField"
                                                                                   inView:freshSignInViewController.view];
  UITextField *freshPasswordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.passwordField"
                                                                                      inView:freshSignInViewController.view];

  XCTAssertEqualObjects(freshSignInViewController.view.accessibilityIdentifier, @"auth.signIn.view");
  XCTAssertEqualObjects(freshEmailField.text ?: @"", @"");
  XCTAssertEqualObjects(freshPasswordField.text ?: @"", @"");
}

- (void)testAuthenticationScreenUsesArrowBackButtonAndDoesNotAutofocusFields {
  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  [emailButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UIView *authView = authenticationViewController.view;
  UIButton *backButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.backButton" inView:authView];
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField" inView:authView];
  UITextField *passwordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.passwordField" inView:authView];
  UIScrollView *scrollView = (UIScrollView *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.scrollView" inView:authView];

  XCTAssertEqualObjects([backButton titleForState:UIControlStateNormal], @"←");
  XCTAssertFalse(emailField.isFirstResponder);
  XCTAssertFalse(passwordField.isFirstResponder);
  XCTAssertEqual(scrollView.keyboardDismissMode, UIScrollViewKeyboardDismissModeOnDrag);
}

- (void)testSubmittingEmailSignupAuthenticatesFromPushedScreen {
  self.authenticationController.sessionToReturn = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                                   email:@"cook@example.com"
                                                                             displayName:@"Email Cook"
                                                                            providerType:MRRAuthProviderTypeEmail
                                                                           emailVerified:NO];

  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  [emailButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UIView *authView = authenticationViewController.view;
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField" inView:authView];
  UITextField *passwordField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.passwordField" inView:authView];
  UIButton *submitButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.submitButton" inView:authView];
  emailField.text = @"cook@example.com";
  passwordField.text = @"password123";

  [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(self.delegateSpy.didAuthenticate);
}

- (void)testGoogleButtonStartsGoogleAuthAndAuthenticatesOnSuccess {
  self.authenticationController.sessionToReturn = [[MRRAuthSession alloc] initWithUserID:@"google-uid"
                                                                                   email:@"cook@example.com"
                                                                             displayName:@"Google Cook"
                                                                            providerType:MRRAuthProviderTypeGoogle
                                                                           emailVerified:YES];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertEqualObjects(self.authenticationController.lastGooglePresentingViewController, self.viewController);
  XCTAssertTrue(self.delegateSpy.didAuthenticate);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testGoogleButtonShowsCenteredLoadingOverlayWhileWaitingForResult {
  self.authenticationController.delaysGoogleCompletion = YES;
  self.authenticationController.sessionToReturn = [[MRRAuthSession alloc] initWithUserID:@"google-uid"
                                                                                   email:@"cook@example.com"
                                                                             displayName:@"Google Cook"
                                                                            providerType:MRRAuthProviderTypeGoogle
                                                                           emailVerified:YES];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  UIVisualEffectView *loadingOverlay = (UIVisualEffectView *)[self findViewWithAccessibilityIdentifier:@"onboarding.loadingOverlay"
                                                                                                inView:self.viewController.view];
  UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[self findViewWithAccessibilityIdentifier:@"onboarding.loadingIndicator"
                                                                                                            inView:self.viewController.view];

  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self.viewController.view layoutIfNeeded];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertFalse(loadingOverlay.hidden);
  XCTAssertEqualWithAccuracy(loadingOverlay.alpha, 1.0, 0.001);
  XCTAssertTrue(loadingIndicator.isAnimating);
  XCTAssertFalse(emailButton.enabled);
  XCTAssertFalse(googleButton.enabled);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.authLoadingIndicator" inView:self.viewController.view]);

  [self.authenticationController completePendingGoogleSignIn];
  [self spinMainRunLoop];

  XCTAssertTrue(loadingOverlay.hidden);
  XCTAssertTrue(self.delegateSpy.didAuthenticate);
}

- (void)testGoogleButtonCancellationStopsWithoutAlert {
  self.authenticationController.nextGoogleError = [NSError errorWithDomain:MRRAuthenticationErrorDomain
                                                                      code:MRRAuthenticationErrorCodeCancelled
                                                                  userInfo:nil];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertFalse(self.delegateSpy.didAuthenticate);
  XCTAssertNil(self.viewController.presentedViewController);
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[OnboardingViewController class]]);
}

- (void)testGoogleButtonErrorPresentsAuthAlert {
  self.authenticationController.nextGoogleError = [NSError errorWithDomain:MRRAuthenticationErrorDomain
                                                                      code:MRRAuthenticationErrorCodeMissingGoogleCallbackScheme
                                                                  userInfo:nil];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertFalse(self.delegateSpy.didAuthenticate);
  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"onboarding.authErrorAlert");
}

- (void)testGoogleButtonRequiresAccountLinkingPushesPrefilledSignInFlow {
  self.authenticationController.pendingLinkEmailStub = @"cook@example.com";
  self.authenticationController.nextGoogleError = [NSError errorWithDomain:MRRAuthenticationErrorDomain
                                                                      code:MRRAuthenticationErrorCodeRequiresAccountLinking
                                                                  userInfo:@{MRRAuthPendingLinkEmailUserInfoKey : @"cook@example.com"}];

  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];
  [googleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRREmailAuthenticationViewController *authenticationViewController = [self topAuthenticationViewController];
  UILabel *helperLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.helperLabel"
                                                                       inView:authenticationViewController.view];
  UITextField *emailField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.emailField"
                                                                              inView:authenticationViewController.view];
  UIButton *switchModeButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"auth.emailScreen.switchModeButton"
                                                                              inView:authenticationViewController.view];

  XCTAssertEqual(self.authenticationController.googleSignInCallCount, 1);
  XCTAssertEqualObjects(authenticationViewController.view.accessibilityIdentifier, @"auth.signIn.view");
  XCTAssertEqualObjects(emailField.text, @"cook@example.com");
  XCTAssertEqualObjects(helperLabel.text, @"Sign in with your existing email account to finish linking the pending credential.");
  XCTAssertTrue(switchModeButton.hidden);
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

- (MRREmailAuthenticationViewController *)topAuthenticationViewController {
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[MRREmailAuthenticationViewController class]]);
  return (MRREmailAuthenticationViewController *)self.navigationController.topViewController;
}

- (MRRForgotPasswordViewController *)topForgotPasswordViewController {
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[MRRForgotPasswordViewController class]]);
  return (MRRForgotPasswordViewController *)self.navigationController.topViewController;
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
