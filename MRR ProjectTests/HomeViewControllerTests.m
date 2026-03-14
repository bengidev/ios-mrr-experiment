#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeViewController.h"

@interface HomeViewController (Testing)

- (void)performConfirmedLogout;

@end

@interface HomeAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *stubSession;
@property(nonatomic, assign) NSInteger signOutCallCount;

@end

@implementation HomeAuthenticationControllerSpy

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

- (BOOL)signOut:(NSError *__autoreleasing _Nullable *)error {
  self.signOutCallCount += 1;
  self.stubSession = nil;
  return YES;
}

@end

@interface HomeDelegateSpy : NSObject <HomeViewControllerDelegate>

@property(nonatomic, assign) BOOL didSignOut;

@end

@implementation HomeDelegateSpy

- (void)homeViewControllerDidSignOut:(HomeViewController *)viewController {
  self.didSignOut = YES;
}

@end

@interface HomeViewControllerTests : XCTestCase

@property(nonatomic, strong) HomeAuthenticationControllerSpy *authenticationController;
@property(nonatomic, strong) HomeViewController *viewController;
@property(nonatomic, strong) HomeDelegateSpy *delegateSpy;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)spinMainRunLoop;

@end

@implementation HomeViewControllerTests

- (void)setUp {
  [super setUp];

  self.authenticationController = [[HomeAuthenticationControllerSpy alloc] init];
  self.authenticationController.stubSession = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                                               email:@"cook@example.com"
                                                                         displayName:@"Home Cook"
                                                                        providerType:MRRAuthProviderTypeGoogle
                                                                       emailVerified:YES];
  self.viewController = [[HomeViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                             session:self.authenticationController.stubSession];
  self.delegateSpy = [[HomeDelegateSpy alloc] init];
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
  self.window.hidden = YES;
  self.window = nil;
  self.delegateSpy = nil;
  self.viewController = nil;
  self.authenticationController = nil;

  [super tearDown];
}

- (void)testHomeExposesCoreAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"home.summaryCard", @"home.displayNameLabel", @"home.emailLabel", @"home.providerLabel", @"home.emailVerificationLabel", @"home.statusLabel",
    @"home.logoutButton"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }
}

- (void)testHomeShowsEmailVerificationStatus {
  UILabel *verificationLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"home.emailVerificationLabel" inView:self.viewController.view];

  XCTAssertNotNil(verificationLabel);
  XCTAssertEqualObjects(verificationLabel.text, @"Email verified: Yes");
}

- (void)testLogoutButtonPresentsConfirmationAlert {
  UIButton *logoutButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"home.logoutButton" inView:self.viewController.view];
  XCTAssertNotNil(logoutButton);

  [logoutButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"home.logoutAlert");
  XCTAssertEqual(self.authenticationController.signOutCallCount, 0);
}

- (void)testConfirmedLogoutSignsOutAndNotifiesDelegate {
  UIButton *logoutButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"home.logoutButton" inView:self.viewController.view];
  [logoutButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  [self.viewController performConfirmedLogout];

  XCTAssertEqual(self.authenticationController.signOutCallCount, 1);
  XCTAssertTrue(self.delegateSpy.didSignOut);
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
