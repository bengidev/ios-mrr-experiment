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
static UIColor *MRRMainMenuTestDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return darkColor;
      }

      return lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRMainMenuTestNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRMainMenuTestDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRMainMenuTestSelectedColor(void) {
  return MRRMainMenuTestNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                   [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRMainMenuTestUnselectedColor(void) {
  return MRRMainMenuTestNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                   [UIColor colorWithWhite:0.63 alpha:1.0]);
}

static UIColor *MRRMainMenuTestBackgroundColor(void) {
  return MRRMainMenuTestNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.15 alpha:1.0]);
}

- (UIColor *)resolvedColor:(UIColor *)color forTraitCollection:(UITraitCollection *)traitCollection;
- (void)assertColor:(UIColor *)actual matchesColor:(UIColor *)expected;
- (void)assertItemAppearance:(UITabBarItemAppearance *)itemAppearance
           selectedIconColor:(UIColor *)selectedIconColor
             unselectedColor:(UIColor *)unselectedColor API_AVAILABLE(ios(13.0));
- (void)testMainMenuAppliesThemeColorsToTabBar {
  UIColor *selectedIconColor = MRRMainMenuTestSelectedColor();
  UIColor *unselectedColor = MRRMainMenuTestUnselectedColor();
  UIColor *backgroundColor = MRRMainMenuTestBackgroundColor();

  [self assertColor:self.tabBarController.tabBar.tintColor matchesColor:selectedIconColor];
  if (@available(iOS 10.0, *)) {
    [self assertColor:self.tabBarController.tabBar.unselectedItemTintColor matchesColor:unselectedColor];
  }
  [self assertColor:self.tabBarController.tabBar.backgroundColor matchesColor:backgroundColor];
  [self assertColor:self.tabBarController.tabBar.barTintColor matchesColor:backgroundColor];
  XCTAssertFalse(self.tabBarController.tabBar.translucent);

  if (@available(iOS 13.0, *)) {
    UITabBarAppearance *appearance = self.tabBarController.tabBar.standardAppearance;
    XCTAssertNotNil(appearance);
    [self assertColor:appearance.backgroundColor matchesColor:backgroundColor];
    [self assertItemAppearance:appearance.stackedLayoutAppearance
             selectedIconColor:selectedIconColor
               unselectedColor:unselectedColor];
    [self assertItemAppearance:appearance.inlineLayoutAppearance
             selectedIconColor:selectedIconColor
               unselectedColor:unselectedColor];
    [self assertItemAppearance:appearance.compactInlineLayoutAppearance
             selectedIconColor:selectedIconColor
               unselectedColor:unselectedColor];
  }

  for (UITabBarItem *item in self.tabBarController.tabBar.items) {
    XCTAssertEqualWithAccuracy(item.titlePositionAdjustment.horizontal, 0.0, 0.001);
    XCTAssertEqualWithAccuracy(item.titlePositionAdjustment.vertical, 0.0, 0.001);
  }

}

- (void)testMainMenuScrollEdgeAppearanceMatchesStandardAppearanceTheme {
  if (@available(iOS 15.0, *)) {
    UITabBarAppearance *standardAppearance = self.tabBarController.tabBar.standardAppearance;
    UITabBarAppearance *scrollEdgeAppearance = self.tabBarController.tabBar.scrollEdgeAppearance;

    XCTAssertNotNil(standardAppearance);
    XCTAssertNotNil(scrollEdgeAppearance);
    [self assertColor:scrollEdgeAppearance.backgroundColor matchesColor:standardAppearance.backgroundColor];
    [self assertItemAppearance:scrollEdgeAppearance.stackedLayoutAppearance
             selectedIconColor:standardAppearance.stackedLayoutAppearance.selected.iconColor
               unselectedColor:standardAppearance.stackedLayoutAppearance.normal.iconColor];
  }
}

- (UIColor *)resolvedColor:(UIColor *)color forTraitCollection:(UITraitCollection *)traitCollection {
  if (color == nil) {
    return nil;
  }

  if (@available(iOS 13.0, *)) {
    return [color resolvedColorWithTraitCollection:traitCollection];
  }

  return color;
}

- (void)assertColor:(UIColor *)actual matchesColor:(UIColor *)expected {
  XCTAssertNotNil(actual);
  XCTAssertNotNil(expected);

  NSArray<UITraitCollection *> *traitCollections = nil;
  if (@available(iOS 13.0, *)) {
    traitCollections = @[
      [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight],
      [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]
    ];
  } else {
    traitCollections = @[ [UITraitCollection traitCollectionWithTraitsFromCollections:@[]] ];
  }

  for (UITraitCollection *traitCollection in traitCollections) {
    UIColor *resolvedActual = [self resolvedColor:actual forTraitCollection:traitCollection];
    UIColor *resolvedExpected = [self resolvedColor:expected forTraitCollection:traitCollection];

    CGFloat actualRed = 0.0;
    CGFloat actualGreen = 0.0;
    CGFloat actualBlue = 0.0;
    CGFloat actualAlpha = 0.0;
    CGFloat expectedRed = 0.0;
    CGFloat expectedGreen = 0.0;
    CGFloat expectedBlue = 0.0;
    CGFloat expectedAlpha = 0.0;

    XCTAssertTrue([resolvedActual getRed:&actualRed green:&actualGreen blue:&actualBlue alpha:&actualAlpha]);
    XCTAssertTrue([resolvedExpected getRed:&expectedRed green:&expectedGreen blue:&expectedBlue alpha:&expectedAlpha]);
    XCTAssertEqualWithAccuracy(actualRed, expectedRed, 0.001);
    XCTAssertEqualWithAccuracy(actualGreen, expectedGreen, 0.001);
    XCTAssertEqualWithAccuracy(actualBlue, expectedBlue, 0.001);
    XCTAssertEqualWithAccuracy(actualAlpha, expectedAlpha, 0.001);
  }
}

- (void)assertItemAppearance:(UITabBarItemAppearance *)itemAppearance
           selectedIconColor:(UIColor *)selectedIconColor
             unselectedColor:(UIColor *)unselectedColor API_AVAILABLE(ios(13.0)) {
  XCTAssertNotNil(itemAppearance);
  [self assertColor:itemAppearance.selected.iconColor matchesColor:selectedIconColor];
  [self assertColor:itemAppearance.normal.iconColor matchesColor:unselectedColor];
  [self assertColor:itemAppearance.selected.titleTextAttributes[NSForegroundColorAttributeName] matchesColor:selectedIconColor];
  [self assertColor:itemAppearance.normal.titleTextAttributes[NSForegroundColorAttributeName] matchesColor:unselectedColor];
  XCTAssertEqualWithAccuracy(itemAppearance.selected.titlePositionAdjustment.horizontal, 0.0, 0.001);
  XCTAssertEqualWithAccuracy(itemAppearance.selected.titlePositionAdjustment.vertical, 0.0, 0.001);
  XCTAssertEqualWithAccuracy(itemAppearance.normal.titlePositionAdjustment.horizontal, 0.0, 0.001);
  XCTAssertEqualWithAccuracy(itemAppearance.normal.titlePositionAdjustment.vertical, 0.0, 0.001);
}

