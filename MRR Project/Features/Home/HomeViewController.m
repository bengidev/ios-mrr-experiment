#import "HomeViewController.h"

#import "../Authentication/MRRAuthSession.h"
#import "../Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"
#import "../../Layout/MRRLayoutScaling.h"
#import "HomeCollectionViewCells.h"
#import "HomeRecipeListViewController.h"
#import "HomeSectionHeaderView.h"

static NSString *const MRRHomeCategoryCellReuseIdentifier = @"MRRHomeCategoryCell";
static NSString *const MRRHomeRecipeCardCellReuseIdentifier = @"MRRHomeRecipeCardCell";
static NSString *const MRRHomeSearchResultsCellReuseIdentifier = @"MRRHomeSearchResultsCell";
static NSTimeInterval const MRRHomeInitialLoadDelay = 0.24;
static NSTimeInterval const MRRHomeSearchDebounceDelay = 0.45;
static NSUInteger const MRRHomeSearchPreviewDisplayLimit = 3;
static NSUInteger const MRRHomeSearchRequestLimit = 12;

typedef NS_ENUM(NSInteger, MRRHomeSectionActionTag) {
  MRRHomeSectionActionTagSearchResults = 301,
  MRRHomeSectionActionTagRecommendation = 302,
  MRRHomeSectionActionTagWeekly = 303,
};

static UIColor *MRRHomeDynamicColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRHomeNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeDynamicColor(lightColor, darkColor);
}

static NSString *MRRHomeDisplayNameFromSession(MRRAuthSession *session) {
  if (session.displayName.length > 0) {
    return session.displayName;
  }

  if (session.email.length > 0) {
    NSArray<NSString *> *components = [session.email componentsSeparatedByString:@"@"];
    if (components.count > 0 && [components.firstObject length] > 0) {
      return components.firstObject.capitalizedString;
    }
  }

  return @"Chef";
}

static NSString *MRRHomeInitialsFromName(NSString *name) {
  NSArray<NSString *> *components = [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSMutableString *initials = [NSMutableString string];
  for (NSString *component in components) {
    if (component.length == 0) {
      continue;
    }

    [initials appendString:[[component substringToIndex:1] uppercaseString]];
    if (initials.length >= 2) {
      break;
    }
  }

  if (initials.length == 0 && name.length > 0) {
    [initials appendString:[[name substringToIndex:1] uppercaseString]];
  }

  return initials.length > 0 ? initials : @"C";
}

static NSString *MRRHomeMealTypeDisplayName(NSString *mealTypeIdentifier) {
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierBreakfast]) {
    return @"Breakfast";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierLunch]) {
    return @"Lunch";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDinner]) {
    return @"Dinner";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDessert]) {
    return @"Dessert";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierSnack]) {
    return @"Snack";
  }

  return @"Recipe";
}

@interface HomeViewController () <UICollectionViewDataSource,
                                  UICollectionViewDelegate,
                                  UICollectionViewDelegateFlowLayout,
                                  UITextFieldDelegate,
                                  HomeRecipeListViewControllerDelegate,
                                  OnboardingRecipeDetailViewControllerDelegate>

@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain) id<HomeDataProviding> dataProvider;

@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UILabel *greetingLabel;
@property(nonatomic, retain) UILabel *headlineLabel;
@property(nonatomic, retain) UIButton *avatarButton;
@property(nonatomic, retain) UIView *searchContainerView;
@property(nonatomic, retain) UITextField *searchTextField;
@property(nonatomic, retain) UIButton *filterButton;
@property(nonatomic, retain) UIActivityIndicatorView *filterLoadingIndicator;
@property(nonatomic, retain) UIView *activeFiltersContainerView;
@property(nonatomic, retain) UIScrollView *activeFiltersScrollView;
@property(nonatomic, retain) UIStackView *activeFiltersStackView;
@property(nonatomic, retain) UIButton *clearFiltersButton;
@property(nonatomic, retain) UIView *loadingStateView;
@property(nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, retain) UILabel *loadingStateLabel;

@property(nonatomic, retain) UIStackView *categoriesSectionView;
@property(nonatomic, retain) HomeSectionHeaderView *categoriesHeaderView;
@property(nonatomic, retain) UICollectionView *categoryCollectionView;
@property(nonatomic, retain) NSLayoutConstraint *categoryCollectionHeightConstraint;

@property(nonatomic, retain) UIStackView *searchResultsSectionView;
@property(nonatomic, retain) HomeSectionHeaderView *searchResultsHeaderView;
@property(nonatomic, retain) UILabel *searchStatusLabel;
@property(nonatomic, retain) UICollectionView *searchResultsCollectionView;
@property(nonatomic, retain) UILabel *searchEmptyStateLabel;
@property(nonatomic, retain) NSLayoutConstraint *searchResultsHeightConstraint;

@property(nonatomic, retain) UIStackView *recommendationSectionView;
@property(nonatomic, retain) HomeSectionHeaderView *recommendationHeaderView;
@property(nonatomic, retain) UICollectionView *recommendationCollectionView;
@property(nonatomic, retain) UILabel *recommendationEmptyStateLabel;
@property(nonatomic, retain) NSLayoutConstraint *recommendationCollectionHeightConstraint;

@property(nonatomic, retain) UIStackView *weeklySectionView;
@property(nonatomic, retain) HomeSectionHeaderView *weeklyHeaderView;
@property(nonatomic, retain) UICollectionView *weeklyCollectionView;
@property(nonatomic, retain) NSLayoutConstraint *weeklyCollectionHeightConstraint;
@property(nonatomic, retain) UIView *poweredByContainerView;
@property(nonatomic, retain) UIButton *poweredByButton;

@property(nonatomic, copy) NSArray<HomeCategory *> *categories;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *recommendationBaseRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *weeklyBaseRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *weeklyRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *filteredRecommendationRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *allSearchResults;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *currentSearchResults;
@property(nonatomic, retain, nullable) HomeCategory *selectedCategory;
@property(nonatomic, assign) HomeFilterOption currentFilterOption;
@property(nonatomic, retain) HomeAdvancedFilterSettings *advancedFilterSettings;
@property(nonatomic, assign) HomeSearchState searchState;
@property(nonatomic, assign, getter=isLoadingContent) BOOL loadingContent;
@property(nonatomic, retain, nullable) NSTimer *initialLoadTimer;
@property(nonatomic, retain, nullable) NSTimer *searchDebounceTimer;
@property(nonatomic, copy, nullable) NSString *lastCompletedSearchQuery;
@property(nonatomic, assign) BOOL hasAnimatedEntrance;
@property(nonatomic, assign) NSUInteger contentRequestToken;
@property(nonatomic, assign) NSUInteger searchRequestToken;
@property(nonatomic, assign) BOOL displayingLiveContent;
@property(nonatomic, assign, getter=isApplyingFilter) BOOL applyingFilter;

- (void)buildViewHierarchy;
- (UIStackView *)sectionStackView;
- (UICollectionView *)horizontalCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UICollectionView *)verticalCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UILabel *)emptyStateLabelWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)searchAdornmentView;
- (UIView *)loadingPlaceholderBarWithWidthMultiplier:(CGFloat)widthMultiplier;
- (NSString *)greetingText;
- (NSString *)avatarInitialsText;
- (void)beginInitialLoad;
- (void)handleInitialLoadTimer:(NSTimer *)timer;
- (void)loadContentFromProviderShowingLoadingState:(BOOL)showLoadingState animated:(BOOL)animated;
- (void)refreshVisibleContentForCurrentFilter;
- (HomeSection * _Nullable)sectionWithIdentifier:(NSString *)identifier inSections:(NSArray<HomeSection *> *)sections;
- (NSArray<HomeRecipeCard *> *)sortedRecipesFromRecipes:(NSArray<HomeRecipeCard *> *)recipes;
- (NSArray<HomeRecipeCard *> *)recommendationRecipesForCurrentSelection;
- (NSString *)currentSearchQuery;
- (void)applyCurrentPresentationStateAnimated:(BOOL)animated;
- (void)reloadCollectionContentAnimated:(BOOL)animated;
- (void)updateMetricsForCurrentViewport;
- (void)updateSearchSectionVisibility;
- (void)updateRecommendationSectionVisibility;
- (void)updatePoweredByVisibility;
- (void)updateFilterLoadingState;
- (void)updateActiveFiltersSummary;
- (void)updateSearchResultsHeightConstraintIfNeeded;
- (void)animateEntranceIfNeeded;
- (void)handleSearchTextChanged:(UITextField *)sender;
- (void)handleSearchDebounceTimer:(NSTimer *)timer;
- (void)executeSearchForQuery:(NSString *)query resultLimit:(NSUInteger)resultLimit presentingResultsList:(BOOL)presentResultsList;
- (void)clearSearchState;
- (void)handleFilterButtonTapped:(id)sender;
- (void)applyFilterOption:(HomeFilterOption)filterOption;
- (void)presentAdvancedFiltersAlert;
- (void)applyAdvancedFilters:(HomeAdvancedFilterSettings *)advancedFilters;
- (void)clearAdvancedFilters;
- (NSString *)displayTitleForFilterOption:(HomeFilterOption)filterOption;
- (NSString *)filterActionSheetMessage;
- (UIView *)activeFilterChipViewWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (NSInteger)integerValueFromTextFieldString:(NSString *)string;
- (void)handleSeeAllButtonTapped:(UIButton *)sender;
- (void)presentRecipeListWithTitle:(NSString *)title recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage;
- (void)presentRecipeDetailForCard:(HomeRecipeCard *)recipeCard;
- (void)animateRecipeSelectionFromSourceView:(nullable UIView *)sourceView completion:(dispatch_block_t)completion;
- (OnboardingRecipePreview *)previewForRecipeCard:(HomeRecipeCard *)recipeCard;
- (OnboardingRecipeDetail *)seedRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard;
- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController;
- (UIViewController *)preferredPresenterViewController;
- (void)dismissPresentedRecipeDetailIfNeeded;
- (void)handleAvatarButtonTapped:(id)sender;
- (void)handlePoweredByButtonTapped:(id)sender;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;
- (void)configurePressFeedbackForButton:(UIButton *)button;
- (void)dismissKeyboard;

@end

@implementation HomeViewController

- (instancetype)init {
  return [self initWithSession:nil dataProvider:[[[HomeCompositeDataProvider alloc] init] autorelease]];
}

- (instancetype)initWithSession:(MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider {
  NSParameterAssert(dataProvider != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.title = @"Home";
    _session = [session retain];
    _dataProvider = [dataProvider retain];
    _currentFilterOption = HomeFilterOptionFeatured;
    _advancedFilterSettings = [[HomeAdvancedFilterSettings emptySettings] retain];
    _searchState = HomeSearchStateIdle;
    _loadingContent = YES;
  }

  return self;
}

- (void)dealloc {
  [_searchDebounceTimer invalidate];
  [_initialLoadTimer invalidate];

  [_searchDebounceTimer release];
  [_initialLoadTimer release];
  [_advancedFilterSettings release];
  [_clearFiltersButton release];
  [_activeFiltersStackView release];
  [_activeFiltersScrollView release];
  [_activeFiltersContainerView release];
  [_selectedCategory release];
  [_lastCompletedSearchQuery release];
  [_currentSearchResults release];
  [_allSearchResults release];
  [_filteredRecommendationRecipes release];
  [_weeklyRecipes release];
  [_weeklyBaseRecipes release];
  [_recommendationBaseRecipes release];
  [_recipesByCategoryIdentifier release];
  [_categories release];
  [_poweredByButton release];
  [_poweredByContainerView release];
  [_weeklyCollectionHeightConstraint release];
  [_weeklyCollectionView release];
  [_weeklyHeaderView release];
  [_weeklySectionView release];
  [_recommendationCollectionHeightConstraint release];
  [_recommendationEmptyStateLabel release];
  [_recommendationCollectionView release];
  [_recommendationHeaderView release];
  [_recommendationSectionView release];
  [_searchResultsHeightConstraint release];
  [_searchEmptyStateLabel release];
  [_searchResultsCollectionView release];
  [_searchStatusLabel release];
  [_searchResultsHeaderView release];
  [_searchResultsSectionView release];
  [_categoryCollectionHeightConstraint release];
  [_categoryCollectionView release];
  [_categoriesHeaderView release];
  [_categoriesSectionView release];
  [_loadingStateLabel release];
  [_loadingIndicator release];
  [_loadingStateView release];
  [_filterLoadingIndicator release];
  [_filterButton release];
  [_searchTextField release];
  [_searchContainerView release];
  [_avatarButton release];
  [_headlineLabel release];
  [_greetingLabel release];
  [_contentStackView release];
  [_contentView release];
  [_scrollView release];
  [_dataProvider release];
  [_session release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"home.view";
  self.view.backgroundColor = MRRHomeNamedColor(@"HomeCanvasColor", [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0],
                                                [UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0]);

  [self buildViewHierarchy];
  [self beginInitialLoad];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self animateEntranceIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateMetricsForCurrentViewport];
  [self.categoryCollectionView.collectionViewLayout invalidateLayout];
  [self.recommendationCollectionView.collectionViewLayout invalidateLayout];
  [self.weeklyCollectionView.collectionViewLayout invalidateLayout];
  [self.searchResultsCollectionView.collectionViewLayout invalidateLayout];
  [self updateSearchResultsHeightConstraintIfNeeded];
}

#pragma mark - View Setup

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.delaysContentTouches = NO;
  scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UIStackView *contentStackView = [[[UIStackView alloc] init] autorelease];
  contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
  contentStackView.axis = UILayoutConstraintAxisVertical;
  contentStackView.spacing = 24.0;
  [contentView addSubview:contentStackView];
  self.contentStackView = contentStackView;

  UIView *headerRowView = [[[UIView alloc] init] autorelease];
  headerRowView.translatesAutoresizingMaskIntoConstraints = NO;
  [contentStackView addArrangedSubview:headerRowView];

  UIView *headerTopRowView = [[[UIView alloc] init] autorelease];
  headerTopRowView.translatesAutoresizingMaskIntoConstraints = NO;
  [headerRowView addSubview:headerTopRowView];

  UILabel *greetingLabel = [[[UILabel alloc] init] autorelease];
  greetingLabel.translatesAutoresizingMaskIntoConstraints = NO;
  greetingLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
  greetingLabel.adjustsFontForContentSizeCategory = YES;
  greetingLabel.textColor = MRRHomeNamedColor(@"HomeHeroSecondaryTextColor", [UIColor colorWithRed:0.46 green:0.43 blue:0.39 alpha:1.0],
                                              [UIColor colorWithRed:0.72 green:0.72 blue:0.69 alpha:1.0]);
  greetingLabel.text = [self greetingText];
  greetingLabel.accessibilityIdentifier = @"home.greetingLabel";
  greetingLabel.accessibilityTraits = UIAccessibilityTraitHeader;
  [headerTopRowView addSubview:greetingLabel];
  self.greetingLabel = greetingLabel;

  UILabel *headlineLabel = [[[UILabel alloc] init] autorelease];
  headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
  headlineLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
  headlineLabel.adjustsFontForContentSizeCategory = YES;
  headlineLabel.textColor = MRRHomeNamedColor(@"HomeHeroPrimaryTextColor", [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1.0],
                                              [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0]);
  headlineLabel.numberOfLines = 0;
  headlineLabel.text = @"What would you like\nto cook today?";
  headlineLabel.accessibilityIdentifier = @"home.headlineLabel";
  [headerRowView addSubview:headlineLabel];
  self.headlineLabel = headlineLabel;

  UIButton *avatarButton = [UIButton buttonWithType:UIButtonTypeSystem];
  avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
  avatarButton.accessibilityIdentifier = @"home.avatarButton";
  avatarButton.layer.cornerRadius = 28.0;
  avatarButton.layer.borderWidth = 1.0;
  avatarButton.layer.borderColor = [MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                      [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]) colorWithAlphaComponent:0.08].CGColor;
  avatarButton.backgroundColor = MRRHomeNamedColor(@"HomeAvatarSurfaceColor", [UIColor colorWithRed:0.91 green:0.97 blue:0.93 alpha:1.0],
                                                   [UIColor colorWithRed:0.16 green:0.19 blue:0.18 alpha:1.0]);
  avatarButton.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
  [avatarButton setTitle:[self avatarInitialsText] forState:UIControlStateNormal];
  [avatarButton setTitleColor:MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0])
                    forState:UIControlStateNormal];
  avatarButton.accessibilityLabel = @"Open profile";
  avatarButton.accessibilityHint = @"Switches to the Profile tab.";
  [avatarButton addTarget:self action:@selector(handleAvatarButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:avatarButton];
  [headerTopRowView addSubview:avatarButton];
  self.avatarButton = avatarButton;

  [NSLayoutConstraint activateConstraints:@[
    [headerTopRowView.topAnchor constraintEqualToAnchor:headerRowView.topAnchor],
    [headerTopRowView.leadingAnchor constraintEqualToAnchor:headerRowView.leadingAnchor],
    [headerTopRowView.trailingAnchor constraintEqualToAnchor:headerRowView.trailingAnchor],

    [greetingLabel.leadingAnchor constraintEqualToAnchor:headerTopRowView.leadingAnchor],
    [greetingLabel.topAnchor constraintEqualToAnchor:headerTopRowView.topAnchor constant:6.0],

    [avatarButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:greetingLabel.trailingAnchor constant:12.0],
    [avatarButton.trailingAnchor constraintEqualToAnchor:headerTopRowView.trailingAnchor],
    [avatarButton.topAnchor constraintEqualToAnchor:headerTopRowView.topAnchor],
    [avatarButton.widthAnchor constraintEqualToConstant:56.0],
    [avatarButton.heightAnchor constraintEqualToConstant:56.0],
    [headerTopRowView.bottomAnchor constraintEqualToAnchor:avatarButton.bottomAnchor],

    [headlineLabel.topAnchor constraintEqualToAnchor:headerTopRowView.bottomAnchor constant:12.0],
    [headlineLabel.leadingAnchor constraintEqualToAnchor:headerRowView.leadingAnchor],
    [headlineLabel.trailingAnchor constraintEqualToAnchor:headerRowView.trailingAnchor],
    [headlineLabel.bottomAnchor constraintEqualToAnchor:headerRowView.bottomAnchor]
  ]];

  UIView *searchContainerView = [[[UIView alloc] init] autorelease];
  searchContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  searchContainerView.accessibilityIdentifier = @"home.searchContainerView";
  searchContainerView.layer.cornerRadius = 28.0;
  searchContainerView.layer.borderWidth = 1.0;
  searchContainerView.layer.borderColor = MRRHomeNamedColor(@"HomeBorderColor", [UIColor colorWithRed:0.92 green:0.91 blue:0.88 alpha:1.0],
                                                            [UIColor colorWithRed:0.24 green:0.24 blue:0.22 alpha:1.0]).CGColor;
  searchContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
  searchContainerView.layer.shadowOpacity = 0.04f;
  searchContainerView.layer.shadowRadius = 12.0f;
  searchContainerView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
  searchContainerView.backgroundColor = MRRHomeNamedColor(@"HomeSearchSurfaceColor", [UIColor colorWithRed:1.0 green:1.0 blue:0.99 alpha:1.0],
                                                          [UIColor colorWithRed:0.14 green:0.15 blue:0.16 alpha:1.0]);
  [contentStackView addArrangedSubview:searchContainerView];
  self.searchContainerView = searchContainerView;

  UIView *searchAdornmentView = [self searchAdornmentView];
  searchAdornmentView.translatesAutoresizingMaskIntoConstraints = NO;
  [searchContainerView addSubview:searchAdornmentView];

  UITextField *searchTextField = [[[UITextField alloc] init] autorelease];
  searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
  searchTextField.delegate = self;
  searchTextField.borderStyle = UITextBorderStyleNone;
  searchTextField.backgroundColor = [UIColor clearColor];
  searchTextField.adjustsFontForContentSizeCategory = YES;
  searchTextField.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
  searchTextField.textColor = MRRHomeNamedColor(@"HomeHeroPrimaryTextColor", [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1.0],
                                                [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0]);
  searchTextField.attributedPlaceholder = [[[NSAttributedString alloc] initWithString:@"Search any recipes"
                                                                           attributes:@{
                                                                             NSForegroundColorAttributeName :
                                                                                 MRRHomeNamedColor(@"HomeSearchPlaceholderColor", [UIColor colorWithRed:0.60 green:0.56 blue:0.51 alpha:1.0],
                                                                                                   [UIColor colorWithRed:0.58 green:0.60 blue:0.60 alpha:1.0])
                                                                           }] autorelease];
  searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
  searchTextField.returnKeyType = UIReturnKeySearch;
  searchTextField.accessibilityIdentifier = @"home.searchTextField";
  searchTextField.accessibilityLabel = @"Search recipes";
  searchTextField.accessibilityHint = @"Type a recipe, ingredient, or meal.";
  [searchTextField addTarget:self action:@selector(handleSearchTextChanged:) forControlEvents:UIControlEventEditingChanged];
  [searchContainerView addSubview:searchTextField];
  self.searchTextField = searchTextField;

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor = MRRHomeNamedColor(@"HomeBorderColor", [UIColor colorWithRed:0.92 green:0.91 blue:0.88 alpha:1.0],
                                                  [UIColor colorWithRed:0.24 green:0.24 blue:0.22 alpha:1.0]);
  [searchContainerView addSubview:dividerView];

  UIButton *filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
  filterButton.translatesAutoresizingMaskIntoConstraints = NO;
  filterButton.accessibilityIdentifier = @"home.filterButton";
  filterButton.layer.cornerRadius = 20.0;
  filterButton.tintColor = MRRHomeNamedColor(@"HomeHeroPrimaryTextColor", [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1.0],
                                             [UIColor colorWithRed:0.95 green:0.95 blue:0.93 alpha:1.0]);
  filterButton.backgroundColor = [UIColor clearColor];
  if (@available(iOS 13.0, *)) {
    [filterButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
  } else {
    [filterButton setTitle:@"Filter" forState:UIControlStateNormal];
    filterButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  }
  filterButton.accessibilityLabel = @"Sort and filter recipes";
  filterButton.accessibilityHint = @"Adjust sort order and advanced recipe filters.";
  [filterButton addTarget:self action:@selector(handleFilterButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:filterButton];
  [searchContainerView addSubview:filterButton];
  self.filterButton = filterButton;

  UIActivityIndicatorViewStyle filterIndicatorStyle = UIActivityIndicatorViewStyleGray;
  if (@available(iOS 13.0, *)) {
    filterIndicatorStyle = UIActivityIndicatorViewStyleMedium;
  }
  UIActivityIndicatorView *filterLoadingIndicator =
      [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:filterIndicatorStyle] autorelease];
  filterLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  filterLoadingIndicator.hidesWhenStopped = YES;
  filterLoadingIndicator.userInteractionEnabled = NO;
  filterLoadingIndicator.color = MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                   [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
  [filterButton addSubview:filterLoadingIndicator];
  self.filterLoadingIndicator = filterLoadingIndicator;

  [NSLayoutConstraint activateConstraints:@[
    [searchContainerView.heightAnchor constraintEqualToConstant:60.0],

    [searchAdornmentView.leadingAnchor constraintEqualToAnchor:searchContainerView.leadingAnchor constant:18.0],
    [searchAdornmentView.centerYAnchor constraintEqualToAnchor:searchContainerView.centerYAnchor],
    [searchAdornmentView.widthAnchor constraintEqualToConstant:18.0],
    [searchAdornmentView.heightAnchor constraintEqualToConstant:18.0],

    [searchTextField.leadingAnchor constraintEqualToAnchor:searchAdornmentView.trailingAnchor constant:12.0],
    [searchTextField.topAnchor constraintEqualToAnchor:searchContainerView.topAnchor constant:10.0],
    [searchTextField.bottomAnchor constraintEqualToAnchor:searchContainerView.bottomAnchor constant:-10.0],

    [dividerView.leadingAnchor constraintEqualToAnchor:searchTextField.trailingAnchor constant:12.0],
    [dividerView.widthAnchor constraintEqualToConstant:1.0],
    [dividerView.topAnchor constraintEqualToAnchor:searchContainerView.topAnchor constant:15.0],
    [dividerView.bottomAnchor constraintEqualToAnchor:searchContainerView.bottomAnchor constant:-15.0],

    [filterButton.leadingAnchor constraintEqualToAnchor:dividerView.trailingAnchor constant:6.0],
    [filterButton.trailingAnchor constraintEqualToAnchor:searchContainerView.trailingAnchor constant:-8.0],
    [filterButton.centerYAnchor constraintEqualToAnchor:searchContainerView.centerYAnchor],
    [filterButton.widthAnchor constraintEqualToConstant:44.0],
    [filterButton.heightAnchor constraintEqualToConstant:44.0],

    [filterLoadingIndicator.centerXAnchor constraintEqualToAnchor:filterButton.centerXAnchor],
    [filterLoadingIndicator.centerYAnchor constraintEqualToAnchor:filterButton.centerYAnchor]
  ]];
  [self updateFilterLoadingState];

  UIView *activeFiltersContainerView = [[[UIView alloc] init] autorelease];
  activeFiltersContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  activeFiltersContainerView.hidden = YES;
  activeFiltersContainerView.accessibilityIdentifier = @"home.activeFilters.containerView";
  [contentStackView addArrangedSubview:activeFiltersContainerView];
  self.activeFiltersContainerView = activeFiltersContainerView;

  UIScrollView *activeFiltersScrollView = [[[UIScrollView alloc] init] autorelease];
  activeFiltersScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  activeFiltersScrollView.showsHorizontalScrollIndicator = NO;
  activeFiltersScrollView.alwaysBounceHorizontal = YES;
  activeFiltersScrollView.delaysContentTouches = NO;
  activeFiltersScrollView.accessibilityIdentifier = @"home.activeFilters.scrollView";
  [activeFiltersContainerView addSubview:activeFiltersScrollView];
  self.activeFiltersScrollView = activeFiltersScrollView;

  UIStackView *activeFiltersStackView = [[[UIStackView alloc] init] autorelease];
  activeFiltersStackView.translatesAutoresizingMaskIntoConstraints = NO;
  activeFiltersStackView.axis = UILayoutConstraintAxisHorizontal;
  activeFiltersStackView.alignment = UIStackViewAlignmentFill;
  activeFiltersStackView.spacing = 8.0;
  [activeFiltersScrollView addSubview:activeFiltersStackView];
  self.activeFiltersStackView = activeFiltersStackView;

  [NSLayoutConstraint activateConstraints:@[
    [activeFiltersContainerView.heightAnchor constraintEqualToConstant:38.0],

    [activeFiltersScrollView.topAnchor constraintEqualToAnchor:activeFiltersContainerView.topAnchor],
    [activeFiltersScrollView.leadingAnchor constraintEqualToAnchor:activeFiltersContainerView.leadingAnchor],
    [activeFiltersScrollView.trailingAnchor constraintEqualToAnchor:activeFiltersContainerView.trailingAnchor],
    [activeFiltersScrollView.bottomAnchor constraintEqualToAnchor:activeFiltersContainerView.bottomAnchor],

    [activeFiltersStackView.topAnchor constraintEqualToAnchor:activeFiltersScrollView.contentLayoutGuide.topAnchor],
    [activeFiltersStackView.leadingAnchor constraintEqualToAnchor:activeFiltersScrollView.contentLayoutGuide.leadingAnchor],
    [activeFiltersStackView.trailingAnchor constraintEqualToAnchor:activeFiltersScrollView.contentLayoutGuide.trailingAnchor],
    [activeFiltersStackView.bottomAnchor constraintEqualToAnchor:activeFiltersScrollView.contentLayoutGuide.bottomAnchor],
    [activeFiltersStackView.heightAnchor constraintEqualToAnchor:activeFiltersScrollView.frameLayoutGuide.heightAnchor]
  ]];
  [self updateActiveFiltersSummary];

  UIView *loadingStateView = [[[UIView alloc] init] autorelease];
  loadingStateView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingStateView.accessibilityIdentifier = @"home.loadingStateView";
  loadingStateView.layer.cornerRadius = 30.0;
  loadingStateView.layer.borderWidth = 1.0;
  loadingStateView.layer.borderColor = MRRHomeNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0],
                                                         [UIColor colorWithWhite:0.24 alpha:1.0]).CGColor;
  loadingStateView.backgroundColor = MRRHomeNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0],
                                                       [UIColor colorWithWhite:0.14 alpha:1.0]);
  [contentStackView addArrangedSubview:loadingStateView];
  self.loadingStateView = loadingStateView;

  UIStackView *loadingStackView = [[[UIStackView alloc] init] autorelease];
  loadingStackView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingStackView.axis = UILayoutConstraintAxisVertical;
  loadingStackView.spacing = 14.0;
  [loadingStateView addSubview:loadingStackView];

  UIActivityIndicatorViewStyle indicatorStyle = UIActivityIndicatorViewStyleGray;
  if (@available(iOS 13.0, *)) {
    indicatorStyle = UIActivityIndicatorViewStyleMedium;
  }
  UIActivityIndicatorView *loadingIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle] autorelease];
  loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  loadingIndicator.color = MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                             [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
  [loadingIndicator startAnimating];
  [loadingStackView addArrangedSubview:loadingIndicator];
  self.loadingIndicator = loadingIndicator;

  UILabel *loadingStateLabel = [[[UILabel alloc] init] autorelease];
  loadingStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
  loadingStateLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
  loadingStateLabel.adjustsFontForContentSizeCategory = YES;
  loadingStateLabel.textColor = MRRHomeNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                  [UIColor colorWithWhite:0.74 alpha:1.0]);
  loadingStateLabel.numberOfLines = 0;
  loadingStateLabel.textAlignment = NSTextAlignmentCenter;
  loadingStateLabel.text = @"Curating today's recipes...";
  loadingStateLabel.accessibilityIdentifier = @"home.loadingStateLabel";
  [loadingStackView addArrangedSubview:loadingStateLabel];
  self.loadingStateLabel = loadingStateLabel;

  [loadingStackView addArrangedSubview:[self loadingPlaceholderBarWithWidthMultiplier:1.0]];
  [loadingStackView addArrangedSubview:[self loadingPlaceholderBarWithWidthMultiplier:0.84]];
  [loadingStackView addArrangedSubview:[self loadingPlaceholderBarWithWidthMultiplier:0.72]];

  [NSLayoutConstraint activateConstraints:@[
    [loadingStackView.topAnchor constraintEqualToAnchor:loadingStateView.topAnchor constant:24.0],
    [loadingStackView.leadingAnchor constraintEqualToAnchor:loadingStateView.leadingAnchor constant:22.0],
    [loadingStackView.trailingAnchor constraintEqualToAnchor:loadingStateView.trailingAnchor constant:-22.0],
    [loadingStackView.bottomAnchor constraintEqualToAnchor:loadingStateView.bottomAnchor constant:-24.0]
  ]];

  UIStackView *categoriesSectionView = [self sectionStackView];
  categoriesSectionView.accessibilityIdentifier = @"home.categoriesSectionView";
  [contentStackView addArrangedSubview:categoriesSectionView];
  self.categoriesSectionView = categoriesSectionView;

  HomeSectionHeaderView *categoriesHeaderView = [[[HomeSectionHeaderView alloc] initWithFrame:CGRectZero] autorelease];
  [categoriesHeaderView configureWithTitle:@"Categories" identifierPrefix:@"home.categoriesHeader" showsSeeAll:NO];
  [categoriesSectionView addArrangedSubview:categoriesHeaderView];
  self.categoriesHeaderView = categoriesHeaderView;

  UICollectionView *categoryCollectionView = [self horizontalCollectionViewWithAccessibilityIdentifier:@"home.categories.collectionView"];
  [categoryCollectionView registerClass:[HomeCategoryCell class] forCellWithReuseIdentifier:MRRHomeCategoryCellReuseIdentifier];
  categoryCollectionView.backgroundColor = [UIColor clearColor];
  categoryCollectionView.showsHorizontalScrollIndicator = NO;
  [categoriesSectionView addArrangedSubview:categoryCollectionView];
  self.categoryCollectionView = categoryCollectionView;
  self.categoryCollectionHeightConstraint = [categoryCollectionView.heightAnchor constraintEqualToConstant:96.0];
  self.categoryCollectionHeightConstraint.active = YES;

  UIStackView *searchResultsSectionView = [self sectionStackView];
  searchResultsSectionView.hidden = YES;
  searchResultsSectionView.accessibilityIdentifier = @"home.searchResultsSectionView";
  [contentStackView addArrangedSubview:searchResultsSectionView];
  self.searchResultsSectionView = searchResultsSectionView;

  HomeSectionHeaderView *searchResultsHeaderView = [[[HomeSectionHeaderView alloc] initWithFrame:CGRectZero] autorelease];
  [searchResultsHeaderView configureWithTitle:@"Search Results" identifierPrefix:@"home.searchResultsHeader" showsSeeAll:NO];
  searchResultsHeaderView.seeAllButton.tag = MRRHomeSectionActionTagSearchResults;
  [searchResultsHeaderView.seeAllButton addTarget:self action:@selector(handleSeeAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [searchResultsSectionView addArrangedSubview:searchResultsHeaderView];
  self.searchResultsHeaderView = searchResultsHeaderView;

  UILabel *searchStatusLabel = [[[UILabel alloc] init] autorelease];
  searchStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  searchStatusLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
  searchStatusLabel.adjustsFontForContentSizeCategory = YES;
  searchStatusLabel.textColor = MRRHomeNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                  [UIColor colorWithWhite:0.74 alpha:1.0]);
  searchStatusLabel.numberOfLines = 0;
  searchStatusLabel.accessibilityIdentifier = @"home.searchResults.statusLabel";
  searchStatusLabel.hidden = YES;
  [searchResultsSectionView addArrangedSubview:searchStatusLabel];
  self.searchStatusLabel = searchStatusLabel;

  UICollectionView *searchResultsCollectionView = [self verticalCollectionViewWithAccessibilityIdentifier:@"home.searchResults.collectionView"];
  [searchResultsCollectionView registerClass:[HomeRecipeCardCell class] forCellWithReuseIdentifier:MRRHomeSearchResultsCellReuseIdentifier];
  searchResultsCollectionView.hidden = YES;
  [searchResultsSectionView addArrangedSubview:searchResultsCollectionView];
  self.searchResultsCollectionView = searchResultsCollectionView;
  self.searchResultsHeightConstraint = [searchResultsCollectionView.heightAnchor constraintEqualToConstant:0.0];
  self.searchResultsHeightConstraint.active = YES;

  UILabel *searchEmptyStateLabel = [self emptyStateLabelWithAccessibilityIdentifier:@"home.searchResults.emptyStateLabel"];
  searchEmptyStateLabel.hidden = YES;
  [searchResultsSectionView addArrangedSubview:searchEmptyStateLabel];
  self.searchEmptyStateLabel = searchEmptyStateLabel;

  UIStackView *recommendationSectionView = [self sectionStackView];
  recommendationSectionView.hidden = YES;
  recommendationSectionView.accessibilityIdentifier = @"home.recommendationSectionView";
  [contentStackView addArrangedSubview:recommendationSectionView];
  self.recommendationSectionView = recommendationSectionView;

  HomeSectionHeaderView *recommendationHeaderView = [[[HomeSectionHeaderView alloc] initWithFrame:CGRectZero] autorelease];
  [recommendationHeaderView configureWithTitle:@"Recommendation" identifierPrefix:@"home.recommendationHeader" showsSeeAll:YES];
  recommendationHeaderView.seeAllButton.tag = MRRHomeSectionActionTagRecommendation;
  [recommendationHeaderView.seeAllButton addTarget:self action:@selector(handleSeeAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [recommendationSectionView addArrangedSubview:recommendationHeaderView];
  self.recommendationHeaderView = recommendationHeaderView;

  UICollectionView *recommendationCollectionView = [self horizontalCollectionViewWithAccessibilityIdentifier:@"home.recommendation.collectionView"];
  [recommendationCollectionView registerClass:[HomeRecipeCardCell class] forCellWithReuseIdentifier:MRRHomeRecipeCardCellReuseIdentifier];
  [recommendationSectionView addArrangedSubview:recommendationCollectionView];
  self.recommendationCollectionView = recommendationCollectionView;
  self.recommendationCollectionHeightConstraint = [recommendationCollectionView.heightAnchor constraintEqualToConstant:298.0];
  self.recommendationCollectionHeightConstraint.active = YES;

  UILabel *recommendationEmptyStateLabel = [self emptyStateLabelWithAccessibilityIdentifier:@"home.recommendation.emptyStateLabel"];
  recommendationEmptyStateLabel.hidden = YES;
  [recommendationSectionView addArrangedSubview:recommendationEmptyStateLabel];
  self.recommendationEmptyStateLabel = recommendationEmptyStateLabel;

  UIStackView *weeklySectionView = [self sectionStackView];
  weeklySectionView.hidden = YES;
  weeklySectionView.accessibilityIdentifier = @"home.weeklySectionView";
  [contentStackView addArrangedSubview:weeklySectionView];
  self.weeklySectionView = weeklySectionView;

  HomeSectionHeaderView *weeklyHeaderView = [[[HomeSectionHeaderView alloc] initWithFrame:CGRectZero] autorelease];
  [weeklyHeaderView configureWithTitle:@"Recipes Of The Week" identifierPrefix:@"home.weeklyHeader" showsSeeAll:YES];
  weeklyHeaderView.seeAllButton.tag = MRRHomeSectionActionTagWeekly;
  [weeklyHeaderView.seeAllButton addTarget:self action:@selector(handleSeeAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [weeklySectionView addArrangedSubview:weeklyHeaderView];
  self.weeklyHeaderView = weeklyHeaderView;

  UICollectionView *weeklyCollectionView = [self horizontalCollectionViewWithAccessibilityIdentifier:@"home.weekly.collectionView"];
  [weeklyCollectionView registerClass:[HomeRecipeCardCell class] forCellWithReuseIdentifier:MRRHomeRecipeCardCellReuseIdentifier];
  [weeklySectionView addArrangedSubview:weeklyCollectionView];
  self.weeklyCollectionView = weeklyCollectionView;
  self.weeklyCollectionHeightConstraint = [weeklyCollectionView.heightAnchor constraintEqualToConstant:298.0];
  self.weeklyCollectionHeightConstraint.active = YES;

  UIView *poweredByContainerView = [[[UIView alloc] init] autorelease];
  poweredByContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  poweredByContainerView.hidden = YES;
  poweredByContainerView.accessibilityIdentifier = @"home.poweredBy.containerView";
  [contentStackView addArrangedSubview:poweredByContainerView];
  self.poweredByContainerView = poweredByContainerView;

  UIButton *poweredByButton = [UIButton buttonWithType:UIButtonTypeSystem];
  poweredByButton.translatesAutoresizingMaskIntoConstraints = NO;
  poweredByButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  poweredByButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  poweredByButton.titleLabel.adjustsFontForContentSizeCategory = YES;
  poweredByButton.accessibilityIdentifier = @"home.poweredBy.button";
  poweredByButton.accessibilityLabel = @"Powered by Spoonacular";
  poweredByButton.accessibilityHint = @"Opens the Spoonacular food API site in Safari.";
  [poweredByButton setTitle:@"Recipe discovery powered by Spoonacular" forState:UIControlStateNormal];
  [poweredByButton setTitleColor:MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                   [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0])
                        forState:UIControlStateNormal];
  [poweredByButton addTarget:self action:@selector(handlePoweredByButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:poweredByButton];
  [poweredByContainerView addSubview:poweredByButton];
  self.poweredByButton = poweredByButton;

  [NSLayoutConstraint activateConstraints:@[
    [poweredByButton.topAnchor constraintEqualToAnchor:poweredByContainerView.topAnchor],
    [poweredByButton.leadingAnchor constraintEqualToAnchor:poweredByContainerView.leadingAnchor],
    [poweredByButton.trailingAnchor constraintEqualToAnchor:poweredByContainerView.trailingAnchor],
    [poweredByButton.bottomAnchor constraintEqualToAnchor:poweredByContainerView.bottomAnchor]
  ]];

  [NSLayoutConstraint activateConstraints:@[
    [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

    [contentStackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16.0],
    [contentStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [contentStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [contentStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0]
  ]];

  UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)] autorelease];
  tapGestureRecognizer.cancelsTouchesInView = NO;
  [self.view addGestureRecognizer:tapGestureRecognizer];

  [contentStackView setCustomSpacing:18.0 afterView:headerRowView];
  [contentStackView setCustomSpacing:14.0 afterView:searchContainerView];
  [contentStackView setCustomSpacing:28.0 afterView:activeFiltersContainerView];
  [self updateMetricsForCurrentViewport];
}

- (UIStackView *)sectionStackView {
  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  return stackView;
}

- (UICollectionView *)horizontalCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.minimumLineSpacing = 16.0;

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.showsHorizontalScrollIndicator = NO;
  collectionView.alwaysBounceHorizontal = YES;
  collectionView.delaysContentTouches = NO;
  collectionView.accessibilityIdentifier = accessibilityIdentifier;
  collectionView.dataSource = self;
  collectionView.delegate = self;
  return collectionView;
}

- (UICollectionView *)verticalCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;
  layout.minimumLineSpacing = 14.0;

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.scrollEnabled = NO;
  collectionView.delaysContentTouches = NO;
  collectionView.accessibilityIdentifier = accessibilityIdentifier;
  collectionView.dataSource = self;
  collectionView.delegate = self;
  return collectionView;
}

- (UILabel *)emptyStateLabelWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
  label.adjustsFontForContentSizeCategory = YES;
  label.textColor = MRRHomeNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                      [UIColor colorWithWhite:0.74 alpha:1.0]);
  label.numberOfLines = 0;
  label.textAlignment = NSTextAlignmentCenter;
  label.accessibilityIdentifier = accessibilityIdentifier;
  return label;
}

- (UIView *)searchAdornmentView {
  if (@available(iOS 13.0, *)) {
    UIImageView *imageView =
        [[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]] autorelease];
    imageView.tintColor = MRRHomeNamedColor(@"HomeSearchPlaceholderColor", [UIColor colorWithRed:0.60 green:0.56 blue:0.51 alpha:1.0],
                                            [UIColor colorWithRed:0.58 green:0.60 blue:0.60 alpha:1.0]);
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    return imageView;
  }

  UIView *containerView = [[[UIView alloc] init] autorelease];
  UIView *lensView = [[[UIView alloc] init] autorelease];
  lensView.translatesAutoresizingMaskIntoConstraints = NO;
  lensView.layer.cornerRadius = 6.0;
  lensView.layer.borderWidth = 1.8;
  lensView.layer.borderColor = MRRHomeNamedColor(@"HomeSearchPlaceholderColor", [UIColor colorWithRed:0.60 green:0.56 blue:0.51 alpha:1.0],
                                                 [UIColor colorWithRed:0.58 green:0.60 blue:0.60 alpha:1.0]).CGColor;
  [containerView addSubview:lensView];

  UIView *handleView = [[[UIView alloc] init] autorelease];
  handleView.translatesAutoresizingMaskIntoConstraints = NO;
  handleView.backgroundColor = MRRHomeNamedColor(@"HomeSearchPlaceholderColor", [UIColor colorWithRed:0.60 green:0.56 blue:0.51 alpha:1.0],
                                                 [UIColor colorWithRed:0.58 green:0.60 blue:0.60 alpha:1.0]);
  handleView.layer.cornerRadius = 1.2;
  handleView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
  [containerView addSubview:handleView];

  [NSLayoutConstraint activateConstraints:@[
    [lensView.widthAnchor constraintEqualToConstant:12.0],
    [lensView.heightAnchor constraintEqualToConstant:12.0],
    [lensView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [lensView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:1.0],

    [handleView.widthAnchor constraintEqualToConstant:8.0],
    [handleView.heightAnchor constraintEqualToConstant:2.4],
    [handleView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-1.0],
    [handleView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-2.0]
  ]];

  return containerView;
}

- (UIView *)loadingPlaceholderBarWithWidthMultiplier:(CGFloat)widthMultiplier {
  UIView *wrapperView = [[[UIView alloc] init] autorelease];
  wrapperView.translatesAutoresizingMaskIntoConstraints = NO;

  UIView *barView = [[[UIView alloc] init] autorelease];
  barView.translatesAutoresizingMaskIntoConstraints = NO;
  barView.layer.cornerRadius = 14.0;
  barView.backgroundColor = MRRHomeNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0],
                                              [UIColor colorWithWhite:0.18 alpha:1.0]);
  [wrapperView addSubview:barView];

  [NSLayoutConstraint activateConstraints:@[
    [wrapperView.heightAnchor constraintEqualToConstant:58.0],
    [barView.topAnchor constraintEqualToAnchor:wrapperView.topAnchor],
    [barView.bottomAnchor constraintEqualToAnchor:wrapperView.bottomAnchor],
    [barView.centerXAnchor constraintEqualToAnchor:wrapperView.centerXAnchor],
    [barView.widthAnchor constraintEqualToAnchor:wrapperView.widthAnchor multiplier:widthMultiplier]
  ]];

  return wrapperView;
}

- (NSString *)greetingText {
  NSString *displayName = MRRHomeDisplayNameFromSession(self.session);
  return [NSString stringWithFormat:@"Hello, %@", displayName];
}

- (NSString *)avatarInitialsText {
  return MRRHomeInitialsFromName(MRRHomeDisplayNameFromSession(self.session));
}

#pragma mark - Data Loading

- (void)beginInitialLoad {
  self.searchTextField.enabled = NO;
  self.initialLoadTimer = [NSTimer scheduledTimerWithTimeInterval:MRRHomeInitialLoadDelay
                                                           target:self
                                                         selector:@selector(handleInitialLoadTimer:)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)handleInitialLoadTimer:(NSTimer *)timer {
  self.initialLoadTimer = nil;
  [self loadContentFromProviderShowingLoadingState:YES animated:NO];
}

- (void)loadContentFromProviderShowingLoadingState:(BOOL)showLoadingState animated:(BOOL)animated {
  self.categories = [self.dataProvider availableCategories];
  if (showLoadingState) {
    self.loadingContent = YES;
    self.searchTextField.enabled = NO;
    self.applyingFilter = NO;
    [self updateFilterLoadingState];
  }

  self.contentRequestToken += 1;
  NSUInteger requestToken = self.contentRequestToken;
  [self.dataProvider loadInitialSectionsForFilterOption:self.currentFilterOption
                                        advancedFilters:self.advancedFilterSettings
                                             completion:^(NSArray<HomeSection *> *sections,
                                                          NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier,
                                                          BOOL usesLiveData) {
    if (requestToken != self.contentRequestToken) {
      return;
    }

    HomeSection *recommendationSection = [self sectionWithIdentifier:HomeSectionIdentifierRecommendation inSections:sections];
    HomeSection *weeklySection = [self sectionWithIdentifier:HomeSectionIdentifierWeekly inSections:sections];

    self.recommendationBaseRecipes = recommendationSection != nil ? recommendationSection.recipes : @[];
    self.weeklyBaseRecipes = weeklySection != nil ? weeklySection.recipes : @[];
    self.recipesByCategoryIdentifier = recipesByCategoryIdentifier ?: @{};
    self.displayingLiveContent = usesLiveData;
    if (showLoadingState) {
      self.loadingContent = NO;
      self.searchTextField.enabled = YES;
      self.searchState = HomeSearchStateIdle;
    }
    self.applyingFilter = NO;
    [self updateFilterLoadingState];
    [self applyCurrentPresentationStateAnimated:animated];
  }];
}

- (void)refreshVisibleContentForCurrentFilter {
  NSString *currentQuery = [self currentSearchQuery];
  if (currentQuery.length >= 3) {
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = nil;
    self.searchState = HomeSearchStateSearching;
    [self updateSearchSectionVisibility];
    [self updateRecommendationSectionVisibility];
    [self updatePoweredByVisibility];
    [self executeSearchForQuery:currentQuery resultLimit:MRRHomeSearchPreviewDisplayLimit presentingResultsList:NO];
    return;
  }

  [self loadContentFromProviderShowingLoadingState:NO animated:YES];
}

- (HomeSection *)sectionWithIdentifier:(NSString *)identifier inSections:(NSArray<HomeSection *> *)sections {
  for (HomeSection *section in sections) {
    if ([section.identifier isEqualToString:identifier]) {
      return section;
    }
  }

  return nil;
}

#pragma mark - State

- (NSArray<HomeRecipeCard *> *)sortedRecipesFromRecipes:(NSArray<HomeRecipeCard *> *)recipes {
  if (recipes.count < 2) {
    return recipes;
  }

  switch (self.currentFilterOption) {
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

- (NSArray<HomeRecipeCard *> *)recommendationRecipesForCurrentSelection {
  NSArray<HomeRecipeCard *> *recipes = self.recommendationBaseRecipes ?: @[];
  if (self.selectedCategory != nil) {
    recipes = [self.recipesByCategoryIdentifier objectForKey:self.selectedCategory.identifier] ?: @[];
  }
  return [self sortedRecipesFromRecipes:recipes];
}

- (NSString *)currentSearchQuery {
  return [self.searchTextField.text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)applyCurrentPresentationStateAnimated:(BOOL)animated {
  if (self.isLoadingContent) {
    return;
  }

  self.filteredRecommendationRecipes = [self recommendationRecipesForCurrentSelection];
  self.weeklyRecipes = [self sortedRecipesFromRecipes:(self.weeklyBaseRecipes ?: @[])];

  NSString *currentQuery = [self currentSearchQuery];
  BOOL isSearching = currentQuery.length > 0;

  if (!isSearching) {
    self.searchState = HomeSearchStateIdle;
    self.allSearchResults = @[];
    self.currentSearchResults = @[];
    self.lastCompletedSearchQuery = nil;
  } else if (self.searchState != HomeSearchStateSearching) {
    self.currentSearchResults = [self sortedRecipesFromRecipes:(self.allSearchResults ?: @[])];
  }

  NSString *recommendationTitle = self.selectedCategory != nil ? [NSString stringWithFormat:@"%@ Picks", self.selectedCategory.title] : @"Recommendation";
  [self.recommendationHeaderView configureWithTitle:recommendationTitle
                                   identifierPrefix:@"home.recommendationHeader"
                                       showsSeeAll:self.filteredRecommendationRecipes.count > 0];

  self.searchResultsHeaderView.seeAllButton.hidden = !(self.currentSearchResults.count > 0 &&
                                                       self.searchState == HomeSearchStateResults);
  self.recommendationEmptyStateLabel.text = self.selectedCategory != nil
                                                ? [NSString stringWithFormat:@"No %@ recipes yet. Try another category.", self.selectedCategory.title.lowercaseString]
                                                : @"No recommendations are available right now.";

  [self reloadCollectionContentAnimated:animated];
  [self updateActiveFiltersSummary];
  [self updateFilterLoadingState];
  [self updateSearchSectionVisibility];
  [self updateRecommendationSectionVisibility];
  [self updatePoweredByVisibility];
  [self animateEntranceIfNeeded];
}

- (void)reloadCollectionContentAnimated:(BOOL)animated {
  [self.categoryCollectionView reloadData];

  void (^reloadRecommendation)(void) = ^{
    [self.recommendationCollectionView reloadData];
  };
  void (^reloadWeekly)(void) = ^{
    [self.weeklyCollectionView reloadData];
  };
  void (^reloadSearch)(void) = ^{
    [self.searchResultsCollectionView reloadData];
  };

  if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
    [UIView transitionWithView:self.recommendationCollectionView
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:reloadRecommendation
                    completion:nil];
    [UIView transitionWithView:self.searchResultsCollectionView
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:reloadSearch
                    completion:nil];
  } else {
    reloadRecommendation();
    reloadSearch();
  }

  reloadWeekly();
  [self.view setNeedsLayout];
  [self.view layoutIfNeeded];
}

- (void)updateMetricsForCurrentViewport {
  CGSize viewportSize = self.view.bounds.size;
  BOOL compactHeight = viewportSize.height < 760.0;
  BOOL compactWidth = viewportSize.width < 390.0;
  BOOL compactViewport = compactHeight || compactWidth;

  self.contentStackView.spacing = compactViewport ? 20.0 : 24.0;
  self.headlineLabel.font = [UIFont systemFontOfSize:(compactViewport ? 27.0 : 30.0) weight:UIFontWeightBold];
  self.categoryCollectionHeightConstraint.constant = compactViewport ? 88.0 : 96.0;

  CGFloat railHeight = compactViewport ? 282.0 : 298.0;
  self.recommendationCollectionHeightConstraint.constant = railHeight;
  self.weeklyCollectionHeightConstraint.constant = railHeight;
  [self.contentStackView setCustomSpacing:(compactViewport ? 16.0 : 18.0) afterView:self.contentStackView.arrangedSubviews.firstObject];
  [self.contentStackView setCustomSpacing:(compactViewport ? 10.0 : 12.0) afterView:self.searchContainerView];
  [self.contentStackView setCustomSpacing:(compactViewport ? 24.0 : 28.0) afterView:self.activeFiltersContainerView];
}

- (void)updateSearchSectionVisibility {
  BOOL shouldShowSearchSection = self.searchState != HomeSearchStateIdle;
  self.searchResultsSectionView.hidden = !shouldShowSearchSection;

  if (!shouldShowSearchSection) {
    self.searchStatusLabel.hidden = YES;
    self.searchEmptyStateLabel.hidden = YES;
    self.searchResultsCollectionView.hidden = YES;
    self.searchResultsHeightConstraint.constant = 0.0;
    return;
  }

  if (self.searchState == HomeSearchStateSearching) {
    self.searchStatusLabel.hidden = NO;
    self.searchStatusLabel.text = self.isApplyingFilter ? @"Applying filter..." : @"Searching recipes...";
    self.searchEmptyStateLabel.hidden = YES;
    self.searchResultsCollectionView.hidden = YES;
    self.searchResultsHeightConstraint.constant = 0.0;
  } else if (self.searchState == HomeSearchStateEmpty) {
    self.searchStatusLabel.hidden = YES;
    self.searchEmptyStateLabel.hidden = NO;
    self.searchEmptyStateLabel.text = @"No recipes match that search yet. Try something broader like pasta, salad, or dinner.";
    self.searchResultsCollectionView.hidden = YES;
    self.searchResultsHeightConstraint.constant = 0.0;
  } else {
    self.searchStatusLabel.hidden = YES;
    self.searchEmptyStateLabel.hidden = YES;
    self.searchResultsCollectionView.hidden = NO;
    [self updateSearchResultsHeightConstraintIfNeeded];
  }
}

- (void)updateRecommendationSectionVisibility {
  BOOL isShowingSearchResults = self.searchState != HomeSearchStateIdle;

  self.loadingStateView.hidden = !self.isLoadingContent;
  self.categoriesSectionView.hidden = self.isLoadingContent;
  self.recommendationSectionView.hidden = self.isLoadingContent || isShowingSearchResults;
  self.weeklySectionView.hidden = self.isLoadingContent || isShowingSearchResults;

  self.recommendationEmptyStateLabel.hidden = self.filteredRecommendationRecipes.count > 0 || self.isLoadingContent || isShowingSearchResults;
  self.recommendationCollectionView.hidden = self.filteredRecommendationRecipes.count == 0 || self.isLoadingContent || isShowingSearchResults;
}

- (void)updatePoweredByVisibility {
  self.poweredByContainerView.hidden = self.isLoadingContent || !self.displayingLiveContent;
}

- (void)updateFilterLoadingState {
  NSArray<NSString *> *summaryTokens = [self.advancedFilterSettings summaryTokens];
  BOOL hasAdvancedFilters = summaryTokens.count > 0;
  self.filterButton.enabled = !self.isApplyingFilter;
  self.clearFiltersButton.enabled = !self.isApplyingFilter;
  self.filterButton.imageView.alpha = self.isApplyingFilter ? 0.0 : 1.0;
  self.filterButton.titleLabel.alpha = self.isApplyingFilter ? 0.0 : 1.0;
  self.filterButton.backgroundColor = hasAdvancedFilters
                                          ? [MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                               [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]) colorWithAlphaComponent:0.12]
                                          : [UIColor clearColor];
  self.filterButton.accessibilityHint = self.isApplyingFilter ? @"Applying the selected sort order and filters."
                                                              : @"Adjust sort order and advanced recipe filters.";
  self.filterButton.accessibilityValue = self.isApplyingFilter ? @"Loading"
                                                               : (hasAdvancedFilters
                                                                      ? [NSString stringWithFormat:@"%lu filters active",
                                                                                                     (unsigned long)summaryTokens.count]
                                                                      : nil);
  if (self.isApplyingFilter) {
    [self.filterLoadingIndicator startAnimating];
  } else {
    [self.filterLoadingIndicator stopAnimating];
  }
}

- (void)updateActiveFiltersSummary {
  NSArray<UIView *> *existingViews = [[self.activeFiltersStackView.arrangedSubviews copy] autorelease];
  for (UIView *view in existingViews) {
    [self.activeFiltersStackView removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  self.clearFiltersButton = nil;

  NSArray<NSString *> *summaryTokens = [self.advancedFilterSettings summaryTokens];
  self.activeFiltersContainerView.hidden = summaryTokens.count == 0;
  self.activeFiltersScrollView.accessibilityValue = summaryTokens.count > 0 ? [summaryTokens componentsJoinedByString:@", "] : nil;
  if (summaryTokens.count == 0) {
    return;
  }

  NSUInteger chipIndex = 0;
  for (NSString *token in summaryTokens) {
    NSString *accessibilityIdentifier = [NSString stringWithFormat:@"home.activeFilters.chip.%lu", (unsigned long)(chipIndex + 1)];
    [self.activeFiltersStackView addArrangedSubview:[self activeFilterChipViewWithText:token accessibilityIdentifier:accessibilityIdentifier]];
    chipIndex += 1;
  }

  UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
  clearButton.translatesAutoresizingMaskIntoConstraints = NO;
  clearButton.accessibilityIdentifier = @"home.activeFilters.clearButton";
  clearButton.accessibilityLabel = @"Clear advanced filters";
  clearButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
  clearButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
  clearButton.layer.cornerRadius = 16.0;
  clearButton.layer.borderWidth = 1.0;
  clearButton.layer.borderColor = [MRRHomeNamedColor(@"HomeBorderColor", [UIColor colorWithRed:0.92 green:0.91 blue:0.88 alpha:1.0],
                                                     [UIColor colorWithRed:0.24 green:0.24 blue:0.22 alpha:1.0]) CGColor];
  clearButton.backgroundColor = MRRHomeNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0],
                                                  [UIColor colorWithWhite:0.14 alpha:1.0]);
  [clearButton setTitle:@"Clear" forState:UIControlStateNormal];
  [clearButton setTitleColor:MRRHomeNamedColor(@"HomeHeroPrimaryTextColor", [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1.0],
                                               [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0])
                    forState:UIControlStateNormal];
  [clearButton addTarget:self action:@selector(clearAdvancedFilters) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:clearButton];
  [self.activeFiltersStackView addArrangedSubview:clearButton];
  self.clearFiltersButton = clearButton;
}

- (void)updateSearchResultsHeightConstraintIfNeeded {
  if (self.searchResultsCollectionView.hidden) {
    self.searchResultsHeightConstraint.constant = 0.0;
    return;
  }

  [self.searchResultsCollectionView layoutIfNeeded];
  CGFloat contentHeight = self.searchResultsCollectionView.collectionViewLayout.collectionViewContentSize.height;
  self.searchResultsHeightConstraint.constant = MAX(contentHeight, 0.0);
}

- (void)animateEntranceIfNeeded {
  if (self.hasAnimatedEntrance || self.isLoadingContent || UIAccessibilityIsReduceMotionEnabled() || self.view.window == nil) {
    return;
  }

  self.hasAnimatedEntrance = YES;
  NSArray<UIView *> *viewsToAnimate = @[
    self.searchContainerView,
    self.activeFiltersContainerView,
    self.categoriesSectionView,
    self.recommendationSectionView,
    self.weeklySectionView
  ];
  CGFloat delay = 0.0;
  for (UIView *view in viewsToAnimate) {
    if (view.hidden) {
      continue;
    }

    view.alpha = 0.0;
    view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    [UIView animateWithDuration:0.42
                          delay:delay
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       view.alpha = 1.0;
                       view.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
    delay += 0.05;
  }
}

#pragma mark - Actions

- (void)handleSearchTextChanged:(UITextField *)sender {
  [self.searchDebounceTimer invalidate];
  self.searchDebounceTimer = nil;

  NSString *trimmedQuery = [self currentSearchQuery];
  if (trimmedQuery.length == 0) {
    [self clearSearchState];
    return;
  }

  if (trimmedQuery.length < 3) {
    self.searchState = HomeSearchStateIdle;
    self.allSearchResults = @[];
    self.currentSearchResults = @[];
    self.lastCompletedSearchQuery = nil;
    [self applyCurrentPresentationStateAnimated:YES];
    return;
  }

  self.searchRequestToken += 1;
  self.allSearchResults = @[];
  self.currentSearchResults = @[];
  self.lastCompletedSearchQuery = nil;
  self.searchState = HomeSearchStateSearching;
  [self updateSearchSectionVisibility];
  [self updateRecommendationSectionVisibility];
  [self updatePoweredByVisibility];

  self.searchDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:MRRHomeSearchDebounceDelay
                                                              target:self
                                                            selector:@selector(handleSearchDebounceTimer:)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void)handleSearchDebounceTimer:(NSTimer *)timer {
  self.searchDebounceTimer = nil;

  [self executeSearchForQuery:[self currentSearchQuery] resultLimit:MRRHomeSearchPreviewDisplayLimit presentingResultsList:NO];
}

- (void)executeSearchForQuery:(NSString *)query resultLimit:(NSUInteger)resultLimit presentingResultsList:(BOOL)presentResultsList {
  NSString *trimmedQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trimmedQuery.length == 0) {
    [self clearSearchState];
    return;
  }

  self.searchRequestToken += 1;
  NSUInteger requestToken = self.searchRequestToken;
  [self.dataProvider searchRecipes:trimmedQuery
                             limit:(resultLimit > 0 ? resultLimit : MRRHomeSearchRequestLimit)
                      filterOption:self.currentFilterOption
                   advancedFilters:self.advancedFilterSettings
                        completion:^(NSArray<HomeRecipeCard *> *recipes, BOOL usesLiveData) {
                          if (requestToken != self.searchRequestToken) {
                            return;
                          }

                          if (!presentResultsList && ![[self currentSearchQuery] isEqualToString:trimmedQuery]) {
                            return;
                          }

                          self.displayingLiveContent = self.displayingLiveContent || usesLiveData;
                          self.allSearchResults = recipes ?: @[];
                          self.lastCompletedSearchQuery = trimmedQuery;
                          self.searchState = self.allSearchResults.count > 0 ? HomeSearchStateResults : HomeSearchStateEmpty;
                          self.applyingFilter = NO;
                          [self updateFilterLoadingState];
                          [self applyCurrentPresentationStateAnimated:YES];

                          if (presentResultsList && self.currentSearchResults.count > 0) {
                            [self presentRecipeListWithTitle:@"Search Results"
                                                     recipes:self.currentSearchResults
                                                emptyMessage:@"No recipes match that search yet."];
                          }
                        }];
}

- (void)clearSearchState {
  self.searchState = HomeSearchStateIdle;
  self.allSearchResults = @[];
  self.currentSearchResults = @[];
  self.lastCompletedSearchQuery = nil;
  [self.searchDebounceTimer invalidate];
  self.searchDebounceTimer = nil;
  self.searchRequestToken += 1;
  self.applyingFilter = NO;
  [self updateFilterLoadingState];
  [self applyCurrentPresentationStateAnimated:YES];
}

- (void)handleFilterButtonTapped:(id)sender {
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Filters & Sort"
                                          message:[self filterActionSheetMessage]
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  alertController.view.accessibilityIdentifier = @"home.filterActionSheet";

  NSArray<NSNumber *> *filterOptions = @[
    @(HomeFilterOptionFeatured), @(HomeFilterOptionFastest), @(HomeFilterOptionPopular), @(HomeFilterOptionLowCalorie)
  ];

  for (NSNumber *filterValue in filterOptions) {
    HomeFilterOption filterOption = (HomeFilterOption)filterValue.integerValue;
    NSString *title = [self displayTitleForFilterOption:filterOption];
    if (filterOption == self.currentFilterOption) {
      title = [NSString stringWithFormat:@"Selected: %@", title];
    }

    [alertController addAction:[UIAlertAction actionWithTitle:title
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
                                                        [self applyFilterOption:filterOption];
                                                      }]];
  }

  NSString *advancedTitle = [self.advancedFilterSettings hasActiveFilters] ? @"Edit Advanced Filters…" : @"Advanced Filters…";
  [alertController addAction:[UIAlertAction actionWithTitle:advancedTitle
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                        [self presentAdvancedFiltersAlert];
                                                      });
                                                    }]];

  if ([self.advancedFilterSettings hasActiveFilters]) {
    [alertController addAction:[UIAlertAction actionWithTitle:@"Clear Advanced Filters"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(__unused UIAlertAction *action) {
                                                        [self clearAdvancedFilters];
                                                      }]];
  }

  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
  if (popoverPresentationController != nil) {
    popoverPresentationController.sourceView = self.filterButton;
    popoverPresentationController.sourceRect = self.filterButton.bounds;
  }

  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)applyFilterOption:(HomeFilterOption)filterOption {
  if (self.currentFilterOption == filterOption) {
    [self applyCurrentPresentationStateAnimated:YES];
    return;
  }

  self.currentFilterOption = filterOption;
  self.applyingFilter = YES;
  [self updateFilterLoadingState];
  [self refreshVisibleContentForCurrentFilter];
}

- (void)presentAdvancedFiltersAlert {
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Advanced Filters"
                                          message:@"Refine Home and search using Spoonacular filters."
                                   preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"home.advancedFilters.alert";

  NSArray<NSDictionary<NSString *, id> *> *fieldConfigurations = @[
    @{
      @"placeholder" : @"Cuisine (e.g. Italian)",
      @"text" : self.advancedFilterSettings.cuisine ?: @"",
      @"identifier" : @"home.advancedFilters.cuisineField"
    },
    @{
      @"placeholder" : @"Diet (e.g. vegetarian)",
      @"text" : self.advancedFilterSettings.diet ?: @"",
      @"identifier" : @"home.advancedFilters.dietField"
    },
    @{
      @"placeholder" : @"Intolerances (comma separated)",
      @"text" : self.advancedFilterSettings.intolerances ?: @"",
      @"identifier" : @"home.advancedFilters.intolerancesField"
    },
    @{
      @"placeholder" : @"Max ready time (minutes)",
      @"text" : self.advancedFilterSettings.maxReadyTime > 0 ? [NSString stringWithFormat:@"%ld", (long)self.advancedFilterSettings.maxReadyTime] : @"",
      @"identifier" : @"home.advancedFilters.maxReadyTimeField",
      @"keyboardType" : @(UIKeyboardTypeNumberPad)
    },
    @{
      @"placeholder" : @"Include ingredients",
      @"text" : self.advancedFilterSettings.includeIngredients ?: @"",
      @"identifier" : @"home.advancedFilters.includeIngredientsField"
    },
    @{
      @"placeholder" : @"Exclude ingredients",
      @"text" : self.advancedFilterSettings.excludeIngredients ?: @"",
      @"identifier" : @"home.advancedFilters.excludeIngredientsField"
    },
    @{
      @"placeholder" : @"Required equipment",
      @"text" : self.advancedFilterSettings.equipment ?: @"",
      @"identifier" : @"home.advancedFilters.equipmentField"
    }
  ];

  for (NSDictionary<NSString *, id> *fieldConfiguration in fieldConfigurations) {
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      textField.placeholder = [fieldConfiguration objectForKey:@"placeholder"];
      textField.text = [fieldConfiguration objectForKey:@"text"];
      textField.clearButtonMode = UITextFieldViewModeWhileEditing;
      textField.accessibilityIdentifier = [fieldConfiguration objectForKey:@"identifier"];
      NSNumber *keyboardTypeValue = [fieldConfiguration objectForKey:@"keyboardType"];
      if (keyboardTypeValue != nil) {
        textField.keyboardType = keyboardTypeValue.integerValue;
      }
    }];
  }

  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Clear All"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(__unused UIAlertAction *action) {
                                                      [self clearAdvancedFilters];
                                                    }]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Apply"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                                                      NSArray<UITextField *> *textFields = alertController.textFields ?: @[];
                                                      NSString *cuisine = textFields.count > 0 ? textFields[0].text : @"";
                                                      NSString *diet = textFields.count > 1 ? textFields[1].text : @"";
                                                      NSString *intolerances = textFields.count > 2 ? textFields[2].text : @"";
                                                      NSString *maxReadyTimeText = textFields.count > 3 ? textFields[3].text : @"";
                                                      NSString *includeIngredients = textFields.count > 4 ? textFields[4].text : @"";
                                                      NSString *excludeIngredients = textFields.count > 5 ? textFields[5].text : @"";
                                                      NSString *equipment = textFields.count > 6 ? textFields[6].text : @"";

                                                      HomeAdvancedFilterSettings *advancedFilters =
                                                          [[[HomeAdvancedFilterSettings alloc] initWithCuisine:cuisine
                                                                                                          diet:diet
                                                                                                  intolerances:intolerances
                                                                                            includeIngredients:includeIngredients
                                                                                            excludeIngredients:excludeIngredients
                                                                                                     equipment:equipment
                                                                                                  maxReadyTime:[self integerValueFromTextFieldString:maxReadyTimeText]] autorelease];
                                                      [self applyAdvancedFilters:advancedFilters];
                                                    }]];

  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)applyAdvancedFilters:(HomeAdvancedFilterSettings *)advancedFilters {
  HomeAdvancedFilterSettings *resolvedAdvancedFilters = advancedFilters ?: [HomeAdvancedFilterSettings emptySettings];
  if ([self.advancedFilterSettings isEqual:resolvedAdvancedFilters]) {
    [self updateActiveFiltersSummary];
    [self updateFilterLoadingState];
    [self applyCurrentPresentationStateAnimated:YES];
    return;
  }

  self.advancedFilterSettings = resolvedAdvancedFilters;
  self.applyingFilter = YES;
  [self updateActiveFiltersSummary];
  [self updateFilterLoadingState];
  [self refreshVisibleContentForCurrentFilter];
}

- (void)clearAdvancedFilters {
  [self applyAdvancedFilters:[HomeAdvancedFilterSettings emptySettings]];
}

- (NSString *)displayTitleForFilterOption:(HomeFilterOption)filterOption {
  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return @"Featured";
    case HomeFilterOptionFastest:
      return @"Fastest";
    case HomeFilterOptionPopular:
      return @"Popular";
    case HomeFilterOptionLowCalorie:
      return @"Low Calorie";
  }
}

- (NSString *)filterActionSheetMessage {
  NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"Sort: %@", [self displayTitleForFilterOption:self.currentFilterOption]]];
  NSArray<NSString *> *summaryTokens = [self.advancedFilterSettings summaryTokens];
  if (summaryTokens.count > 0) {
    [lines addObject:[NSString stringWithFormat:@"Active filters: %@", [summaryTokens componentsJoinedByString:@"  •  "]]];
  } else {
    [lines addObject:@"Add cuisine, diet, intolerance, time, ingredient, or equipment filters."];
  }
  return [lines componentsJoinedByString:@"\n"];
}

- (UIView *)activeFilterChipViewWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.accessibilityIdentifier = accessibilityIdentifier;
  containerView.layer.cornerRadius = 16.0;
  containerView.layer.borderWidth = 1.0;
  containerView.layer.borderColor = [[MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                        [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]) colorWithAlphaComponent:0.16] CGColor];
  containerView.backgroundColor = [MRRHomeNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                     [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]) colorWithAlphaComponent:0.10];

  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
  label.adjustsFontForContentSizeCategory = YES;
  label.textColor = MRRHomeNamedColor(@"HomeHeroPrimaryTextColor", [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1.0],
                                      [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0]);
  label.text = text;
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  [containerView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [containerView.heightAnchor constraintEqualToConstant:32.0],
    [label.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:12.0],
    [label.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12.0],
    [label.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor]
  ]];

  return containerView;
}

- (NSInteger)integerValueFromTextFieldString:(NSString *)string {
  NSScanner *scanner = [NSScanner scannerWithString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
  NSInteger value = 0;
  if ([scanner scanInteger:&value]) {
    return MAX(value, 0);
  }
  return 0;
}

- (void)handleSeeAllButtonTapped:(UIButton *)sender {
  switch (sender.tag) {
    case MRRHomeSectionActionTagSearchResults:
      [self executeSearchForQuery:(self.lastCompletedSearchQuery ?: [self currentSearchQuery])
                      resultLimit:MRRHomeSearchRequestLimit
             presentingResultsList:YES];
      break;
    case MRRHomeSectionActionTagRecommendation:
      [self presentRecipeListWithTitle:self.recommendationHeaderView.titleLabel.text
                               recipes:self.filteredRecommendationRecipes
                          emptyMessage:@"There are no recipes in this category yet."];
      break;
    case MRRHomeSectionActionTagWeekly:
      [self presentRecipeListWithTitle:@"Recipes Of The Week"
                               recipes:self.weeklyRecipes
                          emptyMessage:@"Weekly highlights will show up here soon."];
      break;
  }
}

- (void)presentRecipeListWithTitle:(NSString *)title recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage {
  HomeRecipeListViewController *viewController =
      [[[HomeRecipeListViewController alloc] initWithScreenTitle:title recipes:recipes emptyMessage:emptyMessage] autorelease];
  viewController.delegate = self;
  [self.navigationController pushViewController:viewController animated:YES];
}

- (void)presentRecipeDetailForCard:(HomeRecipeCard *)recipeCard {
  if (recipeCard == nil) {
    return;
  }

  OnboardingRecipePreview *preview = [self previewForRecipeCard:recipeCard];
  OnboardingRecipeDetailViewController *detailViewController =
      [[[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:preview loading:YES] autorelease];
  detailViewController.delegate = self;
  [self presentRecipeDetailViewController:detailViewController];

  OnboardingRecipeDetailViewController *retainedDetailViewController = [detailViewController retain];
  OnboardingRecipePreview *retainedPreview = [preview retain];
  [self.dataProvider loadRecipeDetailForRecipeCard:recipeCard completion:^(OnboardingRecipeDetail *detail, BOOL usesLiveData) {
    OnboardingRecipeDetail *resolvedDetail = detail ?: retainedPreview.fallbackDetail;
    OnboardingRecipeDetailDebugOrigin debugOrigin =
        detail != nil && usesLiveData ? OnboardingRecipeDetailDebugOriginLive : OnboardingRecipeDetailDebugOriginFallback;
    [retainedDetailViewController updateWithRecipeDetail:resolvedDetail debugOrigin:debugOrigin];
    [retainedDetailViewController release];
    [retainedPreview release];
  }];
}

- (OnboardingRecipePreview *)previewForRecipeCard:(HomeRecipeCard *)recipeCard {
  return [[[OnboardingRecipePreview alloc] initWithTitle:recipeCard.title
                                                subtitle:recipeCard.subtitle
                                               assetName:recipeCard.assetName
                                    openFoodFactsBarcode:nil
                                          fallbackDetail:[self seedRecipeDetailForRecipeCard:recipeCard]] autorelease];
}

- (OnboardingRecipeDetail *)seedRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard {
  OnboardingRecipeIngredient *ingredient =
      [[[OnboardingRecipeIngredient alloc] initWithName:@"Ingredients"
                                            displayText:@"Open the recipe to load the latest ingredient list."] autorelease];
  OnboardingRecipeInstruction *instruction =
      [[[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 1"
                                               detailText:@"Recipe details are loading from the source."] autorelease];
  NSArray<NSString *> *tags = recipeCard.tags.count > 0 ? recipeCard.tags : @[ MRRHomeMealTypeDisplayName(recipeCard.mealType) ];
  NSString *summaryText = recipeCard.summaryText.length > 0 ? recipeCard.summaryText : @"Recipe details are loading.";
  return [[[OnboardingRecipeDetail alloc] initWithTitle:recipeCard.title
                                               subtitle:recipeCard.subtitle
                                              assetName:recipeCard.assetName
                                     heroImageURLString:recipeCard.imageURLString
                                           durationText:[recipeCard durationText]
                                            calorieText:[recipeCard calorieText]
                                           servingsText:[recipeCard servingsText]
                                            summaryText:summaryText
                                            ingredients:@[ ingredient ]
                                           instructions:@[ instruction ]
                                                  tools:@[]
                                                   tags:tags
                                             sourceName:recipeCard.sourceName
                                        sourceURLString:recipeCard.sourceURLString
                                         productContext:nil] autorelease];
}

- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController {
  if (detailViewController == nil) {
    return;
  }

  UIViewController *presenter = [self preferredPresenterViewController];
  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:detailViewController] autorelease];
  navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
  navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  [presenter presentViewController:navigationController animated:YES completion:nil];
}

- (void)animateRecipeSelectionFromSourceView:(UIView *)sourceView completion:(dispatch_block_t)completion {
  if (completion == nil) {
    return;
  }

  if (sourceView == nil || sourceView.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
    completion();
    return;
  }

  UIView *transitionContainerView = self.navigationController.view ?: self.view.window ?: self.view;
  CGRect sourceFrame = [sourceView.superview convertRect:sourceView.frame toView:transitionContainerView];
  UIView *snapshotView = [sourceView snapshotViewAfterScreenUpdates:NO];
  if (snapshotView == nil) {
    completion();
    return;
  }

  snapshotView.frame = sourceFrame;
  snapshotView.layer.masksToBounds = NO;
  snapshotView.layer.shadowColor = [UIColor blackColor].CGColor;
  snapshotView.layer.shadowOpacity = 0.12f;
  snapshotView.layer.shadowRadius = 20.0f;
  snapshotView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
  [transitionContainerView addSubview:snapshotView];
  sourceView.hidden = YES;

  [UIView animateWithDuration:0.08
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     CGAffineTransform scaleTransform = CGAffineTransformMakeScale(1.016, 1.016);
                     CGAffineTransform liftTransform = CGAffineTransformMakeTranslation(0.0, -4.0);
                     snapshotView.transform = CGAffineTransformConcat(scaleTransform, liftTransform);
                   }
                   completion:^(__unused BOOL finished) {
                     completion();
                     [UIView animateWithDuration:0.12
                                           delay:0.0
                                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                                                 UIViewAnimationOptionCurveEaseOut
                                      animations:^{
                                        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(1.03, 1.03);
                                        CGAffineTransform liftTransform = CGAffineTransformMakeTranslation(0.0, -8.0);
                                        snapshotView.transform = CGAffineTransformConcat(scaleTransform, liftTransform);
                                        snapshotView.alpha = 0.0;
                                      }
                                      completion:^(__unused BOOL fadeFinished) {
                                        sourceView.hidden = NO;
                                        [snapshotView removeFromSuperview];
                                      }];
                   }];
}

- (UIViewController *)preferredPresenterViewController {
  UIViewController *topViewController = self.navigationController.topViewController;
  if (topViewController != nil && topViewController.view.window != nil) {
    return topViewController;
  }

  if (self.view.window != nil) {
    return self;
  }

  return self.navigationController ?: self;
}

- (void)dismissPresentedRecipeDetailIfNeeded {
  UIViewController *presenter = [self preferredPresenterViewController];
  if (presenter.presentedViewController != nil) {
    [presenter dismissViewControllerAnimated:YES completion:nil];
    return;
  }

  if (self.presentedViewController != nil) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)handleAvatarButtonTapped:(id)sender {
  if ([self.tabBarController isKindOfClass:[UITabBarController class]] && self.tabBarController.viewControllers.count > 2) {
    self.tabBarController.selectedIndex = 2;
  }
}

- (void)handlePoweredByButtonTapped:(id)sender {
  NSURL *URL = [NSURL URLWithString:@"https://spoonacular.com/food-api"];
  if (URL == nil) {
    return;
  }

  if (@available(iOS 10.0, *)) {
    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[UIApplication sharedApplication] openURL:URL];
#pragma clang diagnostic pop
}

- (void)handlePressableButtonTouchDown:(UIButton *)sender {
  if (UIAccessibilityIsReduceMotionEnabled()) {
    sender.alpha = 0.86;
    return;
  }

  [UIView animateWithDuration:0.16
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     sender.alpha = 0.84;
                     sender.transform = CGAffineTransformMakeScale(0.96, 0.96);
                   }
                   completion:nil];
}

- (void)handlePressableButtonTouchUp:(UIButton *)sender {
  [UIView animateWithDuration:0.16
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     sender.alpha = 1.0;
                     sender.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];
}

- (void)configurePressFeedbackForButton:(UIButton *)button {
  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:UIControlEventTouchDragExit];
  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:UIControlEventTouchDragEnter];
}

- (void)dismissKeyboard {
  [self.searchTextField resignFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  NSString *query = [self currentSearchQuery];
  if (query.length > 0) {
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = nil;
    [self executeSearchForQuery:query resultLimit:MRRHomeSearchRequestLimit presentingResultsList:YES];
  }
  return YES;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  if (collectionView == self.categoryCollectionView) {
    return self.categories.count;
  }
  if (collectionView == self.recommendationCollectionView) {
    return self.filteredRecommendationRecipes.count;
  }
  if (collectionView == self.weeklyCollectionView) {
    return self.weeklyRecipes.count;
  }
  if (collectionView == self.searchResultsCollectionView) {
    return MIN(self.currentSearchResults.count, (NSUInteger)MRRHomeSearchPreviewDisplayLimit);
  }

  return 0;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  if (collectionView == self.categoryCollectionView) {
    HomeCategoryCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:MRRHomeCategoryCellReuseIdentifier forIndexPath:indexPath];
    if (indexPath.item < self.categories.count) {
      HomeCategory *category = self.categories[indexPath.item];
      BOOL selected = [self.selectedCategory.identifier isEqualToString:category.identifier];
      [cell configureWithCategory:category selected:selected];
    }
    return cell;
  }

  HomeRecipeCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:(collectionView == self.searchResultsCollectionView
                                                                                     ? MRRHomeSearchResultsCellReuseIdentifier
                                                                                     : MRRHomeRecipeCardCellReuseIdentifier)
                                                                       forIndexPath:indexPath];
  NSArray<HomeRecipeCard *> *recipes = @[];
  HomeRecipeCardCellStyle style = HomeRecipeCardCellStyleRail;
  if (collectionView == self.recommendationCollectionView) {
    recipes = self.filteredRecommendationRecipes ?: @[];
  } else if (collectionView == self.weeklyCollectionView) {
    recipes = self.weeklyRecipes ?: @[];
  } else if (collectionView == self.searchResultsCollectionView) {
    recipes = self.currentSearchResults ?: @[];
    style = HomeRecipeCardCellStyleList;
  }

  if (indexPath.item < recipes.count) {
    [cell configureWithRecipeCard:recipes[indexPath.item] style:style];
  }

  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (collectionView == self.categoryCollectionView) {
    if (indexPath.item >= self.categories.count) {
      return;
    }

    HomeCategory *category = self.categories[indexPath.item];
    if ([self.selectedCategory.identifier isEqualToString:category.identifier]) {
      self.selectedCategory = nil;
    } else {
      self.selectedCategory = category;
    }

    [self applyCurrentPresentationStateAnimated:YES];
    return;
  }

  NSArray<HomeRecipeCard *> *recipes = collectionView == self.recommendationCollectionView ? self.filteredRecommendationRecipes
                                                                                           : (collectionView == self.weeklyCollectionView ? self.weeklyRecipes
                                                                                                                                           : self.currentSearchResults);
  if (indexPath.item >= recipes.count) {
    return;
  }

  UICollectionViewCell *selectedCell = [collectionView cellForItemAtIndexPath:indexPath];
  UIView *sourceView = selectedCell.contentView ?: selectedCell;
  [self animateRecipeSelectionFromSourceView:sourceView completion:^{
    [self presentRecipeDetailForCard:recipes[indexPath.item]];
  }];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGSize viewportSize = self.view.bounds.size;
  UIEdgeInsets contentInsets = collectionView.adjustedContentInset;
  UIEdgeInsets sectionInsets = [self collectionView:collectionView layout:collectionViewLayout insetForSectionAtIndex:indexPath.section];
  CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - contentInsets.left - contentInsets.right - sectionInsets.left - sectionInsets.right;
  CGFloat availableHeight = CGRectGetHeight(collectionView.bounds) - contentInsets.top - contentInsets.bottom - sectionInsets.top - sectionInsets.bottom;

  if (collectionView == self.categoryCollectionView) {
    CGFloat width = MRRLayoutClampedFloat(MRRLayoutScaledValue(92.0, viewportSize, MRRLayoutScaleAxisWidth), 82.0, 98.0);
    CGFloat height = availableHeight > 1.0 ? floor(availableHeight - 1.0) : 88.0;
    return CGSizeMake(width, MAX(height, 1.0));
  }

  if (collectionView == self.searchResultsCollectionView) {
    CGFloat width = availableWidth > 1.0 ? floor(availableWidth - 1.0) : CGRectGetWidth(collectionView.bounds);
    return CGSizeMake(MAX(width, 1.0), 304.0);
  }

  CGFloat width = MRRLayoutClampedFloat(MRRLayoutScaledValue(206.0, viewportSize, MRRLayoutScaleAxisWidth), 180.0, 220.0);
  CGFloat baseHeight = viewportSize.height < 760.0 ? 282.0 : 298.0;
  CGFloat height = availableHeight > 1.0 ? MIN(baseHeight, floor(availableHeight - 1.0)) : baseHeight;
  return CGSizeMake(width, MAX(height, 1.0));
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  if (collectionView == self.categoryCollectionView) {
    return UIEdgeInsetsZero;
  }
  if (collectionView == self.searchResultsCollectionView) {
    return UIEdgeInsetsZero;
  }
  return UIEdgeInsetsMake(0.0, 0.0, 2.0, 0.0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
  if (collectionView == self.categoryCollectionView) {
    return 10.0;
  }
  if (collectionView == self.searchResultsCollectionView) {
    return 14.0;
  }
  return 14.0;
}

#pragma mark - HomeRecipeListViewControllerDelegate

- (void)homeRecipeListViewController:(HomeRecipeListViewController *)viewController
                  didSelectRecipeCard:(HomeRecipeCard *)recipeCard
                            sourceView:(UIView *)sourceView {
  [self animateRecipeSelectionFromSourceView:sourceView completion:^{
    [self presentRecipeDetailForCard:recipeCard];
  }];
}

#pragma mark - OnboardingRecipeDetailViewControllerDelegate

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController {
  [self dismissPresentedRecipeDetailIfNeeded];
}

- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController {
  [self dismissPresentedRecipeDetailIfNeeded];
}

@end
