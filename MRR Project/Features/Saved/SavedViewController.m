#import "SavedViewController.h"

#import "../../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../../Persistence/SavedRecipes/Models/MRRSavedRecipeSnapshot.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "../Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"

static UIColor *MRRSavedDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRSavedNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRSavedDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRSavedCanvasColor(void) {
  return MRRSavedNamedColor(@"BackgroundColor", [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0],
                            [UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0]);
}

static UIColor *MRRSavedSurfaceColor(void) {
  return MRRSavedNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.14 alpha:1.0]);
}

static UIColor *MRRSavedMutedSurfaceColor(void) {
  return MRRSavedNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0], [UIColor colorWithWhite:0.18 alpha:1.0]);
}

static UIColor *MRRSavedBorderColor(void) {
  return MRRSavedNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0], [UIColor colorWithWhite:0.24 alpha:1.0]);
}

static UIColor *MRRSavedPrimaryTextColor(void) {
  return MRRSavedNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRSavedSecondaryTextColor(void) {
  return MRRSavedNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.45 alpha:1.0], [UIColor colorWithWhite:0.70 alpha:1.0]);
}

static UIColor *MRRSavedHeartBubbleColor(void) {
  return MRRSavedNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRSavedHeartButtonInactiveBackgroundColor(void) {
  UIColor *surfaceColor = MRRSavedNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.18 alpha:1.0]);
  return [surfaceColor colorWithAlphaComponent:UIAccessibilityIsReduceTransparencyEnabled() ? 0.98 : 0.92];
}

static CGFloat const MRRSavedCardPressedAlpha = 0.92;
static CGFloat const MRRSavedCardPressedScale = 0.97;
static CGFloat const MRRSavedCardPressedTranslationY = 4.0;
static CGFloat const MRRSavedButtonPressedAlpha = 0.84;
static CGFloat const MRRSavedButtonPressedScale = 0.96;

static NSString *const MRRSavedRecipeCardIdentifierPrefix = @"saved.recipeCard.";
static NSString *const MRRSavedFavoriteButtonIdentifierPrefix = @"saved.favoriteButton.";

static UIImage *MRRSavedSymbolImage(NSString *systemName, CGFloat pointSize, CGFloat weight) {
  if (@available(iOS 13.0, *)) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:(UIImageSymbolWeight)weight];
    return [UIImage systemImageNamed:systemName withConfiguration:configuration];
  }

  return nil;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *MRRSavedSectionDescriptors(void) {
  static NSArray<NSDictionary<NSString *, NSString *> *> *descriptors = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    descriptors = [[NSArray alloc] initWithObjects:@{@"identifier" : MRRSavedRecipeMealTypeBreakfast, @"title" : @"Breakfast"},
                                                   @{@"identifier" : MRRSavedRecipeMealTypeLunch, @"title" : @"Lunch"},
                                                   @{@"identifier" : MRRSavedRecipeMealTypeDinner, @"title" : @"Dinner"},
                                                   @{@"identifier" : MRRSavedRecipeMealTypeDessert, @"title" : @"Dessert"},
                                                   @{@"identifier" : MRRSavedRecipeMealTypeSnack, @"title" : @"Snack"}, nil];
  });

  return descriptors;
}

@interface SavedViewController () <OnboardingRecipeDetailViewControllerDelegate>

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) id<MRRSavedRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIStackView *sectionsStackView;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *sections;
@property(nonatomic, copy, nullable) NSString *expandedSectionIdentifier;
@property(nonatomic, copy, nullable) NSString *presentedRecipeIdentifier;

- (void)buildViewHierarchy;
- (void)loadSectionsFromStore;
- (void)reloadSections;
- (NSArray<MRRSavedRecipeSnapshot *> *)visibleRecipesForSection:(NSDictionary<NSString *, id> *)section;
- (NSString *)countTextForSection:(NSDictionary<NSString *, id> *)section;
- (UIView *)sectionViewForSection:(NSDictionary<NSString *, id> *)section atIndex:(NSUInteger)index expanded:(BOOL)expanded;
- (UIView *)recipeCardViewForRecipe:(MRRSavedRecipeSnapshot *)recipe;
- (UIButton *)favoriteButtonForRecipe:(MRRSavedRecipeSnapshot *)recipe;
- (UIView *)chipViewWithText:(NSString *)text;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (nullable MRRSavedRecipeSnapshot *)snapshotForRecipeIdentifier:(NSString *)recipeIdentifier;
- (void)applyFavoriteButtonAppearance:(UIButton *)button recipe:(MRRSavedRecipeSnapshot *)recipe;
- (void)configurePressFeedbackForControl:(UIControl *)control;
- (nullable NSString *)recipeIdentifierForCardControl:(UIControl *)control;
- (nullable NSString *)recipeIdentifierForFavoriteButton:(UIButton *)button;
- (nullable NSString *)recipeTitleForIdentifier:(NSString *)recipeIdentifier;
- (NSString *)favoriteButtonAccessibilityLabelForTitle:(NSString *)title;
- (void)presentRecipeDetailForSnapshot:(MRRSavedRecipeSnapshot *)snapshot;
- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController;
- (BOOL)removeRecipeWithIdentifier:(NSString *)recipeIdentifier dismissIfPresented:(BOOL)dismissIfPresented;
- (void)presentPersistenceError:(NSError *)error title:(NSString *)title;
- (void)animateReloadSectionsWithAnnouncement:(nullable NSString *)announcement;
- (void)handleRecipeCardTapped:(UIControl *)sender;
- (void)handleFavoriteButtonTapped:(UIButton *)sender;
- (void)handlePressableControlTouchDown:(UIControl *)sender;
- (void)handlePressableControlTouchUp:(UIControl *)sender;
- (void)handleSectionTapped:(UIControl *)sender;
- (void)savedRecipesStoreDidChange:(NSNotification *)notification;

@end

@implementation SavedViewController

- (instancetype)init {
  return [self initWithSessionUserID:nil savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                    savedRecipesStore:(MRRSavedRecipesStore *)savedRecipesStore
                           syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.title = @"Saved";
    _sessionUserID = [sessionUserID copy];
    _savedRecipesStore = [savedRecipesStore retain];
    _syncEngine = [syncEngine retain];
    _sections = [[NSArray alloc] init];
  }

  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_presentedRecipeIdentifier release];
  [_expandedSectionIdentifier release];
  [_sections release];
  [_sectionsStackView release];
  [_contentView release];
  [_scrollView release];
  [_syncEngine release];
  [_savedRecipesStore release];
  [_sessionUserID release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"saved.view";
  self.view.backgroundColor = MRRSavedCanvasColor();

  if (self.savedRecipesStore != nil) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(savedRecipesStoreDidChange:)
                                                 name:MRRSavedRecipesStoreDidChangeNotification
                                               object:self.savedRecipesStore];
  }

  [self buildViewHierarchy];
  [self loadSectionsFromStore];
  [self reloadSections];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [self loadSectionsFromStore];
  [self reloadSections];
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.delaysContentTouches = NO;
  scrollView.backgroundColor = [UIColor clearColor];
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  contentView.backgroundColor = [UIColor clearColor];
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UIStackView *sectionsStackView = [[[UIStackView alloc] init] autorelease];
  sectionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  sectionsStackView.axis = UILayoutConstraintAxisVertical;
  sectionsStackView.spacing = 28.0;
  sectionsStackView.accessibilityIdentifier = @"saved.sectionsStack";
  [contentView addSubview:sectionsStackView];
  self.sectionsStackView = sectionsStackView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:4.0],
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

    [sectionsStackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:14.0],
    [sectionsStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [sectionsStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [sectionsStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-32.0]
  ]];
}

- (void)loadSectionsFromStore {
  NSMutableDictionary<NSString *, NSMutableArray<MRRSavedRecipeSnapshot *> *> *recipesByIdentifier = [NSMutableDictionary dictionary];
  for (NSDictionary<NSString *, NSString *> *descriptor in MRRSavedSectionDescriptors()) {
    recipesByIdentifier[descriptor[@"identifier"]] = [NSMutableArray array];
  }

  NSArray<MRRSavedRecipeSnapshot *> *snapshots = @[];
  if (self.savedRecipesStore != nil && self.sessionUserID.length > 0) {
    NSError *fetchError = nil;
    NSArray<MRRSavedRecipeSnapshot *> *fetchedSnapshots = [self.savedRecipesStore savedRecipesForUserID:self.sessionUserID error:&fetchError];
    if (fetchError == nil && fetchedSnapshots != nil) {
      snapshots = fetchedSnapshots;
    }
  }

  for (MRRSavedRecipeSnapshot *snapshot in snapshots) {
    NSString *sectionIdentifier = snapshot.sectionIdentifier.length > 0 ? snapshot.sectionIdentifier : MRRSavedRecipeMealTypeSnack;
    NSMutableArray<MRRSavedRecipeSnapshot *> *recipes = recipesByIdentifier[sectionIdentifier];
    if (recipes == nil) {
      recipes = recipesByIdentifier[MRRSavedRecipeMealTypeSnack];
    }
    [recipes addObject:snapshot];
  }

  NSMutableArray<NSDictionary<NSString *, id> *> *sectionModels = [NSMutableArray array];
  NSString *firstNonEmptySectionIdentifier = nil;
  for (NSDictionary<NSString *, NSString *> *descriptor in MRRSavedSectionDescriptors()) {
    NSArray<MRRSavedRecipeSnapshot *> *recipes = recipesByIdentifier[descriptor[@"identifier"]] ?: @[];
    if (firstNonEmptySectionIdentifier == nil && recipes.count > 0) {
      firstNonEmptySectionIdentifier = descriptor[@"identifier"];
    }

    [sectionModels addObject:@{@"identifier" : descriptor[@"identifier"], @"title" : descriptor[@"title"], @"recipes" : recipes}];
  }

  self.sections = sectionModels;
  NSArray<NSString *> *validIdentifiers = [self.sections valueForKey:@"identifier"];
  if (self.expandedSectionIdentifier.length == 0 || ![validIdentifiers containsObject:self.expandedSectionIdentifier]) {
    self.expandedSectionIdentifier = firstNonEmptySectionIdentifier ?: MRRSavedRecipeMealTypeBreakfast;
  }
}

- (void)reloadSections {
  while (self.sectionsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.sectionsStackView.arrangedSubviews.firstObject;
    [self.sectionsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  for (NSUInteger index = 0; index < self.sections.count; index += 1) {
    NSDictionary<NSString *, id> *section = self.sections[index];
    BOOL expanded = [self.expandedSectionIdentifier isEqualToString:section[@"identifier"]];
    [self.sectionsStackView addArrangedSubview:[self sectionViewForSection:section atIndex:index expanded:expanded]];
  }
}

- (NSArray<MRRSavedRecipeSnapshot *> *)visibleRecipesForSection:(NSDictionary<NSString *, id> *)section {
  return section[@"recipes"] ?: @[];
}

- (NSString *)countTextForSection:(NSDictionary<NSString *, id> *)section {
  return [NSString stringWithFormat:@"%lu", (unsigned long)[self visibleRecipesForSection:section].count];
}

- (UIView *)sectionViewForSection:(NSDictionary<NSString *, id> *)section atIndex:(NSUInteger)index expanded:(BOOL)expanded {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.backgroundColor = [UIColor clearColor];
  NSString *countText = [self countTextForSection:section];

  UIControl *headerControl = [[[UIControl alloc] init] autorelease];
  headerControl.translatesAutoresizingMaskIntoConstraints = NO;
  headerControl.tag = index;
  headerControl.accessibilityIdentifier = [NSString stringWithFormat:@"saved.sectionHeader.%@", section[@"identifier"]];
  headerControl.accessibilityLabel = [NSString stringWithFormat:@"%@, %@ saved recipes", section[@"title"], countText];
  headerControl.accessibilityTraits = UIAccessibilityTraitButton | (expanded ? UIAccessibilityTraitSelected : 0);
  [headerControl addTarget:self action:@selector(handleSectionTapped:) forControlEvents:UIControlEventTouchUpInside];
  [containerView addSubview:headerControl];

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:23.0 weight:UIFontWeightSemibold] color:MRRSavedPrimaryTextColor()];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.text = section[@"title"];
  titleLabel.adjustsFontForContentSizeCategory = YES;
  [headerControl addSubview:titleLabel];

  UILabel *countLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium] color:MRRSavedSecondaryTextColor()];
  countLabel.translatesAutoresizingMaskIntoConstraints = NO;
  countLabel.text = countText;
  countLabel.adjustsFontForContentSizeCategory = YES;
  [headerControl addSubview:countLabel];

  UIImageView *chevronImageView =
      [[[UIImageView alloc] initWithImage:MRRSavedSymbolImage(expanded ? @"chevron.up" : @"chevron.down", 16.0, UIFontWeightSemibold)] autorelease];
  chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
  chevronImageView.tintColor = MRRSavedPrimaryTextColor();
  [headerControl addSubview:chevronImageView];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor = MRRSavedBorderColor();
  [containerView addSubview:dividerView];

  NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
    [headerControl.topAnchor constraintEqualToAnchor:containerView.topAnchor],
    [headerControl.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [headerControl.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    [headerControl.heightAnchor constraintGreaterThanOrEqualToConstant:42.0],

    [titleLabel.leadingAnchor constraintEqualToAnchor:headerControl.leadingAnchor],
    [titleLabel.centerYAnchor constraintEqualToAnchor:headerControl.centerYAnchor],

    [countLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:8.0],
    [countLabel.firstBaselineAnchor constraintEqualToAnchor:titleLabel.firstBaselineAnchor],

    [chevronImageView.trailingAnchor constraintEqualToAnchor:headerControl.trailingAnchor],
    [chevronImageView.centerYAnchor constraintEqualToAnchor:headerControl.centerYAnchor],
    [chevronImageView.widthAnchor constraintEqualToConstant:18.0], [chevronImageView.heightAnchor constraintEqualToConstant:18.0],

    [countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevronImageView.leadingAnchor constant:-12.0],

    [dividerView.topAnchor constraintEqualToAnchor:headerControl.bottomAnchor constant:14.0],
    [dividerView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [dividerView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor], [dividerView.heightAnchor constraintEqualToConstant:1.0]
  ]];

  NSArray<MRRSavedRecipeSnapshot *> *recipes = [self visibleRecipesForSection:section];
  if (expanded) {
    UIView *contentContainer = [[[UIView alloc] init] autorelease];
    contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    contentContainer.backgroundColor = [UIColor clearColor];
    [containerView addSubview:contentContainer];

    [constraints addObjectsFromArray:@[
      [contentContainer.topAnchor constraintEqualToAnchor:dividerView.bottomAnchor constant:18.0],
      [contentContainer.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
      [contentContainer.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
      [contentContainer.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];

    if (recipes.count > 0) {
      UIStackView *cardsStackView = [[[UIStackView alloc] init] autorelease];
      cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
      cardsStackView.axis = UILayoutConstraintAxisHorizontal;
      cardsStackView.spacing = 14.0;
      cardsStackView.distribution = UIStackViewDistributionFillEqually;
      [contentContainer addSubview:cardsStackView];

      for (MRRSavedRecipeSnapshot *recipe in recipes) {
        [cardsStackView addArrangedSubview:[self recipeCardViewForRecipe:recipe]];
      }

      [constraints addObjectsFromArray:@[
        [cardsStackView.topAnchor constraintEqualToAnchor:contentContainer.topAnchor],
        [cardsStackView.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
        [cardsStackView.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
        [cardsStackView.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor]
      ]];
    } else {
      UIView *placeholderView = [[[UIView alloc] init] autorelease];
      placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
      placeholderView.backgroundColor = MRRSavedSurfaceColor();
      placeholderView.layer.cornerRadius = 24.0;
      placeholderView.layer.borderWidth = 1.0;
      placeholderView.layer.borderColor = [MRRSavedBorderColor() CGColor];
      [contentContainer addSubview:placeholderView];

      UILabel *placeholderLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium] color:MRRSavedSecondaryTextColor()];
      placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
      placeholderLabel.numberOfLines = 0;
      placeholderLabel.textAlignment = NSTextAlignmentCenter;
      placeholderLabel.text = [NSString stringWithFormat:@"No saved %@ recipes yet.", [section[@"title"] lowercaseString]];
      [placeholderView addSubview:placeholderLabel];

      [constraints addObjectsFromArray:@[
        [placeholderView.topAnchor constraintEqualToAnchor:contentContainer.topAnchor],
        [placeholderView.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
        [placeholderView.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
        [placeholderView.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor],
        [placeholderView.heightAnchor constraintEqualToConstant:108.0],

        [placeholderLabel.centerXAnchor constraintEqualToAnchor:placeholderView.centerXAnchor],
        [placeholderLabel.centerYAnchor constraintEqualToAnchor:placeholderView.centerYAnchor],
        [placeholderLabel.leadingAnchor constraintEqualToAnchor:placeholderView.leadingAnchor constant:24.0],
        [placeholderLabel.trailingAnchor constraintEqualToAnchor:placeholderView.trailingAnchor constant:-24.0]
      ]];
    }
  } else {
    [constraints addObject:[dividerView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]];
  }

  [NSLayoutConstraint activateConstraints:constraints];
  return containerView;
}

- (UIView *)recipeCardViewForRecipe:(MRRSavedRecipeSnapshot *)recipe {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.backgroundColor = [UIColor clearColor];
  cardView.isAccessibilityElement = NO;
  cardView.shouldGroupAccessibilityChildren = NO;

  UIControl *cardControl = [[[UIControl alloc] init] autorelease];
  cardControl.translatesAutoresizingMaskIntoConstraints = NO;
  cardControl.accessibilityIdentifier = [NSString stringWithFormat:@"%@%@", MRRSavedRecipeCardIdentifierPrefix, recipe.recipeID];
  cardControl.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", recipe.title, recipe.durationText, recipe.servingsText];
  cardControl.accessibilityHint = @"Double tap to view recipe details.";
  cardControl.accessibilityTraits = UIAccessibilityTraitButton;
  [cardControl addTarget:self action:@selector(handleRecipeCardTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForControl:cardControl];
  [cardView addSubview:cardControl];

  UIView *imageContainerView = [[[UIView alloc] init] autorelease];
  imageContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  imageContainerView.backgroundColor = MRRSavedMutedSurfaceColor();
  imageContainerView.layer.cornerRadius = 30.0;
  imageContainerView.layer.masksToBounds = YES;
  imageContainerView.isAccessibilityElement = NO;
  imageContainerView.userInteractionEnabled = NO;
  [cardControl addSubview:imageContainerView];

  UIImageView *imageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:recipe.assetName]] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  imageView.layer.cornerRadius = 30.0;
  imageView.isAccessibilityElement = NO;
  [imageContainerView addSubview:imageView];

  UIButton *favoriteButton = [self favoriteButtonForRecipe:recipe];
  [cardView addSubview:favoriteButton];

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold] color:MRRSavedPrimaryTextColor()];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.numberOfLines = 2;
  titleLabel.adjustsFontForContentSizeCategory = YES;
  titleLabel.text = recipe.title;
  titleLabel.isAccessibilityElement = NO;
  [cardControl addSubview:titleLabel];

  UIStackView *chipsStackView = [[[UIStackView alloc] init] autorelease];
  chipsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  chipsStackView.axis = UILayoutConstraintAxisHorizontal;
  chipsStackView.spacing = 8.0;
  chipsStackView.alignment = UIStackViewAlignmentLeading;
  chipsStackView.isAccessibilityElement = NO;
  chipsStackView.userInteractionEnabled = NO;
  [chipsStackView addArrangedSubview:[self chipViewWithText:recipe.durationText]];
  [chipsStackView addArrangedSubview:[self chipViewWithText:recipe.calorieText]];
  [cardControl addSubview:chipsStackView];
  cardView.accessibilityElements = @[ cardControl, favoriteButton ];

  [NSLayoutConstraint activateConstraints:@[
    [cardControl.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [cardControl.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [cardControl.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [cardControl.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [imageContainerView.topAnchor constraintEqualToAnchor:cardControl.topAnchor],
    [imageContainerView.leadingAnchor constraintEqualToAnchor:cardControl.leadingAnchor],
    [imageContainerView.trailingAnchor constraintEqualToAnchor:cardControl.trailingAnchor],
    [imageContainerView.heightAnchor constraintEqualToAnchor:imageContainerView.widthAnchor multiplier:1.20],

    [imageView.topAnchor constraintEqualToAnchor:imageContainerView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:imageContainerView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:imageContainerView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor],

    [favoriteButton.heightAnchor constraintEqualToConstant:46.0],
    [favoriteButton.widthAnchor constraintGreaterThanOrEqualToConstant:84.0],
    [favoriteButton.trailingAnchor constraintEqualToAnchor:imageContainerView.trailingAnchor constant:-12.0],
    [favoriteButton.bottomAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor constant:-12.0],

    [titleLabel.topAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor constant:14.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cardControl.leadingAnchor],
    [titleLabel.trailingAnchor constraintEqualToAnchor:cardControl.trailingAnchor],

    [chipsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [chipsStackView.leadingAnchor constraintEqualToAnchor:cardControl.leadingAnchor],
    [chipsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:cardControl.trailingAnchor],
    [chipsStackView.bottomAnchor constraintEqualToAnchor:cardControl.bottomAnchor]
  ]];

  return cardView;
}

- (UIButton *)favoriteButtonForRecipe:(MRRSavedRecipeSnapshot *)recipe {
  UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
  favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
  favoriteButton.accessibilityIdentifier = [NSString stringWithFormat:@"%@%@", MRRSavedFavoriteButtonIdentifierPrefix, recipe.recipeID];
  favoriteButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 12.0, 10.0, 14.0);
  favoriteButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, -1.0, 0.0, 1.0);
  favoriteButton.titleEdgeInsets = UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0);
  favoriteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  favoriteButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  favoriteButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
  favoriteButton.titleLabel.adjustsFontForContentSizeCategory = YES;
  favoriteButton.titleLabel.adjustsFontSizeToFitWidth = YES;
  favoriteButton.titleLabel.minimumScaleFactor = 0.82;
  favoriteButton.layer.cornerRadius = 23.0;
  favoriteButton.layer.borderWidth = 1.0;
  favoriteButton.layer.shadowColor = [UIColor blackColor].CGColor;
  favoriteButton.layer.shadowOpacity = 0.14f;
  favoriteButton.layer.shadowRadius = 14.0f;
  favoriteButton.layer.shadowOffset = CGSizeMake(0.0, 8.0);
  favoriteButton.clipsToBounds = NO;
  favoriteButton.adjustsImageWhenHighlighted = NO;
  [favoriteButton addTarget:self action:@selector(handleFavoriteButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForControl:favoriteButton];
  [self applyFavoriteButtonAppearance:favoriteButton recipe:recipe];
  return favoriteButton;
}

- (UIView *)chipViewWithText:(NSString *)text {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.backgroundColor = MRRSavedMutedSurfaceColor();
  chipView.layer.cornerRadius = 14.0;
  chipView.isAccessibilityElement = NO;
  chipView.userInteractionEnabled = NO;

  UILabel *label = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRSavedPrimaryTextColor()];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.text = text;
  label.isAccessibilityElement = NO;
  [chipView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [label.topAnchor constraintEqualToAnchor:chipView.topAnchor constant:6.0],
    [label.leadingAnchor constraintEqualToAnchor:chipView.leadingAnchor constant:10.0],
    [label.trailingAnchor constraintEqualToAnchor:chipView.trailingAnchor constant:-10.0],
    [label.bottomAnchor constraintEqualToAnchor:chipView.bottomAnchor constant:-6.0]
  ]];

  return chipView;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.font = font;
  label.textColor = color;
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

- (MRRSavedRecipeSnapshot *)snapshotForRecipeIdentifier:(NSString *)recipeIdentifier {
  if (recipeIdentifier.length == 0) {
    return nil;
  }

  for (NSDictionary<NSString *, id> *section in self.sections) {
    for (MRRSavedRecipeSnapshot *recipe in section[@"recipes"]) {
      if ([recipe.recipeID isEqualToString:recipeIdentifier]) {
        return recipe;
      }
    }
  }

  return nil;
}

- (void)applyFavoriteButtonAppearance:(UIButton *)button recipe:(MRRSavedRecipeSnapshot *)recipe {
  UIColor *accentColor = MRRSavedHeartBubbleColor();
  NSString *recipeTitle = recipe.title.length > 0 ? recipe.title : @"recipe";
  button.selected = YES;
  button.backgroundColor = accentColor;
  button.tintColor = [UIColor whiteColor];
  button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor;
  button.layer.shadowOpacity = 0.16f;
  button.layer.shadowRadius = 16.0f;
  button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
  [button setTitle:@"Saved" forState:UIControlStateNormal];
  [button setTitle:@"Saved" forState:UIControlStateHighlighted];
  [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [button setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.82] forState:UIControlStateHighlighted];
  [button setImage:MRRSavedSymbolImage(@"heart.fill", 17.0, UIFontWeightBold) forState:UIControlStateNormal];
  button.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
  button.accessibilityLabel = [self favoriteButtonAccessibilityLabelForTitle:recipeTitle];
  button.accessibilityValue = @"Saved";
  button.accessibilityHint = @"Double tap to remove this recipe from your saved list.";

  if (@available(iOS 13.0, *)) {
    return;
  }

  button.backgroundColor = MRRSavedHeartButtonInactiveBackgroundColor();
  button.tintColor = accentColor;
  button.layer.borderColor = [accentColor colorWithAlphaComponent:0.24].CGColor;
  [button setImage:nil forState:UIControlStateNormal];
  [button setTitle:@"Remove" forState:UIControlStateNormal];
  [button setTitle:@"Remove" forState:UIControlStateHighlighted];
  [button setTitleColor:accentColor forState:UIControlStateNormal];
  [button setTitleColor:[accentColor colorWithAlphaComponent:0.82] forState:UIControlStateHighlighted];
}

- (void)configurePressFeedbackForControl:(UIControl *)control {
  [control addTarget:self action:@selector(handlePressableControlTouchDown:) forControlEvents:UIControlEventTouchDown];
  [control addTarget:self
                action:@selector(handlePressableControlTouchUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
  [control addTarget:self action:@selector(handlePressableControlTouchDown:) forControlEvents:UIControlEventTouchDragEnter];
}

- (NSString *)recipeIdentifierForCardControl:(UIControl *)control {
  NSString *identifier = control.accessibilityIdentifier;
  if (![identifier hasPrefix:MRRSavedRecipeCardIdentifierPrefix]) {
    return nil;
  }

  return [identifier substringFromIndex:MRRSavedRecipeCardIdentifierPrefix.length];
}

- (NSString *)recipeIdentifierForFavoriteButton:(UIButton *)button {
  NSString *identifier = button.accessibilityIdentifier;
  if (![identifier hasPrefix:MRRSavedFavoriteButtonIdentifierPrefix]) {
    return nil;
  }

  return [identifier substringFromIndex:MRRSavedFavoriteButtonIdentifierPrefix.length];
}

- (NSString *)recipeTitleForIdentifier:(NSString *)recipeIdentifier {
  return [self snapshotForRecipeIdentifier:recipeIdentifier].title;
}

- (NSString *)favoriteButtonAccessibilityLabelForTitle:(NSString *)title {
  return [NSString stringWithFormat:@"Remove %@ from saved recipes", title];
}

- (void)presentRecipeDetailForSnapshot:(MRRSavedRecipeSnapshot *)snapshot {
  if (snapshot == nil || self.presentedViewController != nil) {
    return;
  }

  OnboardingRecipeDetailViewController *detailViewController =
      [[[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:[snapshot recipePreviewRepresentation]
                                                              recipeDetail:[snapshot recipeDetailRepresentation]] autorelease];
  detailViewController.delegate = self;
  detailViewController.showsFavoriteButton = self.sessionUserID.length > 0;
  detailViewController.favoriteSelected = YES;
  detailViewController.favoriteButtonEnabled = YES;
  self.presentedRecipeIdentifier = snapshot.recipeID;
  [self presentRecipeDetailViewController:detailViewController];
}

- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController {
  if (detailViewController == nil) {
    return;
  }

  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:detailViewController] autorelease];
  navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
  navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  [self presentViewController:navigationController animated:YES completion:nil];
}

- (BOOL)removeRecipeWithIdentifier:(NSString *)recipeIdentifier dismissIfPresented:(BOOL)dismissIfPresented {
  if (recipeIdentifier.length == 0 || self.savedRecipesStore == nil || self.sessionUserID.length == 0) {
    return NO;
  }

  NSError *removeError = nil;
  BOOL didRemove = [self.savedRecipesStore removeRecipeForUserID:self.sessionUserID recipeID:recipeIdentifier error:&removeError];
  if (!didRemove || removeError != nil) {
    [self presentPersistenceError:removeError title:@"Couldn't remove recipe"];
    return NO;
  }

  [self.syncEngine requestImmediateSyncForUserID:self.sessionUserID];
  [self loadSectionsFromStore];
  [self animateReloadSectionsWithAnnouncement:@"Removed from saved recipes."];

  if (dismissIfPresented && [self.presentedRecipeIdentifier isEqualToString:recipeIdentifier] && self.presentedViewController != nil) {
    self.presentedRecipeIdentifier = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
  }

  return YES;
}

- (void)presentPersistenceError:(NSError *)error title:(NSString *)title {
  NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"Please try again in a moment.";
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)animateReloadSectionsWithAnnouncement:(NSString *)announcement {
  NSTimeInterval animationDuration = UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.22;
  [UIView transitionWithView:self.sectionsStackView
      duration:animationDuration
      options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
      animations:^{
        [self reloadSections];
        [self.view layoutIfNeeded];
      }
      completion:^(__unused BOOL finished) {
        if (announcement.length > 0 && UIAccessibilityIsVoiceOverRunning()) {
          UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);
        }
      }];
}

- (void)handleRecipeCardTapped:(UIControl *)sender {
  MRRSavedRecipeSnapshot *snapshot = [self snapshotForRecipeIdentifier:[self recipeIdentifierForCardControl:sender]];
  if (snapshot == nil) {
    return;
  }

  [self presentRecipeDetailForSnapshot:snapshot];
}

- (void)handleFavoriteButtonTapped:(UIButton *)sender {
  NSString *recipeIdentifier = [self recipeIdentifierForFavoriteButton:sender];
  [self removeRecipeWithIdentifier:recipeIdentifier dismissIfPresented:NO];
}

- (void)handlePressableControlTouchDown:(UIControl *)sender {
  BOOL isRecipeCard = [sender.accessibilityIdentifier hasPrefix:MRRSavedRecipeCardIdentifierPrefix];
  UIView *targetView = isRecipeCard ? sender.superview : sender;
  CGFloat pressedAlpha = isRecipeCard ? MRRSavedCardPressedAlpha : MRRSavedButtonPressedAlpha;
  CGFloat pressedScale = isRecipeCard ? MRRSavedCardPressedScale : MRRSavedButtonPressedScale;
  if (UIAccessibilityIsReduceMotionEnabled()) {
    targetView.alpha = pressedAlpha;
    return;
  }

  [UIView animateWithDuration:0.14
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     targetView.alpha = pressedAlpha;
                     if (isRecipeCard) {
                       targetView.transform =
                           CGAffineTransformTranslate(CGAffineTransformMakeScale(pressedScale, pressedScale), 0.0, MRRSavedCardPressedTranslationY);
                     } else {
                       targetView.transform = CGAffineTransformMakeScale(pressedScale, pressedScale);
                     }
                   }
                   completion:nil];
}

- (void)handlePressableControlTouchUp:(UIControl *)sender {
  UIView *targetView = [sender.accessibilityIdentifier hasPrefix:MRRSavedRecipeCardIdentifierPrefix] ? sender.superview : sender;
  [UIView animateWithDuration:0.16
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     targetView.alpha = 1.0;
                     targetView.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];
}

- (void)handleSectionTapped:(UIControl *)sender {
  NSDictionary<NSString *, id> *section = self.sections[sender.tag];
  NSString *identifier = section[@"identifier"];
  BOOL willExpand = ![self.expandedSectionIdentifier isEqualToString:identifier];
  self.expandedSectionIdentifier = willExpand ? identifier : nil;
  [self animateReloadSectionsWithAnnouncement:nil];
}

- (void)savedRecipesStoreDidChange:(NSNotification *)notification {
  if (notification.object != nil && notification.object != self.savedRecipesStore) {
    return;
  }

  [self loadSectionsFromStore];
  [self reloadSections];

  if (self.presentedRecipeIdentifier.length > 0 && [self snapshotForRecipeIdentifier:self.presentedRecipeIdentifier] == nil &&
      self.presentedViewController != nil) {
    self.presentedRecipeIdentifier = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

#pragma mark - OnboardingRecipeDetailViewControllerDelegate

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController {
  self.presentedRecipeIdentifier = nil;
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController {
  self.presentedRecipeIdentifier = nil;
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recipeDetailViewController:(OnboardingRecipeDetailViewController *)viewController didRequestFavoriteState:(BOOL)favorite {
  if (favorite) {
    viewController.favoriteSelected = YES;
    return;
  }

  NSString *recipeIdentifier = self.presentedRecipeIdentifier;
  if ([self removeRecipeWithIdentifier:recipeIdentifier dismissIfPresented:YES]) {
    viewController.favoriteSelected = NO;
  }
}

@end
