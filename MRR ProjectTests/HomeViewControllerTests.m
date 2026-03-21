#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Features/Home/HomeCollectionViewCells.h"
#import "../MRR Project/Features/Home/HomeDataSource.h"
#import "../MRR Project/Features/Home/HomeRecipeListViewController.h"
#import "../MRR Project/Features/Home/HomeViewController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"

@class HomeAsyncTestDataProvider;

@interface HomeViewController (Testing) <UICollectionViewDelegate>

@property(nonatomic, readonly) UITextField *searchTextField;
@property(nonatomic, readonly) UIButton *filterButton;
@property(nonatomic, readonly) UIView *activeFiltersContainerView;
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
@property(nonatomic, readonly) NSArray<HomeRecipeCard *> *allSearchResults;
@property(nonatomic, readonly, nullable) NSString *lastCompletedSearchQuery;
@property(nonatomic, readonly, nullable) HomeCategory *selectedCategory;
@property(nonatomic, assign) HomeFilterOption currentFilterOption;
@property(nonatomic, assign) HomeSearchState searchState;
@property(nonatomic, readonly, getter=isLoadingContent) BOOL loadingContent;
@property(nonatomic, readonly) UIView *poweredByContainerView;
@property(nonatomic, assign) BOOL displayingLiveContent;
- (void)applyFilterOption:(HomeFilterOption)filterOption;
- (void)applyAdvancedFilters:(HomeAdvancedFilterSettings *)advancedFilters;
- (BOOL)textFieldShouldReturn:(UITextField *)textField;
- (void)executeSearchForQuery:(NSString *)query resultLimit:(NSUInteger)resultLimit presentingResultsList:(BOOL)presentResultsList;

@end

@interface HomeRecipeCardCell (Testing)

@property(nonatomic, readonly) UIImageView *heroImageView;

@end

@interface HomeRecipeListViewController (Testing)

@property(nonatomic, readonly) UICollectionView *collectionView;
@property(nonatomic, readonly) UILabel *emptyStateLabel;
@property(nonatomic, readonly) NSArray<HomeRecipeCard *> *recipes;
@property(nonatomic, readonly) UIButton *compactDropdownButton;
@property(nonatomic, readonly) UIView *introCardSurfaceView;
@property(nonatomic, readonly) UIStackView *expandedIntroStackView;
@property(nonatomic, readonly) BOOL introCompact;
@property(nonatomic, readonly) BOOL introDropdownExpanded;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

@end

@interface HomeViewControllerTests : XCTestCase

@property(nonatomic, strong) MRRAuthSession *session;
@property(nonatomic, strong) HomeAsyncTestDataProvider *dataProvider;
@property(nonatomic, strong) HomeViewController *viewController;
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (void)finishInitialLoadIfNeeded;
- (UIViewController *)presentedRecipeContainerViewController;
- (UIView *)presentedRecipeDetailRootView;
- (NSArray<HomeRecipeCard *> *)weeklyRecipes;
- (NSArray<HomeRecipeCard *> *)recommendationRecipes;
- (NSArray<HomeRecipeCard *> *)testRecipeCardsWithPrefix:(NSString *)prefix count:(NSUInteger)count mealType:(NSString *)mealType;
- (OnboardingRecipeDetail *)testRecipeDetailWithTitle:(NSString *)title assetName:(NSString *)assetName;
- (HomeRecipeListViewController *)mountedRecipeListViewControllerWithTitle:(NSString *)title
                                                                   recipes:(NSArray<HomeRecipeCard *> *)recipes
                                                              emptyMessage:(NSString *)emptyMessage
                                                                    window:(UIWindow * __strong *)window
                                                      navigationController:(UINavigationController * __strong *)navigationController;
- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout;
- (void)spinMainRunLoop;

@end

@interface HomeAsyncTestDataProvider : HomeMockDataProvider

@property(nonatomic, assign) NSTimeInterval initialDelay;
@property(nonatomic, assign) NSTimeInterval searchDelay;
@property(nonatomic, assign) NSTimeInterval detailDelay;
@property(nonatomic, assign) BOOL initialUsesLiveData;
@property(nonatomic, assign) BOOL searchUsesLiveData;
@property(nonatomic, assign) BOOL detailUsesLiveData;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *searchResultsByQuery;
@property(nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSNumber *, NSArray<HomeRecipeCard *> *> *> *searchResultsByQueryAndFilterOption;
@property(nonatomic, copy) NSDictionary<NSString *, NSNumber *> *searchDelayByQuery;
@property(nonatomic, copy) NSDictionary<NSString *, OnboardingRecipeDetail *> *detailByRecipeID;
@property(nonatomic, copy) NSArray<HomeSection *> *initialSectionsOverride;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *initialRecipesByCategoryIdentifierOverride;
@property(nonatomic, retain) NSMutableArray<NSDictionary<NSString *, id> *> *initialRequests;
@property(nonatomic, retain) NSMutableArray<NSDictionary<NSString *, id> *> *searchRequests;
@property(nonatomic, retain) NSMutableArray<NSString *> *detailRequests;

@end

@implementation HomeAsyncTestDataProvider

- (instancetype)init {
  self = [super init];
  if (self) {
    _initialDelay = 0.01;
    _searchDelay = 0.01;
    _detailDelay = 0.01;
    _initialUsesLiveData = YES;
    _searchUsesLiveData = YES;
    _detailUsesLiveData = YES;
    _initialRequests = [[NSMutableArray alloc] init];
    _searchRequests = [[NSMutableArray alloc] init];
    _detailRequests = [[NSMutableArray alloc] init];
  }

  return self;
}

- (NSArray<HomeRecipeCard *> *)sortedRecipes:(NSArray<HomeRecipeCard *> *)recipes forFilterOption:(HomeFilterOption)filterOption {
  if (recipes.count < 2) {
    return recipes ?: @[];
  }

  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return recipes;
    case HomeFilterOptionFastest:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.readyInMinutes == right.readyInMinutes) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.readyInMinutes < right.readyInMinutes ? NSOrderedAscending : NSOrderedDescending;
      }];
    case HomeFilterOptionPopular:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.popularityScore == right.popularityScore) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.popularityScore > right.popularityScore ? NSOrderedAscending : NSOrderedDescending;
      }];
    case HomeFilterOptionLowCalorie:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.calorieCount == right.calorieCount) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.calorieCount < right.calorieCount ? NSOrderedAscending : NSOrderedDescending;
      }];
  }
}

- (NSArray<HomeRecipeCard *> *)recipes:(NSArray<HomeRecipeCard *> *)recipes filteredForAdvancedFilters:(HomeAdvancedFilterSettings *)advancedFilters {
  if (recipes.count == 0 || advancedFilters == nil || ![advancedFilters hasActiveFilters]) {
    return recipes ?: @[];
  }

  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HomeRecipeCard *recipeCard, NSDictionary<NSString *, id> *bindings) {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObjects:
        recipeCard.title ?: @"",
        recipeCard.subtitle ?: @"",
        recipeCard.summaryText ?: @"",
        recipeCard.mealType ?: @"",
        nil];
    [parts addObjectsFromArray:recipeCard.tags ?: @[]];
    NSString *joinedText = [[parts componentsJoinedByString:@" "] lowercaseString];

    if (advancedFilters.maxReadyTime > 0 && recipeCard.readyInMinutes > advancedFilters.maxReadyTime) {
      return NO;
    }
    if (advancedFilters.cuisine.length > 0 && ![joinedText containsString:advancedFilters.cuisine.lowercaseString]) {
      return NO;
    }
    if (advancedFilters.diet.length > 0 && ![joinedText containsString:advancedFilters.diet.lowercaseString]) {
      return NO;
    }
    if (advancedFilters.intolerances.length > 0) {
      NSString *term = advancedFilters.intolerances.lowercaseString;
      BOOL matchesIntolerance = [joinedText containsString:[NSString stringWithFormat:@"%@ free", term]] ||
                                [joinedText containsString:[NSString stringWithFormat:@"%@-free", term]] ||
                                [joinedText containsString:[NSString stringWithFormat:@"no %@", term]];
      if (!matchesIntolerance) {
        return NO;
      }
    }
    if (advancedFilters.includeIngredients.length > 0 && ![joinedText containsString:advancedFilters.includeIngredients.lowercaseString]) {
      return NO;
    }
    if (advancedFilters.excludeIngredients.length > 0 && [joinedText containsString:advancedFilters.excludeIngredients.lowercaseString]) {
      return NO;
    }
    if (advancedFilters.equipment.length > 0 && ![joinedText containsString:advancedFilters.equipment.lowercaseString]) {
      return NO;
    }
    return YES;
  }];
  return [recipes filteredArrayUsingPredicate:predicate];
}

- (NSArray<HomeSection *> *)sectionsForFilterOption:(HomeFilterOption)filterOption advancedFilters:(HomeAdvancedFilterSettings *)advancedFilters {
  NSArray<HomeSection *> *sections = self.initialSectionsOverride ?: [self featuredSections];
  NSMutableArray<HomeSection *> *filteredSections = [NSMutableArray arrayWithCapacity:sections.count];
  for (HomeSection *section in sections) {
    NSArray<HomeRecipeCard *> *filteredRecipes = [self recipes:section.recipes filteredForAdvancedFilters:advancedFilters];
    [filteredSections addObject:[[HomeSection alloc] initWithIdentifier:section.identifier
                                                                  title:section.title
                                                                recipes:[self sortedRecipes:filteredRecipes forFilterOption:filterOption]]];
  }
  return filteredSections;
}

- (NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *)recipesByCategoryIdentifierForFilterOption:(HomeFilterOption)filterOption
                                                                                 advancedFilters:(HomeAdvancedFilterSettings *)advancedFilters {
  NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier = self.initialRecipesByCategoryIdentifierOverride;
  if (recipesByCategoryIdentifier == nil) {
    NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *derivedRecipesByCategoryIdentifier =
        [NSMutableDictionary dictionary];
    for (HomeCategory *category in [self availableCategories]) {
      NSArray<HomeRecipeCard *> *recipes = [self recipesForCategory:category] ?: @[];
      recipes = [self recipes:recipes filteredForAdvancedFilters:advancedFilters];
      [derivedRecipesByCategoryIdentifier setObject:[self sortedRecipes:recipes forFilterOption:filterOption]
                                             forKey:category.identifier];
    }
    recipesByCategoryIdentifier = derivedRecipesByCategoryIdentifier;
  } else {
    NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *filteredRecipesByCategoryIdentifier =
        [NSMutableDictionary dictionaryWithCapacity:recipesByCategoryIdentifier.count];
    [recipesByCategoryIdentifier enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                                                     NSArray<HomeRecipeCard *> *recipes,
                                                                     BOOL *stop) {
      recipes = [self recipes:recipes filteredForAdvancedFilters:advancedFilters];
      [filteredRecipesByCategoryIdentifier setObject:[self sortedRecipes:recipes forFilterOption:filterOption]
                                              forKey:key];
    }];
    recipesByCategoryIdentifier = filteredRecipesByCategoryIdentifier;
  }

  return recipesByCategoryIdentifier;
}

- (void)loadInitialSectionsForFilterOption:(HomeFilterOption)filterOption completion:(HomeInitialSectionsCompletion)completion {
  [self loadInitialSectionsForFilterOption:filterOption advancedFilters:nil completion:completion];
}

- (void)loadInitialSectionsForFilterOption:(HomeFilterOption)filterOption
                           advancedFilters:(HomeAdvancedFilterSettings *)advancedFilters
                                completion:(HomeInitialSectionsCompletion)completion {
  if (completion == nil) {
    return;
  }

  [self.initialRequests addObject:@{
    @"filterOption" : @(filterOption),
    @"advancedFilters" : advancedFilters ?: [HomeAdvancedFilterSettings emptySettings]
  }];
  NSArray<HomeSection *> *sections = [self sectionsForFilterOption:filterOption advancedFilters:advancedFilters];
  NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier =
      [self recipesByCategoryIdentifierForFilterOption:filterOption advancedFilters:advancedFilters];
  BOOL usesLiveData = self.initialUsesLiveData;
  NSTimeInterval delay = MAX(self.initialDelay, 0.0);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    completion(sections, recipesByCategoryIdentifier, usesLiveData);
  });
}

- (void)loadInitialSectionsWithCompletion:(HomeInitialSectionsCompletion)completion {
  [self loadInitialSectionsForFilterOption:HomeFilterOptionFeatured advancedFilters:nil completion:completion];
}

- (void)searchRecipes:(NSString *)query
                limit:(NSUInteger)limit
         filterOption:(HomeFilterOption)filterOption
      advancedFilters:(HomeAdvancedFilterSettings *)advancedFilters
           completion:(HomeRecipeSearchCompletion)completion {
  if (completion == nil) {
    return;
  }

  NSString *trimmedQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trimmedQuery.length == 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(self.searchDelay, 0.0) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     completion(@[], self.searchUsesLiveData);
                   });
    return;
  }

  NSDictionary<NSNumber *, NSArray<HomeRecipeCard *> *> *recipesByFilterOption =
      [self.searchResultsByQueryAndFilterOption objectForKey:trimmedQuery];
  NSArray<HomeRecipeCard *> *recipes = [recipesByFilterOption objectForKey:@(filterOption)];
  if (recipes == nil) {
    recipes = [self.searchResultsByQuery objectForKey:trimmedQuery];
    recipes = [self sortedRecipes:recipes ?: [self searchRecipes:trimmedQuery] forFilterOption:filterOption];
  }
  recipes = [self recipes:recipes filteredForAdvancedFilters:advancedFilters];
  if (limit > 0 && recipes.count > limit) {
    recipes = [recipes subarrayWithRange:NSMakeRange(0, limit)];
  }

  NSNumber *overrideDelay = [self.searchDelayByQuery objectForKey:trimmedQuery];
  NSTimeInterval delay = overrideDelay != nil ? overrideDelay.doubleValue : self.searchDelay;
  [self.searchRequests addObject:@{
    @"query" : trimmedQuery,
    @"limit" : @(limit),
    @"filterOption" : @(filterOption),
    @"advancedFilters" : advancedFilters ?: [HomeAdvancedFilterSettings emptySettings]
  }];
  BOOL usesLiveData = self.searchUsesLiveData;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(delay, 0.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    completion(recipes ?: @[], usesLiveData);
  });
}

- (void)searchRecipes:(NSString *)query limit:(NSUInteger)limit completion:(HomeRecipeSearchCompletion)completion {
  [self searchRecipes:query limit:limit filterOption:HomeFilterOptionFeatured advancedFilters:nil completion:completion];
}

- (void)loadRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard completion:(HomeRecipeDetailCompletion)completion {
  if (completion == nil || recipeCard == nil) {
    return;
  }

  OnboardingRecipeDetail *detail = [self.detailByRecipeID objectForKey:recipeCard.recipeID];
  if (detail == nil) {
    detail = [self recipeDetailForID:recipeCard.recipeID];
  }

  [self.detailRequests addObject:recipeCard.recipeID ?: @""];
  BOOL usesLiveData = self.detailUsesLiveData;
  NSTimeInterval delay = MAX(self.detailDelay, 0.0);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    completion(detail, usesLiveData);
  });
}

@end

static HomeRecipeCard *MRRTestHomeRecipeCard(NSString *recipeID,
                                             NSString *title,
                                             NSString *subtitle,
                                             NSString *assetName,
                                             NSString *summaryText,
                                             NSInteger readyInMinutes,
                                             NSInteger servings,
                                             NSInteger calorieCount,
                                             NSInteger popularityScore,
                                             NSString *sourceName,
                                             NSString *mealType,
                                             NSArray<NSString *> *tags) {
  return [[HomeRecipeCard alloc] initWithRecipeID:recipeID
                                            title:title
                                         subtitle:subtitle
                                        assetName:assetName
                                   imageURLString:nil
                                      summaryText:summaryText
                                   readyInMinutes:readyInMinutes
                                         servings:servings
                                     calorieCount:calorieCount
                                  popularityScore:popularityScore
                                       sourceName:sourceName
                                  sourceURLString:nil
                                         mealType:mealType
                                             tags:tags];
}

static NSArray<HomeRecipeCard *> *MRRTestHomeRecipeCardsWithPrefix(NSString *prefix, NSUInteger count, NSString *mealType) {
  NSMutableArray<HomeRecipeCard *> *cards = [NSMutableArray arrayWithCapacity:count];
  NSArray<NSNumber *> *calories = @[@(540), @(160), @(310), @(220), @(480), @(180), @(260), @(620), @(140), @(390), @(200), @(450), @(170), @(300), @(240)];
  for (NSUInteger index = 0; index < count; index += 1) {
    NSInteger calorieCount = [[calories objectAtIndex:(index % calories.count)] integerValue];
    NSString *title = [NSString stringWithFormat:@"%@ %02lu", prefix, (unsigned long)index + 1];
    NSString *recipeID = [NSString stringWithFormat:@"test.%@.%02lu", prefix.lowercaseString, (unsigned long)index + 1];
    NSString *summary = [NSString stringWithFormat:@"%@ recipe number %02lu keeps the Home search and sorting states busy.", prefix, (unsigned long)index + 1];
    [cards addObject:MRRTestHomeRecipeCard(recipeID,
                                           title,
                                           [NSString stringWithFormat:@"%@ preview", prefix],
                                           @"avocado-toast",
                                           summary,
                                           10 + (NSInteger)(index % 25),
                                           1 + (NSInteger)(index % 4),
                                           calorieCount,
                                           100 - (NSInteger)index,
                                           @"Culina Test Kitchen",
                                           mealType,
                                           @[ prefix, @"Test", mealType ])];
  }

  return cards;
}

static OnboardingRecipeDetail *MRRTestHomeRecipeDetail(NSString *title, NSString *assetName) {
  OnboardingRecipeIngredient *ingredient =
      [[OnboardingRecipeIngredient alloc] initWithName:@"Test Ingredient" displayText:@"1 cup test ingredient"];
  OnboardingRecipeInstruction *instruction =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 1" detailText:@"Stir and serve."];
  return [[OnboardingRecipeDetail alloc] initWithTitle:title
                                              subtitle:[NSString stringWithFormat:@"%@ subtitle", title]
                                             assetName:assetName
                                    heroImageURLString:nil
                                          durationText:@"20 min"
                                           calorieText:@"320 kcal"
                                          servingsText:@"2 servings"
                                           summaryText:[NSString stringWithFormat:@"%@ summary", title]
                                           ingredients:@[ ingredient ]
                                          instructions:@[ instruction ]
                                                 tools:@[]
                                                  tags:@[ @"Test" ]
                                            sourceName:@"Culina Test Kitchen"
                                       sourceURLString:nil
                                        productContext:nil];
}

@implementation HomeViewControllerTests

- (void)setUp {
  [super setUp];

  self.session = [[MRRAuthSession alloc] initWithUserID:@"user-1"
                                                  email:@"anne@example.com"
                                            displayName:@"Anne Cook"
                                           providerType:MRRAuthProviderTypeGoogle
                                          emailVerified:YES];
  HomeAsyncTestDataProvider *dataProvider = [[HomeAsyncTestDataProvider alloc] init];
  dataProvider.searchResultsByQuery = @{
    @"salad" : MRRTestHomeRecipeCardsWithPrefix(@"Salad", 14, HomeCategoryIdentifierLunch),
    @"soup" : MRRTestHomeRecipeCardsWithPrefix(@"Soup", 4, HomeCategoryIdentifierDinner),
    @"berry" : MRRTestHomeRecipeCardsWithPrefix(@"Berry", 2, HomeCategoryIdentifierDessert),
    @"curry" : MRRTestHomeRecipeCardsWithPrefix(@"Curry", 14, HomeCategoryIdentifierDinner)
  };
  dataProvider.searchResultsByQueryAndFilterOption = @{
    @"curry" : @{
      @(HomeFilterOptionFeatured) : MRRTestHomeRecipeCardsWithPrefix(@"Curry", 4, HomeCategoryIdentifierDinner),
      @(HomeFilterOptionLowCalorie) : @[
        MRRTestHomeRecipeCard(@"test.curry.lowcal.01",
                              @"Curry 01",
                              @"Curry preview",
                              @"avocado-toast",
                              @"Curry low-calorie recipe number 01 keeps the refetch path visible.",
                              18,
                              2,
                              140,
                              99,
                              @"Culina Test Kitchen",
                              HomeCategoryIdentifierDinner,
                              @[ @"Curry", @"Test", HomeCategoryIdentifierDinner ]),
        MRRTestHomeRecipeCard(@"test.curry.lowcal.02",
                              @"Curry 02",
                              @"Curry preview",
                              @"avocado-toast",
                              @"Curry low-calorie recipe number 02 keeps the refetch path visible.",
                              22,
                              2,
                              180,
                              98,
                              @"Culina Test Kitchen",
                              HomeCategoryIdentifierDinner,
                              @[ @"Curry", @"Test", HomeCategoryIdentifierDinner ])
      ]
    }
  };
  dataProvider.searchDelayByQuery = @{
    @"salad" : @(0.16),
    @"soup" : @(0.02),
    @"berry" : @(0.01),
    @"curry" : @(0.01)
  };
  dataProvider.detailByRecipeID = @{
    @"home.pastaCarbonara" : MRRTestHomeRecipeDetail(@"Pasta Carbonara, Hydrated", @"pasta-carbonara")
  };
  self.dataProvider = dataProvider;
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

- (void)testInitialAsyncLoadShowsLiveContentAndPoweredByAttribution {
  [self finishInitialLoadIfNeeded];

  XCTAssertFalse(self.viewController.isLoadingContent);
  XCTAssertTrue(self.viewController.displayingLiveContent);
  XCTAssertFalse(self.viewController.poweredByContainerView.hidden);
  XCTAssertEqual(self.dataProvider.initialRequests.count, 1U);
  XCTAssertEqualObjects([[self.dataProvider.initialRequests firstObject] objectForKey:@"filterOption"], @(HomeFilterOptionFeatured));
}

- (void)testChangingFilterReloadsLiveHomeSections {
  [self finishInitialLoadIfNeeded];

  self.dataProvider.initialDelay = 0.12;
  NSUInteger initialRequestCount = self.dataProvider.initialRequests.count;
  [self.viewController applyFilterOption:HomeFilterOptionFastest];
  XCTAssertFalse(self.viewController.filterButton.enabled);
  [self waitForCondition:^BOOL {
    return self.dataProvider.initialRequests.count == initialRequestCount + 1;
  } timeout:1.2];
  [self waitForCondition:^BOOL {
    return self.viewController.filterButton.enabled;
  } timeout:1.2];

  XCTAssertEqual(self.dataProvider.initialRequests.count, initialRequestCount + 1);
  XCTAssertEqualObjects([[self.dataProvider.initialRequests lastObject] objectForKey:@"filterOption"], @(HomeFilterOptionFastest));
}

- (void)testApplyingAdvancedFiltersReloadsHomeSectionsAndShowsSummary {
  [self finishInitialLoadIfNeeded];

  self.dataProvider.initialDelay = 0.12;
  NSUInteger initialRequestCount = self.dataProvider.initialRequests.count;
  HomeAdvancedFilterSettings *advancedFilters =
      [[HomeAdvancedFilterSettings alloc] initWithCuisine:@"Italian"
                                                     diet:nil
                                             intolerances:nil
                                       includeIngredients:nil
                                       excludeIngredients:nil
                                                equipment:nil
                                             maxReadyTime:30];

  [self.viewController applyAdvancedFilters:advancedFilters];
  XCTAssertFalse(self.viewController.activeFiltersContainerView.hidden);
  [self waitForCondition:^BOOL {
    return self.dataProvider.initialRequests.count == initialRequestCount + 1;
  } timeout:1.2];
  [self waitForCondition:^BOOL {
    return self.viewController.filterButton.enabled;
  } timeout:1.2];

  NSDictionary<NSString *, id> *lastRequest = [self.dataProvider.initialRequests lastObject];
  HomeAdvancedFilterSettings *capturedFilters = [lastRequest objectForKey:@"advancedFilters"];

  XCTAssertEqualObjects(capturedFilters.cuisine, @"Italian");
  XCTAssertEqual(capturedFilters.maxReadyTime, 30);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"home.activeFilters.chip.1" inView:self.viewController.view]);
  XCTAssertTrue([[self titlesForRecipes:self.viewController.filteredRecommendationRecipes] containsObject:@"Pasta Carbonara"]);
}

- (void)testFallbackInitialLoadKeepsPoweredByHidden {
  HomeAsyncTestDataProvider *fallbackProvider = [[HomeAsyncTestDataProvider alloc] init];
  fallbackProvider.initialUsesLiveData = NO;

  HomeViewController *fallbackViewController = [[HomeViewController alloc] initWithSession:self.session
                                                                               dataProvider:fallbackProvider];
  UINavigationController *fallbackNavigationController =
      [[UINavigationController alloc] initWithRootViewController:fallbackViewController];
  UIWindow *fallbackWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  fallbackWindow.rootViewController = fallbackNavigationController;
  [fallbackWindow makeKeyAndVisible];
  [fallbackNavigationController loadViewIfNeeded];
  [fallbackViewController loadViewIfNeeded];
  [fallbackViewController.view layoutIfNeeded];

  [self waitForCondition:^BOOL {
    return !fallbackViewController.isLoadingContent;
  } timeout:1.2];

  XCTAssertFalse(fallbackViewController.displayingLiveContent);
  XCTAssertTrue(fallbackViewController.poweredByContainerView.hidden);
  XCTAssertFalse(fallbackViewController.isLoadingContent);

  fallbackWindow.hidden = YES;
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

- (void)testHomeHidesNavigationBarWhileVisible {
  [self.viewController viewWillAppear:NO];
  XCTAssertTrue(self.navigationController.isNavigationBarHidden);

  [self.viewController viewWillDisappear:NO];
  XCTAssertFalse(self.navigationController.isNavigationBarHidden);
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
  XCTAssertEqual(self.viewController.currentSearchResults.count, 3U);
  XCTAssertEqual([self.viewController.searchResultsCollectionView numberOfItemsInSection:0], 3U);
  XCTAssertEqualObjects(self.viewController.lastCompletedSearchQuery, @"salad");
  XCTAssertEqual(self.dataProvider.searchRequests.count, 1U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests firstObject] objectForKey:@"query"], @"salad");
  XCTAssertEqual([[[self.dataProvider.searchRequests firstObject] objectForKey:@"limit"] unsignedIntegerValue], 3U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests firstObject] objectForKey:@"filterOption"], @(HomeFilterOptionFeatured));
}

- (void)testSearchQueryWithNoMatchesShowsEmptyState {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"berry tart";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateEmpty;
  } timeout:1.0];

  XCTAssertFalse(self.viewController.searchResultsSectionView.hidden);
  XCTAssertFalse(self.viewController.searchEmptyStateLabel.hidden);
}

- (void)testSearchReturnUsesLatestQueryResultsAfterDebounceWindow {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"salad";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:2.0];

  [self.viewController textFieldShouldReturn:self.viewController.searchTextField];
  [self waitForCondition:^BOOL {
    return [self.navigationController.topViewController isKindOfClass:[HomeRecipeListViewController class]];
  } timeout:1.0];

  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[HomeRecipeListViewController class]]);

  HomeRecipeListViewController *presentedList = (HomeRecipeListViewController *)self.navigationController.topViewController;
  [presentedList loadViewIfNeeded];
  [presentedList.view layoutIfNeeded];
  XCTAssertEqualObjects(presentedList.title, @"Search Results");
  XCTAssertEqual(presentedList.recipes.count, 12U);
  XCTAssertEqual(self.dataProvider.searchRequests.count, 2U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"query"], @"salad");
  XCTAssertEqual([[[self.dataProvider.searchRequests lastObject] objectForKey:@"limit"] unsignedIntegerValue], 12U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"filterOption"], @(HomeFilterOptionFeatured));
}

- (void)testChangingSearchFilterRefetchesVisibleResultsWithSelectedOption {
  [self finishInitialLoadIfNeeded];

  NSMutableDictionary<NSString *, NSNumber *> *searchDelayByQuery =
      [NSMutableDictionary dictionaryWithDictionary:self.dataProvider.searchDelayByQuery ?: @{}];
  [searchDelayByQuery setObject:@(0.12) forKey:@"curry"];
  self.dataProvider.searchDelayByQuery = searchDelayByQuery;

  self.viewController.searchTextField.text = @"curry";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:2.0];

  NSUInteger requestCountBeforeFilter = self.dataProvider.searchRequests.count;

  [self.viewController applyFilterOption:HomeFilterOptionLowCalorie];
  XCTAssertFalse(self.viewController.filterButton.enabled);
  [self waitForCondition:^BOOL {
    return self.dataProvider.searchRequests.count == requestCountBeforeFilter + 1;
  } timeout:1.0];
  [self waitForCondition:^BOOL {
    return [self.viewController.lastCompletedSearchQuery isEqualToString:@"curry"] &&
           self.viewController.currentSearchResults.count == 2U;
  } timeout:1.0];
  [self waitForCondition:^BOOL {
    return self.viewController.filterButton.enabled;
  } timeout:1.0];

  XCTAssertEqual(self.dataProvider.searchRequests.count, requestCountBeforeFilter + 1);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"query"], @"curry");
  XCTAssertEqual([[[self.dataProvider.searchRequests lastObject] objectForKey:@"limit"] unsignedIntegerValue], 3U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"filterOption"], @(HomeFilterOptionLowCalorie));
  XCTAssertEqual(self.viewController.currentSearchResults.count, 2U);
  XCTAssertEqualObjects([self titlesForRecipes:self.viewController.currentSearchResults], (@[ @"Curry 01", @"Curry 02" ]));
}

- (void)testApplyingAdvancedFiltersRefetchesVisibleSearchResults {
  [self finishInitialLoadIfNeeded];

  NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *searchResultsByQuery =
      [NSMutableDictionary dictionaryWithDictionary:self.dataProvider.searchResultsByQuery ?: @{}];
  [searchResultsByQuery setObject:@[
    MRRTestHomeRecipeCard(@"test.green.01",
                          @"Green Pasta",
                          @"Italian garden bowl",
                          @"avocado-toast",
                          @"Tomato basil pasta blended into a bright blender sauce.",
                          18,
                          2,
                          320,
                          98,
                          @"Culina Test Kitchen",
                          HomeCategoryIdentifierLunch,
                          @[ @"Italian", @"Vegetarian", @"Tomato", @"Blender" ]),
    MRRTestHomeRecipeCard(@"test.green.02",
                          @"Green Curry",
                          @"Comfort bowl",
                          @"green-curry",
                          @"Herby curry for a slower dinner with a stock pot.",
                          34,
                          3,
                          410,
                          94,
                          @"Culina Test Kitchen",
                          HomeCategoryIdentifierDinner,
                          @[ @"Thai", @"Curry", @"Dinner" ])
  ] forKey:@"green"];
  self.dataProvider.searchResultsByQuery = searchResultsByQuery;

  NSMutableDictionary<NSString *, NSNumber *> *searchDelayByQuery =
      [NSMutableDictionary dictionaryWithDictionary:self.dataProvider.searchDelayByQuery ?: @{}];
  [searchDelayByQuery setObject:@(0.12) forKey:@"green"];
  self.dataProvider.searchDelayByQuery = searchDelayByQuery;

  self.viewController.searchTextField.text = @"green";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:2.0];

  NSUInteger requestCountBeforeFilter = self.dataProvider.searchRequests.count;
  HomeAdvancedFilterSettings *advancedFilters =
      [[HomeAdvancedFilterSettings alloc] initWithCuisine:@"Italian"
                                                     diet:nil
                                             intolerances:nil
                                       includeIngredients:@"Tomato"
                                       excludeIngredients:nil
                                                equipment:@"Blender"
                                             maxReadyTime:20];

  [self.viewController applyAdvancedFilters:advancedFilters];
  XCTAssertFalse(self.viewController.filterButton.enabled);
  [self waitForCondition:^BOOL {
    return self.dataProvider.searchRequests.count == requestCountBeforeFilter + 1;
  } timeout:1.2];
  [self waitForCondition:^BOOL {
    return self.viewController.currentSearchResults.count == 1U;
  } timeout:1.2];
  [self waitForCondition:^BOOL {
    return self.viewController.filterButton.enabled;
  } timeout:1.2];

  NSDictionary<NSString *, id> *lastRequest = [self.dataProvider.searchRequests lastObject];
  HomeAdvancedFilterSettings *capturedFilters = [lastRequest objectForKey:@"advancedFilters"];

  XCTAssertEqualObjects(capturedFilters.cuisine, @"Italian");
  XCTAssertEqualObjects(capturedFilters.includeIngredients, @"Tomato");
  XCTAssertEqualObjects(capturedFilters.equipment, @"Blender");
  XCTAssertEqualObjects([self titlesForRecipes:self.viewController.currentSearchResults], (@[ @"Green Pasta" ]));
  XCTAssertFalse(self.viewController.activeFiltersContainerView.hidden);
}

- (void)testSearchSeeAllRequestsFullResultSetAndPushesRecipeList {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"salad";
  [self.viewController.searchTextField sendActionsForControlEvents:UIControlEventEditingChanged];
  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults;
  } timeout:2.0];

  UIButton *seeAllButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"home.searchResultsHeader.seeAllButton" inView:self.viewController.view];
  XCTAssertNotNil(seeAllButton);
  XCTAssertFalse(seeAllButton.hidden);

  [seeAllButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self waitForCondition:^BOOL {
    return [self.navigationController.topViewController isKindOfClass:[HomeRecipeListViewController class]];
  } timeout:1.2];

  XCTAssertEqual(self.dataProvider.searchRequests.count, 2U);
  XCTAssertEqual([[[self.dataProvider.searchRequests lastObject] objectForKey:@"limit"] unsignedIntegerValue], 12U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"filterOption"], @(HomeFilterOptionFeatured));

  HomeRecipeListViewController *presentedList = (HomeRecipeListViewController *)self.navigationController.topViewController;
  [presentedList loadViewIfNeeded];
  [presentedList.view layoutIfNeeded];
  XCTAssertEqualObjects(presentedList.view.accessibilityIdentifier, @"home.recipeList.view");
  XCTAssertEqual(presentedList.recipes.count, 12U);
}

- (void)testStaleSearchResponseIsIgnored {
  [self finishInitialLoadIfNeeded];

  self.viewController.searchTextField.text = @"salad";
  [self.viewController executeSearchForQuery:@"salad" resultLimit:12 presentingResultsList:NO];
  self.viewController.searchTextField.text = @"soup";
  [self.viewController executeSearchForQuery:@"soup" resultLimit:12 presentingResultsList:NO];

  [self waitForCondition:^BOOL {
    return self.viewController.searchState == HomeSearchStateResults &&
           [self.viewController.lastCompletedSearchQuery isEqualToString:@"soup"];
  } timeout:1.0];

  XCTAssertEqualObjects(self.viewController.lastCompletedSearchQuery, @"soup");
  XCTAssertEqualObjects([[self titlesForRecipes:self.viewController.currentSearchResults] firstObject], @"Soup 01");
  XCTAssertEqual(self.dataProvider.searchRequests.count, 2U);
  XCTAssertEqualObjects([[self.dataProvider.searchRequests lastObject] objectForKey:@"filterOption"], @(HomeFilterOptionFeatured));
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

- (void)testWeeklyRecipeListCompactsIntroIntoDropdownWhenScrolled {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Recipes Of The Week"
                                            recipes:[self weeklyRecipes]
                                       emptyMessage:@"No weekly picks yet."
                                             window:&window
                               navigationController:&navigationController];

  XCTAssertFalse(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);
  XCTAssertTrue(listViewController.compactDropdownButton.hidden);

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertTrue(listViewController.introCompact);
  XCTAssertFalse(listViewController.introDropdownExpanded);
  XCTAssertFalse(listViewController.compactDropdownButton.hidden);

  window.hidden = YES;
}

- (void)testWeeklyRecipeListDropdownReExpandsIntroAndResetsNearTop {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Recipes Of The Week"
                                            recipes:[self weeklyRecipes]
                                       emptyMessage:@"No weekly picks yet."
                                             window:&window
                               navigationController:&navigationController];

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];

  [listViewController.compactDropdownButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertTrue(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);

  listViewController.collectionView.contentOffset = CGPointMake(0.0, -listViewController.collectionView.adjustedContentInset.top);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertFalse(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);
  XCTAssertTrue(listViewController.compactDropdownButton.hidden);

  window.hidden = YES;
}

- (void)testWeeklyRecipeListExpandedDropdownStaysClippedInsideIntroCard {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Recipes Of The Week"
                                            recipes:[self weeklyRecipes]
                                       emptyMessage:@"No weekly picks yet."
                                             window:&window
                               navigationController:&navigationController];

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];

  [listViewController.compactDropdownButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  CGRect compactDropdownFrame =
      [listViewController.compactDropdownButton.superview convertRect:listViewController.compactDropdownButton.frame toView:listViewController.view];
  CGRect expandedIntroFrame =
      [listViewController.expandedIntroStackView.superview convertRect:listViewController.expandedIntroStackView.frame toView:listViewController.view];
  CGRect introCardFrame =
      [listViewController.introCardSurfaceView.superview convertRect:listViewController.introCardSurfaceView.frame toView:listViewController.view];

  XCTAssertTrue(listViewController.introCardSurfaceView.clipsToBounds);
  XCTAssertLessThanOrEqual(CGRectGetMaxY(compactDropdownFrame), CGRectGetMinY(expandedIntroFrame));
  XCTAssertGreaterThanOrEqual(CGRectGetMinY(expandedIntroFrame), CGRectGetMinY(introCardFrame));
  XCTAssertLessThanOrEqual(CGRectGetMaxY(expandedIntroFrame), CGRectGetMaxY(introCardFrame));

  window.hidden = YES;
}

- (void)testRecommendationRecipeListCompactsIntroIntoDropdownWhenScrolled {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Recommendation"
                                            recipes:[self recommendationRecipes]
                                       emptyMessage:@"No recommendation picks yet."
                                             window:&window
                               navigationController:&navigationController];

  XCTAssertFalse(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);
  XCTAssertTrue(listViewController.compactDropdownButton.hidden);

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertTrue(listViewController.introCompact);
  XCTAssertFalse(listViewController.introDropdownExpanded);
  XCTAssertFalse(listViewController.compactDropdownButton.hidden);

  window.hidden = YES;
}

- (void)testRecommendationPicksRecipeListCompactsIntroIntoDropdownWhenScrolled {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Dinner Picks"
                                            recipes:[self recommendationRecipes]
                                       emptyMessage:@"There are no recipes in this category yet."
                                             window:&window
                               navigationController:&navigationController];

  XCTAssertFalse(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);
  XCTAssertTrue(listViewController.compactDropdownButton.hidden);

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertTrue(listViewController.introCompact);
  XCTAssertFalse(listViewController.introDropdownExpanded);
  XCTAssertFalse(listViewController.compactDropdownButton.hidden);
  XCTAssertEqualObjects([listViewController.compactDropdownButton titleForState:UIControlStateNormal], @"8 curated picks");

  window.hidden = YES;
}

- (void)testRecommendationRecipeListExpandedDropdownStaysClippedInsideIntroCard {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Recommendation"
                                            recipes:[self recommendationRecipes]
                                       emptyMessage:@"No recommendation picks yet."
                                             window:&window
                               navigationController:&navigationController];

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];

  [listViewController.compactDropdownButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  CGRect compactDropdownFrame =
      [listViewController.compactDropdownButton.superview convertRect:listViewController.compactDropdownButton.frame toView:listViewController.view];
  CGRect expandedIntroFrame =
      [listViewController.expandedIntroStackView.superview convertRect:listViewController.expandedIntroStackView.frame toView:listViewController.view];
  CGRect introCardFrame =
      [listViewController.introCardSurfaceView.superview convertRect:listViewController.introCardSurfaceView.frame toView:listViewController.view];

  XCTAssertTrue(listViewController.introCardSurfaceView.clipsToBounds);
  XCTAssertLessThanOrEqual(CGRectGetMaxY(compactDropdownFrame), CGRectGetMinY(expandedIntroFrame));
  XCTAssertGreaterThanOrEqual(CGRectGetMinY(expandedIntroFrame), CGRectGetMinY(introCardFrame));
  XCTAssertLessThanOrEqual(CGRectGetMaxY(expandedIntroFrame), CGRectGetMaxY(introCardFrame));

  window.hidden = YES;
}

- (void)testSearchResultsRecipeListKeepsExpandedIntroWhileScrolling {
  UIWindow *window = nil;
  UINavigationController *navigationController = nil;
  HomeRecipeListViewController *listViewController =
      [self mountedRecipeListViewControllerWithTitle:@"Search Results"
                                            recipes:[self.dataProvider searchRecipes:@"a"]
                                       emptyMessage:@"No recipes match that search yet."
                                             window:&window
                               navigationController:&navigationController];

  listViewController.collectionView.contentOffset = CGPointMake(0.0, 88.0);
  [listViewController scrollViewDidScroll:listViewController.collectionView];
  [self spinMainRunLoop];
  [listViewController.view layoutIfNeeded];

  XCTAssertFalse(listViewController.introCompact);
  XCTAssertTrue(listViewController.introDropdownExpanded);
  XCTAssertTrue(listViewController.compactDropdownButton.hidden);

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
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] != nil;
  } timeout:1.2];

  XCTAssertNotNil([self presentedRecipeContainerViewController]);
  XCTAssertEqualObjects([self presentedRecipeDetailRootView].accessibilityIdentifier, @"onboarding.recipeDetail.view");
}

- (void)testSelectingRecommendationRecipeUsesFullscreenPopupPresentation {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.recommendationCollectionView didSelectItemAtIndexPath:firstIndexPath];
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] != nil;
  } timeout:1.2];

  UIViewController *presentedViewController = [self presentedRecipeContainerViewController];
  XCTAssertNotNil(presentedViewController);
  XCTAssertTrue([presentedViewController isKindOfClass:[UINavigationController class]]);
  XCTAssertEqual(presentedViewController.modalPresentationStyle, UIModalPresentationFullScreen);
  XCTAssertEqual(presentedViewController.modalTransitionStyle, UIModalTransitionStyleCoverVertical);
}

- (void)testSelectingRecommendationRecipeHydratesDetailFromAsyncProvider {
  [self finishInitialLoadIfNeeded];

  self.dataProvider.detailDelay = 0.12;

  NSIndexPath *targetIndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
  [self.viewController collectionView:self.viewController.recommendationCollectionView didSelectItemAtIndexPath:targetIndexPath];

  UIViewController *presentedViewController = [self presentedRecipeContainerViewController];
  XCTAssertNotNil(presentedViewController);
  XCTAssertTrue([presentedViewController isKindOfClass:[UINavigationController class]]);

  OnboardingRecipeDetailViewController *detailViewController =
      (OnboardingRecipeDetailViewController *)((UINavigationController *)presentedViewController).topViewController;
  XCTAssertTrue(detailViewController.loading);

  [self waitForCondition:^BOOL {
    return !detailViewController.loading;
  } timeout:1.2];

  XCTAssertFalse(detailViewController.loading);
  XCTAssertEqual(detailViewController.debugOrigin, OnboardingRecipeDetailDebugOriginLive);
  XCTAssertEqualObjects(detailViewController.recipeDetail.title, @"Pasta Carbonara, Hydrated");
}

- (void)testFullscreenRecipeDetailPinsCloseButtonToRootChrome {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.recommendationCollectionView didSelectItemAtIndexPath:firstIndexPath];
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] != nil;
  } timeout:1.2];

  UIView *detailRootView = [self presentedRecipeDetailRootView];
  UIButton *closeButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:detailRootView];
  XCTAssertNotNil(closeButton);
  XCTAssertEqualObjects(closeButton.superview, detailRootView);
}

- (void)testFullscreenRecipeDetailUsesPremiumCloseButtonIcon {
  [self finishInitialLoadIfNeeded];

  NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.recommendationCollectionView didSelectItemAtIndexPath:firstIndexPath];
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] != nil;
  } timeout:1.2];

  UIView *detailRootView = [self presentedRecipeDetailRootView];
  UIButton *closeButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:detailRootView];
  XCTAssertNotNil(closeButton);
  XCTAssertNotNil(closeButton.currentImage);
  XCTAssertEqual(closeButton.currentTitle.length, 0U);
}

- (void)testHomeRecipeCardCellFallsBackToLocalAssetWhenRemoteImageURLIsInvalid {
  HomeRecipeCardCell *cell = [[HomeRecipeCardCell alloc] initWithFrame:CGRectMake(0.0, 0.0, 280.0, 320.0)];
  HomeRecipeCard *card =
      [[HomeRecipeCard alloc] initWithRecipeID:@"test.cell.fallback"
                                         title:@"Fallback Test"
                                      subtitle:@"Fallback subtitle"
                                     assetName:@"avocado-toast"
                                imageURLString:@"http://example.com/invalid url"
                                   summaryText:@"Fallback summary"
                                readyInMinutes:12
                                      servings:2
                                  calorieCount:250
                               popularityScore:90
                                    sourceName:@"Culina Test Kitchen"
                               sourceURLString:nil
                                      mealType:HomeCategoryIdentifierBreakfast
                                          tags:@[ @"Test" ]];

  [cell configureWithRecipeCard:card style:HomeRecipeCardCellStyleRail];

  UIImage *expectedImage = [UIImage imageNamed:@"avocado-toast"];
  XCTAssertNotNil(cell.heroImageView.image);
  XCTAssertNotNil(expectedImage);
  XCTAssertEqualObjects(UIImagePNGRepresentation(cell.heroImageView.image), UIImagePNGRepresentation(expectedImage));
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

- (NSArray<HomeRecipeCard *> *)weeklyRecipes {
  for (HomeSection *section in [self.dataProvider featuredSections]) {
    if ([section.identifier isEqualToString:HomeSectionIdentifierWeekly]) {
      return section.recipes;
    }
  }

  return @[];
}

- (NSArray<HomeRecipeCard *> *)recommendationRecipes {
  for (HomeSection *section in [self.dataProvider featuredSections]) {
    if ([section.identifier isEqualToString:HomeSectionIdentifierRecommendation]) {
      return section.recipes;
    }
  }

  return @[];
}

- (NSArray<HomeRecipeCard *> *)testRecipeCardsWithPrefix:(NSString *)prefix count:(NSUInteger)count mealType:(NSString *)mealType {
  return MRRTestHomeRecipeCardsWithPrefix(prefix, count, mealType);
}

- (OnboardingRecipeDetail *)testRecipeDetailWithTitle:(NSString *)title assetName:(NSString *)assetName {
  return MRRTestHomeRecipeDetail(title, assetName);
}

- (HomeRecipeListViewController *)mountedRecipeListViewControllerWithTitle:(NSString *)title
                                                                   recipes:(NSArray<HomeRecipeCard *> *)recipes
                                                              emptyMessage:(NSString *)emptyMessage
                                                                    window:(UIWindow * __strong *)window
                                                      navigationController:(UINavigationController * __strong *)navigationController {
  HomeRecipeListViewController *listViewController =
      [[HomeRecipeListViewController alloc] initWithScreenTitle:title recipes:recipes emptyMessage:emptyMessage];
  UIWindow *mountedWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UINavigationController *mountedNavigationController = [[UINavigationController alloc] initWithRootViewController:listViewController];
  mountedWindow.rootViewController = mountedNavigationController;
  [mountedWindow makeKeyAndVisible];
  [mountedNavigationController loadViewIfNeeded];
  [listViewController loadViewIfNeeded];
  [listViewController.view layoutIfNeeded];

  if (window != nil) {
    *window = mountedWindow;
  }
  if (navigationController != nil) {
    *navigationController = mountedNavigationController;
  }

  return listViewController;
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
