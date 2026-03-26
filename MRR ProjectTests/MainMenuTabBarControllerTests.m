#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeCoordinator.h"
#import "../MRR Project/Features/Home/HomeViewController.h"
#import "../MRR Project/Features/MainMenu/MainMenuCoordinator.h"
#import "../MRR Project/Features/MainMenu/MainMenuTabBarController.h"
#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../MRR Project/Persistence/SavedRecipes/Sync/MRRNoOpSavedRecipesSyncEngine.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"
#import "../MRR Project/Features/Profile/ProfileCoordinator.h"
#import "../MRR Project/Features/Profile/ProfileViewController.h"
#import "../MRR Project/Features/Saved/SavedCoordinator.h"
#import "../MRR Project/Features/Saved/SavedViewController.h"

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
@property(nonatomic, strong) MRRCoreDataStack *coreDataStack;
@property(nonatomic, strong) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, strong) MRRNoOpSavedRecipesSyncEngine *syncEngine;
@property(nonatomic, strong) MainMenuCoordinator *mainMenuCoordinator;
@property(nonatomic, strong) MainMenuTabBarController *tabBarController;
@property(nonatomic, strong) UIWindow *window;

- (void)seedSavedRecipes;
- (MRRSavedRecipeSnapshot *)savedRecipeSnapshotWithRecipeID:(NSString *)recipeID
                                                     title:(NSString *)title
                                                  subtitle:(NSString *)subtitle;
- (UINavigationController *)navigationControllerAtIndex:(NSUInteger)index;
- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout;
- (void)spinMainRunLoop;
- (UIColor *)resolvedColor:(UIColor *)color forTraitCollection:(UITraitCollection *)traitCollection;
- (void)assertColor:(UIColor *)actual matchesColor:(UIColor *)expected;
- (void)assertItemAppearance:(UITabBarItemAppearance *)itemAppearance
           selectedIconColor:(UIColor *)selectedIconColor
             unselectedColor:(UIColor *)unselectedColor API_AVAILABLE(ios(13.0));

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
  NSError *coreDataError = nil;
  self.coreDataStack = [[MRRCoreDataStack alloc] initWithInMemoryStore:YES error:&coreDataError];
  XCTAssertNil(coreDataError);
  XCTAssertNotNil(self.coreDataStack);
  self.savedRecipesStore = [[MRRSavedRecipesStore alloc] initWithCoreDataStack:self.coreDataStack];
  self.syncEngine = [[MRRNoOpSavedRecipesSyncEngine alloc] init];
  [self seedSavedRecipes];
  self.mainMenuCoordinator = [[MainMenuCoordinator alloc] initWithAuthenticationController:self.authenticationController
                                                                                   session:self.session
                                                                          savedRecipesStore:self.savedRecipesStore
                                                                                syncEngine:self.syncEngine
                                                                           logoutController:nil];
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
  self.syncEngine = nil;
  self.savedRecipesStore = nil;
  self.coreDataStack = nil;
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

- (void)testHomeViewControllerSetsTitleDuringInitialization {
  UINavigationController *homeNavigationController = [self navigationControllerAtIndex:0];
  XCTAssertEqualObjects(homeNavigationController.topViewController.title, @"Home");
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

- (void)testSavedTabShowsSectionHeadersAndExpandedRecipeCards {
  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  [savedNavigationController.topViewController loadViewIfNeeded];

  UIView *savedView = savedNavigationController.topViewController.view;
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionsStack" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionHeader.breakfast" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionHeader.lunch" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionHeader.dessert" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionHeader.dinner" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.sectionHeader.snack" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.recipeCard.caesarCrunch" inView:savedView]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.recipeCard.spinachFeta" inView:savedView]);
}

- (void)testSavedRecipeCardPresentsRecipeDetail {
  self.tabBarController.selectedIndex = 1;

  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  [savedNavigationController.topViewController loadViewIfNeeded];

  UIView *savedView = savedNavigationController.topViewController.view;
  [savedView layoutIfNeeded];
  UIControl *recipeCardControl =
      (UIControl *)[self findViewWithAccessibilityIdentifier:@"saved.recipeCard.caesarCrunch" inView:savedView];

  XCTAssertNotNil(recipeCardControl);
  XCTAssertTrue([recipeCardControl isKindOfClass:[UIControl class]]);
  XCTAssertEqualObjects(recipeCardControl.accessibilityHint, @"Double tap to view recipe details.");

  [recipeCardControl sendActionsForControlEvents:UIControlEventTouchUpInside];

  __block UINavigationController *detailNavigationController = nil;
  __block UILabel *titleLabel = nil;
  [self waitForCondition:^BOOL {
    detailNavigationController = (UINavigationController *)savedNavigationController.topViewController.presentedViewController;
    if (![detailNavigationController isKindOfClass:[UINavigationController class]]) {
      return NO;
    }

    UIViewController *detailRootViewController = detailNavigationController.topViewController;
    if (![detailRootViewController isKindOfClass:[OnboardingRecipeDetailViewController class]]) {
      return NO;
    }

    [detailRootViewController loadViewIfNeeded];
    titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.titleLabel"
                                                               inView:detailRootViewController.view];
    return [titleLabel.text isEqualToString:@"Garden Caesar Crunch"];
  } timeout:2.0];

  XCTAssertNotNil(detailNavigationController);
  XCTAssertEqual(detailNavigationController.modalPresentationStyle, UIModalPresentationFullScreen);
  XCTAssertNotNil(titleLabel);
  [detailNavigationController dismissViewControllerAnimated:NO completion:nil];
}

- (void)testSavedFavoriteHeartActsLikeASavedActionButton {
  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  [savedNavigationController.topViewController loadViewIfNeeded];

  UIView *savedView = savedNavigationController.topViewController.view;
  [savedView layoutIfNeeded];
  UIButton *favoriteButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"saved.favoriteButton.caesarCrunch" inView:savedView];

  XCTAssertNotNil(favoriteButton);
  XCTAssertTrue([favoriteButton isKindOfClass:[UIButton class]]);
  XCTAssertTrue((favoriteButton.accessibilityTraits & UIAccessibilityTraitButton) != 0);
  XCTAssertTrue(favoriteButton.selected);
  XCTAssertGreaterThanOrEqual(CGRectGetWidth(favoriteButton.bounds), 44.0);
  XCTAssertGreaterThanOrEqual(CGRectGetHeight(favoriteButton.bounds), 44.0);
  XCTAssertNotNil(favoriteButton.accessibilityLabel);
  XCTAssertEqualObjects(favoriteButton.accessibilityValue, @"Saved");

  [favoriteButton sendActionsForControlEvents:UIControlEventTouchUpInside];

  [self waitForCondition:^BOOL {
    [savedView layoutIfNeeded];
    return [self findViewWithAccessibilityIdentifier:@"saved.favoriteButton.caesarCrunch" inView:savedView] == nil &&
           [self findViewWithAccessibilityIdentifier:@"saved.recipeCard.caesarCrunch" inView:savedView] == nil &&
           [self findViewWithAccessibilityIdentifier:@"saved.recipeCard.spinachFeta" inView:savedView] != nil;
  } timeout:2.5];
}

- (void)testSavedTabRefreshesWhenStorePostsChangeNotification {
  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  SavedViewController *savedViewController = (SavedViewController *)savedNavigationController.topViewController;
  [savedViewController loadViewIfNeeded];

  UIView *savedView = savedViewController.view;
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"saved.recipeCard.chiliCrunchEggs" inView:savedView]);

  NSError *saveError = nil;
  XCTAssertTrue([self.savedRecipesStore saveRecipeSnapshot:[self savedRecipeSnapshotWithRecipeID:@"chiliCrunchEggs"
                                                                                           title:@"Chili Crunch Eggs"
                                                                                        subtitle:@"Fast breakfast bowl"]
                                                     error:&saveError]);
  XCTAssertNil(saveError);

  [self waitForCondition:^BOOL {
    [savedView layoutIfNeeded];
    return [self findViewWithAccessibilityIdentifier:@"saved.recipeCard.chiliCrunchEggs" inView:savedView] != nil;
  } timeout:2.0];
}

- (void)testSavedTabReloadsFromStoreWhenItBecomesVisibleAgain {
  UINavigationController *savedNavigationController = [self navigationControllerAtIndex:1];
  SavedViewController *savedViewController = (SavedViewController *)savedNavigationController.topViewController;
  [savedViewController loadViewIfNeeded];

  UIView *savedView = savedViewController.view;
  [[NSNotificationCenter defaultCenter] removeObserver:savedViewController
                                                  name:MRRSavedRecipesStoreDidChangeNotification
                                                object:self.savedRecipesStore];

  NSError *saveError = nil;
  XCTAssertTrue([self.savedRecipesStore saveRecipeSnapshot:[self savedRecipeSnapshotWithRecipeID:@"roastedTomatoes"
                                                                                           title:@"Roasted Tomato Toast"
                                                                                        subtitle:@"Savory morning bite"]
                                                     error:&saveError]);
  XCTAssertNil(saveError);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"saved.recipeCard.roastedTomatoes" inView:savedView]);

  [savedViewController viewWillAppear:NO];
  [savedView layoutIfNeeded];

  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"saved.recipeCard.roastedTomatoes" inView:savedView]);
}

- (void)seedSavedRecipes {
  NSError *saveError = nil;
  XCTAssertTrue([self.savedRecipesStore saveRecipeSnapshot:[self savedRecipeSnapshotWithRecipeID:@"caesarCrunch"
                                                                                           title:@"Garden Caesar Crunch"
                                                                                        subtitle:@"Crisp lunch favorite"]
                                                     error:&saveError]);
  XCTAssertNil(saveError);
  XCTAssertTrue([self.savedRecipesStore saveRecipeSnapshot:[self savedRecipeSnapshotWithRecipeID:@"spinachFeta"
                                                                                           title:@"Spinach & Blueberry Feta Salad"
                                                                                        subtitle:@"Bright bowl for warm days"]
                                                     error:&saveError]);
  XCTAssertNil(saveError);
}

- (MRRSavedRecipeSnapshot *)savedRecipeSnapshotWithRecipeID:(NSString *)recipeID
                                                     title:(NSString *)title
                                                  subtitle:(NSString *)subtitle {
  HomeRecipeCard *recipeCard = [[HomeRecipeCard alloc] initWithRecipeID:recipeID
                                                                  title:title
                                                               subtitle:subtitle
                                                              assetName:@"avocado-toast"
                                                         imageURLString:nil
                                                            summaryText:@"Persisted saved recipe for tab tests."
                                                         readyInMinutes:20
                                                               servings:2
                                                           calorieCount:390
                                                        popularityScore:120
                                                             sourceName:@"MRR Tests"
                                                        sourceURLString:@"https://example.com/saved"
                                                               mealType:HomeCategoryIdentifierBreakfast
                                                                   tags:@[ @"Breakfast", @"Fresh" ]];
  OnboardingRecipeIngredient *ingredientOne =
      [[OnboardingRecipeIngredient alloc] initWithName:@"Sourdough" displayText:@"2 slices sourdough"];
  OnboardingRecipeIngredient *ingredientTwo =
      [[OnboardingRecipeIngredient alloc] initWithName:@"Avocado" displayText:@"1 ripe avocado"];
  OnboardingRecipeInstruction *instructionOne =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 1" detailText:@"Toast the bread until golden."];
  OnboardingRecipeInstruction *instructionTwo =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 2" detailText:@"Top with avocado and finish."];
  OnboardingRecipeDetail *detail =
      [[OnboardingRecipeDetail alloc] initWithTitle:title
                                           subtitle:subtitle
                                          assetName:@"avocado-toast"
                                 heroImageURLString:nil
                                       durationText:@"20 mins"
                                        calorieText:@"390 kcal"
                                       servingsText:@"2 servings"
                                        summaryText:@"Persisted saved recipe for tab tests."
                                        ingredients:@[ ingredientOne, ingredientTwo ]
                                       instructions:@[ instructionOne, instructionTwo ]
                                              tools:@[ @"Skillet", @"Mixing bowl" ]
                                               tags:@[ @"Breakfast", @"Fresh" ]
                                         sourceName:@"MRR Tests"
                                    sourceURLString:@"https://example.com/saved"
                                     productContext:nil];
  NSDate *savedAt = [NSDate dateWithTimeIntervalSince1970:1700000100.0];
  return [MRRSavedRecipeSnapshot snapshotWithUserID:self.session.userID
                                         recipeCard:recipeCard
                                       recipeDetail:detail
                                            savedAt:savedAt
                                    localModifiedAt:[savedAt dateByAddingTimeInterval:15.0]];
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

- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout {
  NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (!condition()) {
    if ([timeoutDate timeIntervalSinceNow] <= 0.0) {
      XCTFail(@"Condition not met before timeout");
      return;
    }
    [self spinMainRunLoop];
  }
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.08]];
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

@end
