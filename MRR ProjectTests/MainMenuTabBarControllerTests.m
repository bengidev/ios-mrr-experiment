#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeCoordinator.h"
#import "../MRR Project/Features/Home/HomeViewController.h"
#import "../MRR Project/Features/MainMenu/MainMenuCoordinator.h"
#import "../MRR Project/Features/MainMenu/MainMenuTabBarController.h"
#import "../MRR Project/Features/Profile/ProfileCoordinator.h"
#import "../MRR Project/Features/Profile/ProfileViewController.h"
#import "../MRR Project/Features/Saved/SavedCoordinator.h"
#import "../MRR Project/Features/Saved/SavedViewController.h"

@interface MainMenuAuthStateObservationSpy : NSObject <MRRAuthStateObservation>
@end

@implementation MainMenuAuthStateObservationSpy

- (void)invalidate {
}

@end

@interface MainMenuAuthenticationControllerSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, strong, nullable) MRRAuthSession *stubSession;

@end

@implementation MainMenuAuthenticationControllerSpy

- (MRRAuthSession *)currentSession {
  return self.stubSession;
}

- (id<MRRAuthStateObservation>)observeAuthStateWithHandler:(MRRAuthStateChangeHandler)handler {
  return [[MainMenuAuthStateObservationSpy alloc] init];
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
  self.stubSession = nil;
  return YES;
}

@end

@interface MainMenuTabBarControllerTests : XCTestCase

@property(nonatomic, strong) MainMenuAuthenticationControllerSpy *authenticationController;
@property(nonatomic, strong) MRRAuthSession *session;
@property(nonatomic, strong) MainMenuCoordinator *mainMenuCoordinator;
@property(nonatomic, strong) MainMenuTabBarController *tabBarController;
@property(nonatomic, strong) UIWindow *window;

- (UINavigationController *)navigationControllerAtIndex:(NSUInteger)index;
- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;

@end

@implementation MainMenuTabBarControllerTests

- (void)setUp {
  [super setUp];

  self.authenticationController = [[MainMenuAuthenticationControllerSpy alloc] init];
  self.session = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                  email:@"cook@example.com"
                                            displayName:@"Test Cook"
                                           providerType:MRRAuthProviderTypeGoogle
                                          emailVerified:YES];
  self.authenticationController.stubSession = self.session;
  self.mainMenuCoordinator = [[MainMenuCoordinator alloc] initWithAuthenticationController:self.authenticationController session:self.session];
  self.tabBarController = (MainMenuTabBarController *)[self.mainMenuCoordinator rootViewController];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.tabBarController;
  [self.window makeKeyAndVisible];
  [self.tabBarController loadViewIfNeeded];
}

- (void)tearDown {
  self.window.hidden = YES;
  self.window = nil;
  self.tabBarController = nil;
  self.mainMenuCoordinator = nil;
  self.session = nil;
  self.authenticationController = nil;

  [super tearDown];
}

- (void)testMainMenuCoordinatorBuildsThreeTabs {
  XCTAssertEqual(self.tabBarController.viewControllers.count, 3);
  XCTAssertEqualObjects(self.tabBarController.tabBar.accessibilityIdentifier, @"mainMenu.tabBar");
}

- (void)testMainMenuDefaultsToHomeTab {
  UINavigationController *navigationController = [self navigationControllerAtIndex:self.tabBarController.selectedIndex];
  XCTAssertTrue([navigationController.topViewController isKindOfClass:[HomeViewController class]]);
  XCTAssertEqual(self.tabBarController.selectedIndex, 0);
}

- (void)testEachTabUsesItsOwnNavigationController {
  for (NSUInteger index = 0; index < self.tabBarController.viewControllers.count; index += 1) {
    XCTAssertTrue([self.tabBarController.viewControllers[index] isKindOfClass:[UINavigationController class]]);
  }
}

- (void)testProfileTabHostsProfileViewController {
  UINavigationController *navigationController = [self navigationControllerAtIndex:2];
  XCTAssertTrue([navigationController.topViewController isKindOfClass:[ProfileViewController class]]);
  XCTAssertEqualObjects(navigationController.tabBarItem.title, @"Profile");
}

- (void)testMountedTabsExposeFeatureAccessibilityIdentifiers {
  UINavigationController *homeNavigationController = [self navigationControllerAtIndex:0];
  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  UINavigationController *profileNavigationController = [self navigationControllerAtIndex:2];

  [homeNavigationController.topViewController loadViewIfNeeded];
  [savedNavigationController.topViewController loadViewIfNeeded];
  [profileNavigationController.topViewController loadViewIfNeeded];

  XCTAssertEqualObjects(homeNavigationController.topViewController.view.accessibilityIdentifier, @"home.view");
  XCTAssertEqualObjects(savedNavigationController.topViewController.view.accessibilityIdentifier, @"saved.view");
  XCTAssertEqualObjects(profileNavigationController.topViewController.view.accessibilityIdentifier, @"profile.view");
}

- (void)testHomeTabReceivesAuthenticatedGreeting {
  UINavigationController *homeNavigationController = [self navigationControllerAtIndex:0];
  [homeNavigationController.topViewController loadViewIfNeeded];

  UILabel *greetingLabel =
      (UILabel *)[self findViewWithAccessibilityIdentifier:@"home.greetingLabel" inView:homeNavigationController.topViewController.view];
  XCTAssertNotNil(greetingLabel);
  XCTAssertEqualObjects(greetingLabel.text, @"Hello, Test Cook");
}

- (void)testFeatureCoordinatorsReturnStandaloneContentControllers {
  HomeCoordinator *homeCoordinator = [[HomeCoordinator alloc] init];
  SavedCoordinator *savedCoordinator = [[SavedCoordinator alloc] init];
  ProfileCoordinator *profileCoordinator =
      [[ProfileCoordinator alloc] initWithAuthenticationController:self.authenticationController session:self.session];

  XCTAssertTrue([[homeCoordinator rootViewController] isKindOfClass:[HomeViewController class]]);
  XCTAssertFalse([[homeCoordinator rootViewController] isKindOfClass:[UINavigationController class]]);
  XCTAssertEqualObjects([[homeCoordinator tabBarItem] title], @"Home");

  XCTAssertTrue([[savedCoordinator rootViewController] isKindOfClass:[SavedViewController class]]);
  XCTAssertFalse([[savedCoordinator rootViewController] isKindOfClass:[UINavigationController class]]);
  XCTAssertEqualObjects([[savedCoordinator tabBarItem] title], @"Saved");

  XCTAssertTrue([[profileCoordinator rootViewController] isKindOfClass:[ProfileViewController class]]);
  XCTAssertFalse([[profileCoordinator rootViewController] isKindOfClass:[UINavigationController class]]);
  XCTAssertEqualObjects([[profileCoordinator tabBarItem] title], @"Profile");
}

- (UINavigationController *)navigationControllerAtIndex:(NSUInteger)index {
  XCTAssertLessThan(index, self.tabBarController.viewControllers.count);
  UIViewController *viewController = self.tabBarController.viewControllers[index];
  XCTAssertTrue([viewController isKindOfClass:[UINavigationController class]]);
  return (UINavigationController *)viewController;
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

@end
