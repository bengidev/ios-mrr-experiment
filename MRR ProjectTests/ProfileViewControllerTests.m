#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Profile/ProfileViewController.h"

@interface ProfileViewController (Testing)

- (void)performConfirmedLogout;

@end

@interface ProfileAuthStateObservationSpy : NSObject <MRRAuthStateObservation>
@end

@implementation ProfileAuthStateObservationSpy

- (void)invalidate {
}

@end

@interface ProfileAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *stubSession;
@property(nonatomic, strong, nullable) NSError *nextSignOutError;
@property(nonatomic, assign) NSInteger signOutCallCount;
@property(nonatomic, copy, nullable) MRRAuthStateChangeHandler authStateHandler;

@end

@implementation ProfileAuthenticationControllerSpy

- (MRRAuthSession *)currentSession {
  return self.stubSession;
}

- (id<MRRAuthStateObservation>)observeAuthStateWithHandler:(MRRAuthStateChangeHandler)handler {
  self.authStateHandler = handler;
  return [[ProfileAuthStateObservationSpy alloc] init];
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
  if (self.nextSignOutError != nil) {
    if (error != NULL) {
      *error = self.nextSignOutError;
    }
    return NO;
  }

  self.stubSession = nil;
  if (self.authStateHandler != nil) {
    self.authStateHandler(nil);
  }
  return YES;
}

@end

@interface ProfileViewControllerTests : XCTestCase

@property(nonatomic, strong) ProfileAuthenticationControllerSpy *authenticationController;
@property(nonatomic, strong) ProfileViewController *viewController;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)spinMainRunLoop;

@end

@implementation ProfileViewControllerTests

- (void)setUp {
  [super setUp];

  self.authenticationController = [[ProfileAuthenticationControllerSpy alloc] init];
  self.authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                               email:@"cook@example.com"
                                                                         displayName:@"Home Cook"
                                                                        providerType:MRRAuthProviderTypeGoogle
                                                                       emailVerified:YES];
  self.viewController = [[ProfileViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                                session:self.authenticationController.stubSession];
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
  self.window.hidden = YES;
  self.window = nil;
  self.viewController = nil;
  self.authenticationController = nil;

  [super tearDown];
}

- (void)testProfileExposesCoreAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"profile.summaryCard", @"profile.displayNameLabel", @"profile.emailLabel", @"profile.providerLabel", @"profile.emailVerificationLabel",
    @"profile.statusLabel", @"profile.logoutButton"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }
}

- (void)testProfileShowsEmailVerificationStatus {
  UILabel *verificationLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"profile.emailVerificationLabel"
                                                                             inView:self.viewController.view];

  XCTAssertNotNil(verificationLabel);
  XCTAssertEqualObjects(verificationLabel.text, @"Email verified: Yes");
}

- (void)testLogoutButtonPresentsConfirmationAlert {
  UIButton *logoutButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"profile.logoutButton" inView:self.viewController.view];
  XCTAssertNotNil(logoutButton);

  [logoutButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"profile.logoutAlert");
  XCTAssertEqual(self.authenticationController.signOutCallCount, 0);
}

- (void)testConfirmedLogoutSignsOut {
  UIButton *logoutButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"profile.logoutButton" inView:self.viewController.view];
  [logoutButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  [self.viewController performConfirmedLogout];

  XCTAssertEqual(self.authenticationController.signOutCallCount, 1);
}

- (void)testLogoutFailurePresentsErrorAlert {
  self.authenticationController.nextSignOutError = [NSError errorWithDomain:@"ProfileTests" code:1 userInfo:@{NSLocalizedDescriptionKey : @"Nope"}];

  [self.viewController performConfirmedLogout];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"profile.logoutErrorAlert");
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
