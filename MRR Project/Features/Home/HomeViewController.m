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
static NSTimeInterval const MRRHomeSearchDebounceDelay = 0.18;

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

@property(nonatomic, copy) NSArray<HomeCategory *> *categories;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *recommendationBaseRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *weeklyRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *filteredRecommendationRecipes;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *currentSearchResults;
@property(nonatomic, retain, nullable) HomeCategory *selectedCategory;
@property(nonatomic, assign) HomeFilterOption currentFilterOption;
@property(nonatomic, assign) HomeSearchState searchState;
@property(nonatomic, assign, getter=isLoadingContent) BOOL loadingContent;
@property(nonatomic, retain, nullable) NSTimer *initialLoadTimer;
@property(nonatomic, retain, nullable) NSTimer *searchDebounceTimer;
@property(nonatomic, copy, nullable) NSString *lastCompletedSearchQuery;
@property(nonatomic, assign) BOOL hasAnimatedEntrance;

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
- (void)loadContentFromProvider;
- (HomeSection * _Nullable)sectionWithIdentifier:(NSString *)identifier;
- (NSArray<HomeRecipeCard *> *)sortedRecipesFromRecipes:(NSArray<HomeRecipeCard *> *)recipes;
- (NSArray<HomeRecipeCard *> *)recommendationRecipesForCurrentSelection;
- (NSString *)currentSearchQuery;
- (void)applyCurrentPresentationStateAnimated:(BOOL)animated;
- (void)reloadCollectionContentAnimated:(BOOL)animated;
- (void)updateMetricsForCurrentViewport;
- (void)updateSearchSectionVisibility;
- (void)updateRecommendationSectionVisibility;
- (void)updateSearchResultsHeightConstraintIfNeeded;
- (void)animateEntranceIfNeeded;
- (void)handleSearchTextChanged:(UITextField *)sender;
- (void)handleSearchDebounceTimer:(NSTimer *)timer;
- (NSArray<HomeRecipeCard *> *)searchResultsForQuery:(NSString *)query;
- (void)executeSearchForQuery:(NSString *)query presentingResultsList:(BOOL)presentResultsList;
- (void)clearSearchState;
- (void)handleFilterButtonTapped:(id)sender;
- (void)applyFilterOption:(HomeFilterOption)filterOption;
- (NSString *)displayTitleForFilterOption:(HomeFilterOption)filterOption;
- (void)handleSeeAllButtonTapped:(UIButton *)sender;
- (void)presentRecipeListWithTitle:(NSString *)title recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage;
- (void)presentRecipeDetailForCard:(HomeRecipeCard *)recipeCard;
- (OnboardingRecipePreview *)previewForRecipeCard:(HomeRecipeCard *)recipeCard detail:(OnboardingRecipeDetail *)detail;
- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController;
- (UIViewController *)preferredPresenterViewController;
- (void)dismissPresentedRecipeDetailIfNeeded;
- (void)handleAvatarButtonTapped:(id)sender;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;
- (void)configurePressFeedbackForButton:(UIButton *)button;
- (void)dismissKeyboard;

@end

@implementation HomeViewController

- (instancetype)init {
  return [self initWithSession:nil dataProvider:[[[HomeMockDataProvider alloc] init] autorelease]];
}

- (instancetype)initWithSession:(MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider {
  NSParameterAssert(dataProvider != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _session = [session retain];
    _dataProvider = [dataProvider retain];
    _currentFilterOption = HomeFilterOptionFeatured;
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
  [_selectedCategory release];
  [_lastCompletedSearchQuery release];
  [_currentSearchResults release];
  [_filteredRecommendationRecipes release];
  [_weeklyRecipes release];
  [_recommendationBaseRecipes release];
  [_categories release];
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

  self.title = @"";
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
    [filterButton setTitle:@"Sort" forState:UIControlStateNormal];
    filterButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  }
  filterButton.accessibilityLabel = @"Sort recipes";
  filterButton.accessibilityHint = @"Choose how recipes are ordered.";
  [filterButton addTarget:self action:@selector(handleFilterButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:filterButton];
  [searchContainerView addSubview:filterButton];
  self.filterButton = filterButton;

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
    [filterButton.heightAnchor constraintEqualToConstant:44.0]
  ]];

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
  [contentStackView setCustomSpacing:28.0 afterView:searchContainerView];
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
  [self loadContentFromProvider];
}

- (void)loadContentFromProvider {
  self.categories = [self.dataProvider availableCategories];

  HomeSection *recommendationSection = [self sectionWithIdentifier:HomeSectionIdentifierRecommendation];
  HomeSection *weeklySection = [self sectionWithIdentifier:HomeSectionIdentifierWeekly];

  self.recommendationBaseRecipes = recommendationSection != nil ? recommendationSection.recipes : [self.dataProvider recipesForCategory:nil];
  self.weeklyRecipes = weeklySection != nil ? weeklySection.recipes : @[];
  self.loadingContent = NO;
  self.searchTextField.enabled = YES;
  self.searchState = HomeSearchStateIdle;
  [self applyCurrentPresentationStateAnimated:NO];
}

- (HomeSection *)sectionWithIdentifier:(NSString *)identifier {
  for (HomeSection *section in [self.dataProvider featuredSections]) {
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
    recipes = [self.dataProvider recipesForCategory:self.selectedCategory];
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

  NSString *currentQuery = [self currentSearchQuery];
  BOOL isSearching = currentQuery.length > 0;

  if (!isSearching) {
    self.searchState = HomeSearchStateIdle;
    self.currentSearchResults = @[];
    self.lastCompletedSearchQuery = nil;
  } else if (self.searchState != HomeSearchStateSearching) {
    NSArray<HomeRecipeCard *> *searchResults = [self searchResultsForQuery:currentQuery];
    self.currentSearchResults = searchResults;
    self.lastCompletedSearchQuery = currentQuery;
    self.searchState = searchResults.count > 0 ? HomeSearchStateResults : HomeSearchStateEmpty;
  }

  NSString *recommendationTitle = self.selectedCategory != nil ? [NSString stringWithFormat:@"%@ Picks", self.selectedCategory.title] : @"Recommendation";
  [self.recommendationHeaderView configureWithTitle:recommendationTitle
                                   identifierPrefix:@"home.recommendationHeader"
                                       showsSeeAll:self.filteredRecommendationRecipes.count > 0];

  self.searchResultsHeaderView.seeAllButton.hidden =
      !(self.currentSearchResults.count > 3 && self.searchState == HomeSearchStateResults);
  self.recommendationEmptyStateLabel.text = self.selectedCategory != nil
                                                ? [NSString stringWithFormat:@"No %@ recipes yet. Try another category.", self.selectedCategory.title.lowercaseString]
                                                : @"No recommendations are available right now.";

  [self reloadCollectionContentAnimated:animated];
  [self updateSearchSectionVisibility];
  [self updateRecommendationSectionVisibility];
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
  [self.contentStackView setCustomSpacing:(compactViewport ? 24.0 : 28.0) afterView:self.searchContainerView];
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
    self.searchStatusLabel.text = @"Searching recipes...";
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
  NSArray<UIView *> *viewsToAnimate = @[ self.searchContainerView, self.categoriesSectionView, self.recommendationSectionView, self.weeklySectionView ];
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

  self.currentSearchResults = @[];
  self.lastCompletedSearchQuery = nil;
  self.searchState = HomeSearchStateSearching;
  [self updateSearchSectionVisibility];
  [self updateRecommendationSectionVisibility];

  self.searchDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:MRRHomeSearchDebounceDelay
                                                              target:self
                                                            selector:@selector(handleSearchDebounceTimer:)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void)handleSearchDebounceTimer:(NSTimer *)timer {
  self.searchDebounceTimer = nil;

  [self executeSearchForQuery:[self currentSearchQuery] presentingResultsList:NO];
}

- (NSArray<HomeRecipeCard *> *)searchResultsForQuery:(NSString *)query {
  return [self sortedRecipesFromRecipes:[self.dataProvider searchRecipes:query]];
}

- (void)executeSearchForQuery:(NSString *)query presentingResultsList:(BOOL)presentResultsList {
  NSString *trimmedQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trimmedQuery.length == 0) {
    [self clearSearchState];
    return;
  }

  NSArray<HomeRecipeCard *> *searchResults = [self searchResultsForQuery:trimmedQuery];
  self.currentSearchResults = searchResults;
  self.lastCompletedSearchQuery = trimmedQuery;
  self.searchState = searchResults.count > 0 ? HomeSearchStateResults : HomeSearchStateEmpty;
  [self applyCurrentPresentationStateAnimated:YES];

  if (presentResultsList && searchResults.count > 0) {
    [self presentRecipeListWithTitle:@"Search Results" recipes:searchResults emptyMessage:@"No recipes match that search yet."];
  }
}

- (void)clearSearchState {
  self.searchState = HomeSearchStateIdle;
  self.currentSearchResults = @[];
  self.lastCompletedSearchQuery = nil;
  [self.searchDebounceTimer invalidate];
  self.searchDebounceTimer = nil;
  [self applyCurrentPresentationStateAnimated:YES];
}

- (void)handleFilterButtonTapped:(id)sender {
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Sort Recipes"
                                          message:@"Choose how Home should organize the current recipes."
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

  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
  if (popoverPresentationController != nil) {
    popoverPresentationController.sourceView = self.filterButton;
    popoverPresentationController.sourceRect = self.filterButton.bounds;
  }

  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)applyFilterOption:(HomeFilterOption)filterOption {
  self.currentFilterOption = filterOption;
  [self applyCurrentPresentationStateAnimated:YES];
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

- (void)handleSeeAllButtonTapped:(UIButton *)sender {
  switch (sender.tag) {
    case MRRHomeSectionActionTagSearchResults:
      [self presentRecipeListWithTitle:@"Search Results"
                               recipes:self.currentSearchResults
                          emptyMessage:@"No recipes match that search yet."];
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

  OnboardingRecipeDetail *detail = [self.dataProvider recipeDetailForID:recipeCard.recipeID];
  if (detail == nil) {
    return;
  }

  OnboardingRecipePreview *preview = [self previewForRecipeCard:recipeCard detail:detail];
  OnboardingRecipeDetailViewController *detailViewController =
      [[[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:preview recipeDetail:detail] autorelease];
  detailViewController.delegate = self;
  [self presentRecipeDetailViewController:detailViewController];
}

- (OnboardingRecipePreview *)previewForRecipeCard:(HomeRecipeCard *)recipeCard detail:(OnboardingRecipeDetail *)detail {
  return [[[OnboardingRecipePreview alloc] initWithTitle:recipeCard.title
                                                subtitle:recipeCard.subtitle
                                               assetName:recipeCard.assetName
                                    openFoodFactsBarcode:nil
                                          fallbackDetail:detail] autorelease];
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
    [self executeSearchForQuery:query presentingResultsList:YES];
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
    return MIN(self.currentSearchResults.count, (NSUInteger)3);
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

  [self presentRecipeDetailForCard:recipes[indexPath.item]];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGSize viewportSize = self.view.bounds.size;
  if (collectionView == self.categoryCollectionView) {
    CGFloat width = MRRLayoutClampedFloat(MRRLayoutScaledValue(92.0, viewportSize, MRRLayoutScaleAxisWidth), 82.0, 98.0);
    return CGSizeMake(width, 88.0);
  }

  if (collectionView == self.searchResultsCollectionView) {
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    return CGSizeMake(MAX(width, 220.0), 304.0);
  }

  CGFloat width = MRRLayoutClampedFloat(MRRLayoutScaledValue(206.0, viewportSize, MRRLayoutScaleAxisWidth), 180.0, 220.0);
  CGFloat height = viewportSize.height < 760.0 ? 282.0 : 298.0;
  return CGSizeMake(width, height);
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

- (void)homeRecipeListViewController:(HomeRecipeListViewController *)viewController didSelectRecipeCard:(HomeRecipeCard *)recipeCard {
  [self presentRecipeDetailForCard:recipeCard];
}

#pragma mark - OnboardingRecipeDetailViewControllerDelegate

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController {
  [self dismissPresentedRecipeDetailIfNeeded];
}

- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController {
  [self dismissPresentedRecipeDetailIfNeeded];
}

@end
