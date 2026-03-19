#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeDataSource.h"
#import "../MRR Project/Features/Home/HomeRecipeListViewController.h"
#import "../MRR Project/Features/Home/HomeViewController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"

@interface HomeViewController (Testing) <UICollectionViewDelegate>

@property(nonatomic, readonly) UITextField *searchTextField;
@property(nonatomic, readonly) UIButton *filterButton;
@property(nonatomic, readonly) UIView *loadingStateView;
@property(nonatomic, readonly) UICollectionView *categoryCollectionView;
@property(nonatomic, readonly) UICollectionView *recommendationCollectionView;
@property(nonatomic, readonly) UICollectionView *searchResultsCollectionView;
@property(nonatomic, readonly) UIStackView *searchResultsSectionView;
@property(nonatomic, readonly) UIStackView *recommendationSectionView;
@property(nonatomic, readonly) UIStackView *weeklySectionView;
@property(nonatomic, readonly) UILabel *recommendationEmptyStateLabel;
@property(nonatomic, readonly) UILabel *searchEmptyStateLabel;
@property(nonatomic, readonly) NSArray<HomeRecipeCard *> *filteredRecommendationRecipes;
@property(nonatomic, readonly) NSArray<HomeRecipeCard *> *currentSearchResults;
@property(nonatomic, readonly, nullable) HomeCategory *selectedCategory;
@property(nonatomic, assign) HomeFilterOption currentFilterOption;
@property(nonatomic, assign) HomeSearchState searchState;
@property(nonatomic, readonly, getter=isLoadingContent) BOOL loadingContent;
- (void)applyFilterOption:(HomeFilterOption)filterOption;
- (BOOL)textFieldShouldReturn:(UITextField *)textField;

@end

@interface HomeRecipeListViewController (Testing)

@property(nonatomic, readonly) UICollectionView *collectionView;
@property(nonatomic, readonly) UILabel *emptyStateLabel;
@property(nonatomic, readonly) NSArray<HomeRecipeCard *> *recipes;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface HomeViewControllerTests : XCTestCase

@property(nonatomic, strong) MRRAuthSession *session;
@property(nonatomic, strong) HomeMockDataProvider *dataProvider;
@property(nonatomic, strong) HomeViewController *viewController;
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)finishInitialLoadIfNeeded;
- (UIViewController *)presentedRecipeContainerViewController;
- (UIView *)presentedRecipeDetailRootView;
- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout;
- (void)spinMainRunLoop;

@end

@implementation HomeViewControllerTests

- (void)setUp {
  [super setUp];

  self.session = [[MRRAuthSession alloc] initWithUserID:@"user-1"
                                                  email:@"anne@example.com"
                                            displayName:@"Anne Cook"
                                           providerType:MRRAuthProviderTypeGoogle
                                          emailVerified:YES];
  self.dataProvider = [[HomeMockDataProvider alloc] init];
  self.viewController = [[HomeViewController alloc] initWithSession:self.session dataProvider:self.dataProvider];
  self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  [self.navigationController loadViewIfNeeded];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  self.window.hidden = YES;
  self.window = nil;
  self.navigationController = nil;
  self.viewController = nil;
  self.dataProvider = nil;
  self.session = nil;

  [super tearDown];
}

- (void)testHomeStartsInLoadingState {
  XCTAssertTrue(self.viewController.isLoadingContent);
  UIView *loadingStateView = [self findViewWithAccessibilityIdentifier:@"home.loadingStateView" inView:self.viewController.view];
  XCTAssertNotNil(loadingStateView);
  XCTAssertFalse(loadingStateView.hidden);
}

- (void)testHomeExposesPrimaryAccessibilityIdentifiersAfterLoad {
  [self finishInitialLoadIfNeeded];

  NSArray<NSString *> *identifiers = @[
    @"home.view", @"home.greetingLabel", @"home.headlineLabel", @"home.avatarButton", @"home.searchContainerView",
    @"home.searchTextField", @"home.filterButton", @"home.categories.collectionView", @"home.recommendation.collectionView",
    @"home.weekly.collectionView"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }
}

- (void)testHomeGreetingUsesAuthenticatedDisplayName {
  UILabel *greetingLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"home.greetingLabel" inView:self.viewController.view];
  XCTAssertNotNil(greetingLabel);
  XCTAssertEqualObjects(greetingLabel.text, @"Hello, Anne Cook");
}

- (void)testSelectingDinnerCategoryFiltersRecommendations {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *dinnerIndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
  [self.viewController collectionView:self.viewController.categoryCollectionView didSelectItemAtIndexPath:dinnerIndexPath];

  XCTAssertEqualObjects(self.viewController.selectedCategory.identifier, HomeCategoryIdentifierDinner);
  XCTAssertGreaterThan(self.viewController.filteredRecommendationRecipes.count, 0);
  for (HomeRecipeCard *recipeCard in self.viewController.filteredRecommendationRecipes) {
    BOOL isDinnerRecipe = [recipeCard.mealType isEqualToString:HomeCategoryIdentifierDinner] || [recipeCard.tags containsObject:@"Dinner"];
    XCTAssertTrue(isDinnerRecipe);
  }
}

- (void)testSelectingDessertCategoryShowsEmptyState {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *dessertIndexPath = [NSIndexPath indexPathForItem:3 inSection:0];
  [self.viewController collectionView:self.viewController.categoryCollectionView didSelectItemAtIndexPath:dessertIndexPath];

  XCTAssertEqual(self.viewController.filteredRecommendationRecipes.count, 0);
  XCTAssertFalse(self.viewController.recommendationEmptyStateLabel.hidden);
}

- (void)testSearchQueryShowsSearchResultsAndHidesRails {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"salad";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:1.0];

  XCTAssertFalse(self.viewController.searchResultsSectionView.hidden);
  XCTAssertTrue(self.viewController.recommendationSectionView.hidden);
  XCTAssertTrue(self.viewController.weeklySectionView.hidden);
  XCTAssertGreaterThan(self.viewController.currentSearchResults.count, 0);
}

- (void)testSearchQueryWithNoMatchesShowsEmptyState {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"brownie";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateEmpty;
  } timeout:1.0];

  XCTAssertFalse(self.viewController.searchResultsSectionView.hidden);
  XCTAssertFalse(self.viewController.searchEmptyStateLabel.hidden);
}

- (void)testSearchReturnUsesLatestQueryResultsAfterDebounceWindow {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"a";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:1.0];

  XCTAssertGreaterThan(self.viewController.currentSearchResults.count, 1);

  self.viewController.searchTextField.text = @"salad";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self.viewController textFieldShouldReturn:self.viewController.searchTextField];
  [self spinMainRunLoop];

  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[HomeRecipeListViewController class]]);

  HomeRecipeListViewController *presentedList = (HomeRecipeListViewController *)self.navigationController.topViewController;
  XCTAssertEqualObjects(presentedList.title, @"Search Results");
  XCTAssertEqual(presentedList.recipes.count, 1U);
  XCTAssertEqualObjects(presentedList.recipes.firstObject.title, @"Greek Salad");
}

- (void)testChangingSearchFilterReordersVisibleResults {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"a";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:1.0];

  NSArray<NSString *> *initialTitles = [self titlesForRecipes:self.viewController.currentSearchResults];
  XCTAssertGreaterThan(initialTitles.count, 2U);

  [self.viewController applyFilterOption:HomeFilterOptionLowCalorie];

  NSArray<HomeRecipeCard *> *expectedRecipes =
      [[self.dataProvider searchRecipes:@"a"] sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.calorieCount == right.calorieCount) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.calorieCount < right.calorieCount ? NSOrderedAscending : NSOrderedDescending;
      }];

  XCTAssertEqualObjects([self titlesForRecipes:self.viewController.currentSearchResults], [self titlesForRecipes:expectedRecipes]);
}

- (void)testRecipeListViewControllerSizesCardsToFitContent {
  NSArray<HomeRecipeCard *> *recipes = [self.dataProvider searchRecipes:@"a"];
  HomeRecipeListViewController *listViewController =
      [[HomeRecipeListViewController alloc] initWithScreenTitle:@"Search Results"
                                                        recipes:recipes
                                                   emptyMessage:@"No recipes match that search yet."];

  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:listViewController];
  window.rootViewController = navigationController;
  [window makeKeyAndVisible];
  [navigationController loadViewIfNeeded];
  [listViewController loadViewIfNeeded];
  [listViewController.view layoutIfNeeded];

  CGSize itemSize = [listViewController collectionView:listViewController.collectionView
                                layout:listViewController.collectionView.collectionViewLayout
                 sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];

  NSArray<NSString *> *introIdentifiers = @[
    @"home.recipeList.introCardView", @"home.recipeList.eyebrowLabel", @"home.recipeList.titleLabel",
    @"home.recipeList.summaryLabel", @"home.recipeList.countBadgeLabel"
  ];
  for (NSString *identifier in introIdentifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:listViewController.view], @"Missing %@", identifier);
  }

  XCTAssertEqualObjects(listViewController.collectionView.accessibilityLabel, @"Search Results");
  XCTAssertEqualWithAccuracy(listViewController.collectionView.contentInset.top, 4.0, 0.001);
  XCTAssertTrue(listViewController.emptyStateLabel.hidden);
  XCTAssertTrue(listViewController.emptyStateLabel.isAccessibilityElement);
  XCTAssertGreaterThanOrEqual(itemSize.height, 340.0);
  XCTAssertGreaterThan(itemSize.width, 200.0);

  window.hidden = YES;
}

- (void)testFilterButtonPresentsActionSheet {
  [self finishInitialLoadIfNeeded];

  [self.viewController.filterButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"home.filterActionSheet");
}

- (void)testSeeAllPushesRecipeListScreen {
  [self finishInitialLoadIfNeeded];

  UIButton *seeAllButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"home.recommendationHeader.seeAllButton" inView:self.viewController.view];
  XCTAssertNotNil(seeAllButton);

  [seeAllButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[HomeRecipeListViewController class]]);
  XCTAssertEqualObjects(self.navigationController.topViewController.view.accessibilityIdentifier, @"home.recipeList.view");
}

- (void)testSelectingRecommendationRecipePresentsDetailView {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.recommendationCollectionView didSelectItemAtIndexPath:firstIndexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil([self presentedRecipeContainerViewController]);
  XCTAssertEqualObjects([self presentedRecipeDetailRootView].accessibilityIdentifier, @"onboarding.recipeDetail.view");
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

- (void)finishInitialLoadIfNeeded {
  [self waitForCondition:^BOOL {
    return !self.viewController.isLoadingContent;
  } timeout:1.2];
}

- (UIViewController *)presentedRecipeContainerViewController {
  return self.viewController.presentedViewController;
}

- (UIView *)presentedRecipeDetailRootView {
  UIViewController *presentedViewController = [self presentedRecipeContainerViewController];
  if ([presentedViewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController = (UINavigationController *)presentedViewController;
    return navigationController.topViewController.view;
  }
  return presentedViewController.view;
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

- (NSArray<NSString *> *)titlesForRecipes:(NSArray<HomeRecipeCard *> *)recipes {
  NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:recipes.count];
  for (HomeRecipeCard *recipe in recipes) {
    [titles addObject:recipe.title ?: @""];
  }
  return titles;
}

@end
