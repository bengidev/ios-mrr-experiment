#import "HomeRecipeListViewController.h"

#import "HomeCollectionViewCells.h"

static NSString *const MRRHomeRecipeListCellReuseIdentifier = @"MRRHomeRecipeListCell";
static CGFloat const MRRHomeRecipeListCompactTriggerOffset = 68.0;
static CGFloat const MRRHomeRecipeListCompactReleaseOffset = 32.0;
static NSTimeInterval const MRRHomeRecipeListTransitionDuration = 0.28;
static CGFloat const MRRHomeRecipeListTransitionLift = 8.0;

static UIColor *MRRHomeListDynamicColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRHomeListNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeListDynamicColor(lightColor, darkColor);
}

static UIImage *MRRHomeListChevronImage(BOOL expanded) {
  if (@available(iOS 13.0, *)) {
    NSString *symbolName = expanded ? @"chevron.up" : @"chevron.down";
    UIImage *image = [UIImage systemImageNamed:symbolName];
    if (image != nil) {
      UIImageSymbolConfiguration *configuration =
          [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIFontWeightSemibold];
      return [image imageWithConfiguration:configuration];
    }
  }

  return nil;
}

@interface HomeRecipeListViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property(nonatomic, copy) NSString *screenTitle;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *recipes;
@property(nonatomic, copy) NSString *emptyMessage;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UIView *introCardView;
@property(nonatomic, retain) UIView *introCardSurfaceView;
@property(nonatomic, retain) UIStackView *introStateStackView;
@property(nonatomic, retain) UIStackView *expandedIntroStackView;
@property(nonatomic, retain) UILabel *eyebrowLabel;
@property(nonatomic, retain) UILabel *introTitleLabel;
@property(nonatomic, retain) UILabel *introSummaryLabel;
@property(nonatomic, retain) UIView *countBadgeView;
@property(nonatomic, retain) UILabel *countBadgeLabel;
@property(nonatomic, retain) UIButton *compactDropdownButton;
@property(nonatomic, retain) UICollectionView *collectionView;
@property(nonatomic, retain) UILabel *emptyStateLabel;
@property(nonatomic, retain) HomeRecipeCardCell *sizingCell;
@property(nonatomic, assign) BOOL introCompact;
@property(nonatomic, assign) BOOL introDropdownExpanded;

@end

@implementation HomeRecipeListViewController

- (instancetype)initWithScreenTitle:(NSString *)screenTitle recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage {
  NSParameterAssert(screenTitle.length > 0);
  NSParameterAssert(recipes != nil);
  NSParameterAssert(emptyMessage.length > 0);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _screenTitle = [screenTitle copy];
    _recipes = [recipes copy];
    _emptyMessage = [emptyMessage copy];
    _introDropdownExpanded = YES;
  }

  return self;
}

- (void)dealloc {
  [_compactDropdownButton release];
  [_countBadgeLabel release];
  [_countBadgeView release];
  [_introSummaryLabel release];
  [_introTitleLabel release];
  [_eyebrowLabel release];
  [_expandedIntroStackView release];
  [_introStateStackView release];
  [_introCardSurfaceView release];
  [_introCardView release];
  [_contentStackView release];
  [_sizingCell release];
  [_emptyStateLabel release];
  [_collectionView release];
  [_emptyMessage release];
  [_recipes release];
  [_screenTitle release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = self.screenTitle;
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"home.recipeList.view";
  self.view.backgroundColor = MRRHomeListNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0],
                                                    [UIColor colorWithWhite:0.10 alpha:1.0]);

  UIStackView *contentStackView = [[[UIStackView alloc] init] autorelease];
  contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
  contentStackView.axis = UILayoutConstraintAxisVertical;
  contentStackView.spacing = 18.0;
  [self.view addSubview:contentStackView];
  self.contentStackView = contentStackView;

  UIView *introCardView = [[[UIView alloc] init] autorelease];
  introCardView.translatesAutoresizingMaskIntoConstraints = NO;
  introCardView.layer.cornerRadius = 30.0;
  introCardView.layer.shadowColor = [UIColor blackColor].CGColor;
  introCardView.layer.shadowOpacity = 0.08f;
  introCardView.layer.shadowRadius = 18.0f;
  introCardView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
  introCardView.backgroundColor = [UIColor clearColor];
  introCardView.accessibilityIdentifier = @"home.recipeList.introCardView";
  [contentStackView addArrangedSubview:introCardView];
  self.introCardView = introCardView;

  UIView *introCardSurfaceView = [[[UIView alloc] init] autorelease];
  introCardSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
  introCardSurfaceView.layer.cornerRadius = 30.0;
  introCardSurfaceView.layer.borderWidth = 1.0;
  introCardSurfaceView.layer.borderColor = MRRHomeListNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.24 alpha:1.0]).CGColor;
  introCardSurfaceView.backgroundColor = MRRHomeListNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0],
                                                               [UIColor colorWithWhite:0.14 alpha:1.0]);
  introCardSurfaceView.clipsToBounds = YES;
  [introCardView addSubview:introCardSurfaceView];
  self.introCardSurfaceView = introCardSurfaceView;

  UIStackView *introStateStackView = [[[UIStackView alloc] init] autorelease];
  introStateStackView.translatesAutoresizingMaskIntoConstraints = NO;
  introStateStackView.axis = UILayoutConstraintAxisVertical;
  introStateStackView.spacing = 12.0;
  introStateStackView.clipsToBounds = YES;
  introStateStackView.isAccessibilityElement = NO;
  [introCardSurfaceView addSubview:introStateStackView];
  self.introStateStackView = introStateStackView;

  UIButton *compactDropdownButton = [UIButton buttonWithType:UIButtonTypeSystem];
  compactDropdownButton.translatesAutoresizingMaskIntoConstraints = NO;
  compactDropdownButton.hidden = YES;
  compactDropdownButton.layer.cornerRadius = 18.0;
  compactDropdownButton.layer.borderWidth = 1.0;
  compactDropdownButton.layer.borderColor = MRRHomeListNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0],
                                                                  [UIColor colorWithWhite:0.24 alpha:1.0]).CGColor;
  compactDropdownButton.backgroundColor = MRRHomeListNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0],
                                                                [UIColor colorWithWhite:0.18 alpha:1.0]);
  compactDropdownButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
  compactDropdownButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
  compactDropdownButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
  compactDropdownButton.titleLabel.adjustsFontForContentSizeCategory = YES;
  compactDropdownButton.titleLabel.adjustsFontSizeToFitWidth = YES;
  compactDropdownButton.titleLabel.minimumScaleFactor = 0.8;
  compactDropdownButton.tintColor = MRRHomeListNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                          [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
  [compactDropdownButton setTitleColor:MRRHomeListNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                             [UIColor colorWithWhite:0.96 alpha:1.0])
                              forState:UIControlStateNormal];
  compactDropdownButton.accessibilityIdentifier = @"home.recipeList.dropdownButton";
  [compactDropdownButton addTarget:self
                            action:@selector(handleCompactDropdownButtonTapped:)
                  forControlEvents:UIControlEventTouchUpInside];
  [introStateStackView addArrangedSubview:compactDropdownButton];
  self.compactDropdownButton = compactDropdownButton;

  UIStackView *expandedIntroStackView = [[[UIStackView alloc] init] autorelease];
  expandedIntroStackView.translatesAutoresizingMaskIntoConstraints = NO;
  expandedIntroStackView.axis = UILayoutConstraintAxisVertical;
  expandedIntroStackView.spacing = 10.0;
  expandedIntroStackView.isAccessibilityElement = NO;
  [introStateStackView addArrangedSubview:expandedIntroStackView];
  self.expandedIntroStackView = expandedIntroStackView;

  UIStackView *topRowStackView = [[[UIStackView alloc] init] autorelease];
  topRowStackView.translatesAutoresizingMaskIntoConstraints = NO;
  topRowStackView.axis = UILayoutConstraintAxisHorizontal;
  topRowStackView.alignment = UIStackViewAlignmentCenter;
  topRowStackView.spacing = 12.0;
  [expandedIntroStackView addArrangedSubview:topRowStackView];

  UILabel *eyebrowLabel = [[[UILabel alloc] init] autorelease];
  eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
  eyebrowLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
  eyebrowLabel.adjustsFontForContentSizeCategory = YES;
  eyebrowLabel.textColor = MRRHomeListNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                 [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
  eyebrowLabel.text = @"Curated list";
  eyebrowLabel.accessibilityIdentifier = @"home.recipeList.eyebrowLabel";
  [topRowStackView addArrangedSubview:eyebrowLabel];
  self.eyebrowLabel = eyebrowLabel;

  UIView *countBadgeView = [[[UIView alloc] init] autorelease];
  countBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
  countBadgeView.layer.cornerRadius = 14.0;
  countBadgeView.backgroundColor = MRRHomeListNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0],
                                                         [UIColor colorWithWhite:0.18 alpha:1.0]);
  countBadgeView.accessibilityIdentifier = @"home.recipeList.countBadgeView";
  [topRowStackView addArrangedSubview:countBadgeView];
  self.countBadgeView = countBadgeView;

  UILabel *countBadgeLabel = [[[UILabel alloc] init] autorelease];
  countBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
  countBadgeLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
  countBadgeLabel.adjustsFontForContentSizeCategory = YES;
  countBadgeLabel.textColor = MRRHomeListNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                    [UIColor colorWithWhite:0.72 alpha:1.0]);
  countBadgeLabel.textAlignment = NSTextAlignmentCenter;
  countBadgeLabel.text = [NSString stringWithFormat:@"%lu items", (unsigned long)self.recipes.count];
  countBadgeLabel.accessibilityIdentifier = @"home.recipeList.countBadgeLabel";
  [countBadgeView addSubview:countBadgeLabel];
  self.countBadgeLabel = countBadgeLabel;

  UILabel *introTitleLabel = [[[UILabel alloc] init] autorelease];
  introTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  introTitleLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
  introTitleLabel.adjustsFontForContentSizeCategory = YES;
  introTitleLabel.textColor = MRRHomeListNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                    [UIColor colorWithWhite:0.96 alpha:1.0]);
  introTitleLabel.numberOfLines = 0;
  introTitleLabel.text = self.screenTitle;
  introTitleLabel.accessibilityIdentifier = @"home.recipeList.titleLabel";
  [expandedIntroStackView addArrangedSubview:introTitleLabel];
  self.introTitleLabel = introTitleLabel;

  UILabel *introSummaryLabel = [[[UILabel alloc] init] autorelease];
  introSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
  introSummaryLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
  introSummaryLabel.adjustsFontForContentSizeCategory = YES;
  introSummaryLabel.textColor = MRRHomeListNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                      [UIColor colorWithWhite:0.74 alpha:1.0]);
  introSummaryLabel.numberOfLines = 0;
  introSummaryLabel.text = [self introSummaryText];
  introSummaryLabel.accessibilityIdentifier = @"home.recipeList.summaryLabel";
  [expandedIntroStackView addArrangedSubview:introSummaryLabel];
  self.introSummaryLabel = introSummaryLabel;

  [countBadgeView.heightAnchor constraintEqualToConstant:28.0].active = YES;
  [countBadgeView.widthAnchor constraintGreaterThanOrEqualToConstant:72.0].active = YES;
  [compactDropdownButton.heightAnchor constraintEqualToConstant:50.0].active = YES;

  [NSLayoutConstraint activateConstraints:@[
    [introCardSurfaceView.topAnchor constraintEqualToAnchor:introCardView.topAnchor],
    [introCardSurfaceView.leadingAnchor constraintEqualToAnchor:introCardView.leadingAnchor],
    [introCardSurfaceView.trailingAnchor constraintEqualToAnchor:introCardView.trailingAnchor],
    [introCardSurfaceView.bottomAnchor constraintEqualToAnchor:introCardView.bottomAnchor],

    [introStateStackView.topAnchor constraintEqualToAnchor:introCardSurfaceView.topAnchor constant:18.0],
    [introStateStackView.leadingAnchor constraintEqualToAnchor:introCardSurfaceView.leadingAnchor constant:18.0],
    [introStateStackView.trailingAnchor constraintEqualToAnchor:introCardSurfaceView.trailingAnchor constant:-18.0],
    [introStateStackView.bottomAnchor constraintEqualToAnchor:introCardSurfaceView.bottomAnchor constant:-18.0],

    [countBadgeLabel.leadingAnchor constraintEqualToAnchor:countBadgeView.leadingAnchor constant:12.0],
    [countBadgeLabel.trailingAnchor constraintEqualToAnchor:countBadgeView.trailingAnchor constant:-12.0],
    [countBadgeLabel.topAnchor constraintEqualToAnchor:countBadgeView.topAnchor constant:5.0],
    [countBadgeLabel.bottomAnchor constraintEqualToAnchor:countBadgeView.bottomAnchor constant:-5.0]
  ]];

  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.minimumLineSpacing = 20.0;
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.alwaysBounceVertical = YES;
  collectionView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 28.0, 0.0);
  collectionView.accessibilityIdentifier = @"home.recipeList.collectionView";
  collectionView.accessibilityLabel = self.screenTitle;
  collectionView.dataSource = self;
  collectionView.delegate = self;
  [collectionView registerClass:[HomeRecipeCardCell class] forCellWithReuseIdentifier:MRRHomeRecipeListCellReuseIdentifier];
  [contentStackView addArrangedSubview:collectionView];
  self.collectionView = collectionView;

  self.sizingCell = [[[HomeRecipeCardCell alloc] initWithFrame:CGRectZero] autorelease];

  UILabel *emptyStateLabel = [[[UILabel alloc] init] autorelease];
  emptyStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
  emptyStateLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  emptyStateLabel.adjustsFontForContentSizeCategory = YES;
  emptyStateLabel.numberOfLines = 0;
  emptyStateLabel.textAlignment = NSTextAlignmentCenter;
  emptyStateLabel.textColor = MRRHomeListNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                    [UIColor colorWithWhite:0.74 alpha:1.0]);
  emptyStateLabel.text = self.emptyMessage;
  emptyStateLabel.hidden = self.recipes.count > 0;
  emptyStateLabel.accessibilityIdentifier = @"home.recipeList.emptyStateLabel";
  emptyStateLabel.isAccessibilityElement = YES;
  emptyStateLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
  [self.view addSubview:emptyStateLabel];
  self.emptyStateLabel = emptyStateLabel;

  [NSLayoutConstraint activateConstraints:@[
    [contentStackView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
    [contentStackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
    [contentStackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
    [contentStackView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [collectionView.heightAnchor constraintGreaterThanOrEqualToConstant:340.0],

    [emptyStateLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [emptyStateLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    [emptyStateLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [emptyStateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
  ]];

  [self updateIntroPresentationAnimated:NO];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  self.introCardView.layer.shadowPath =
      [UIBezierPath bezierPathWithRoundedRect:self.introCardView.bounds cornerRadius:self.introCardSurfaceView.layer.cornerRadius].CGPath;
  [self updateIntroPresentationForScrollOffset:self.collectionView.contentOffset.y animated:NO];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return self.recipes.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  HomeRecipeCardCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:MRRHomeRecipeListCellReuseIdentifier forIndexPath:indexPath];
  if (indexPath.item < self.recipes.count) {
    [cell configureWithRecipeCard:self.recipes[indexPath.item] style:HomeRecipeCardCellStyleList];
  }
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - 4.0;
  CGFloat targetWidth = MAX(availableWidth, 220.0);

  if (indexPath.item >= self.recipes.count) {
    return CGSizeMake(targetWidth, 320.0);
  }

  HomeRecipeCardCell *sizingCell = self.sizingCell;
  if (sizingCell == nil) {
    sizingCell = [[[HomeRecipeCardCell alloc] initWithFrame:CGRectZero] autorelease];
    self.sizingCell = sizingCell;
  }

  [sizingCell configureWithRecipeCard:self.recipes[indexPath.item] style:HomeRecipeCardCellStyleList];
  sizingCell.bounds = CGRectMake(0.0, 0.0, targetWidth, 1200.0);
  [sizingCell setNeedsLayout];
  [sizingCell layoutIfNeeded];

  CGSize fittingSize = [sizingCell.contentView
      systemLayoutSizeFittingSize:CGSizeMake(targetWidth, UILayoutFittingCompressedSize.height)
    withHorizontalFittingPriority:UILayoutPriorityRequired
          verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
  CGFloat height = ceil(MAX(fittingSize.height, 340.0));
  return CGSizeMake(targetWidth, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  return UIEdgeInsetsMake(0.0, 16.0, 28.0, 16.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.item >= self.recipes.count) {
    return;
  }

  UICollectionViewCell *selectedCell = [collectionView cellForItemAtIndexPath:indexPath];
  UIView *sourceView = selectedCell.contentView ?: selectedCell;
  [self.delegate homeRecipeListViewController:self didSelectRecipeCard:self.recipes[indexPath.item] sourceView:sourceView];
}

- (BOOL)isWeeklyIntroScreen {
  return [self.screenTitle isEqualToString:@"Recipes Of The Week"];
}

- (BOOL)isRecommendationIntroScreen {
  return [self.screenTitle isEqualToString:@"Recommendation"];
}

- (BOOL)isRecommendationPicksIntroScreen {
  return [self isRecommendationIntroScreen] || [self.screenTitle hasSuffix:@"Picks"];
}

- (BOOL)usesCollapsibleCuratedIntro {
  if (self.recipes.count == 0) {
    return NO;
  }

  return [self isWeeklyIntroScreen] || [self isRecommendationPicksIntroScreen];
}

- (NSString *)compactDropdownSummaryText {
  NSUInteger count = self.recipes.count;
  if ([self isWeeklyIntroScreen]) {
    return [NSString stringWithFormat:@"%lu %@", (unsigned long)count, (count == 1 ? @"weekend pick" : @"weekend picks")];
  }

  if ([self isRecommendationPicksIntroScreen]) {
    return [NSString stringWithFormat:@"%lu %@", (unsigned long)count, (count == 1 ? @"curated pick" : @"curated picks")];
  }

  return [NSString stringWithFormat:@"%lu %@", (unsigned long)count, (count == 1 ? @"item" : @"items")];
}

- (void)updateIntroPresentationAnimated:(BOOL)animated {
  BOOL usesCollapsibleCuratedIntro = [self usesCollapsibleCuratedIntro];
  BOOL showsCompactButton = usesCollapsibleCuratedIntro && self.introCompact;
  BOOL showsExpandedIntro = !usesCollapsibleCuratedIntro || !self.introCompact || self.introDropdownExpanded;
  BOOL wasShowingCompactButton = !self.compactDropdownButton.hidden;
  BOOL wasShowingExpandedIntro = !self.expandedIntroStackView.hidden;
  BOOL revealsCompactButton = showsCompactButton && !wasShowingCompactButton;
  BOOL revealsExpandedIntro = showsExpandedIntro && !wasShowingExpandedIntro;
  [self.compactDropdownButton setTitle:[self compactDropdownSummaryText] forState:UIControlStateNormal];
  [self.compactDropdownButton setImage:MRRHomeListChevronImage(showsExpandedIntro) forState:UIControlStateNormal];
  self.compactDropdownButton.accessibilityLabel =
      showsCompactButton ? [NSString stringWithFormat:@"%@, %@", self.screenTitle, (showsExpandedIntro ? @"Collapse summary" : @"Expand summary")] : nil;
  self.compactDropdownButton.accessibilityHint = showsCompactButton ? @"Double tap to toggle the list summary." : nil;
  [self.compactDropdownButton.layer removeAllAnimations];
  [self.expandedIntroStackView.layer removeAllAnimations];
  [self.introCardView.layer removeAllAnimations];
  [self.introCardSurfaceView.layer removeAllAnimations];
  self.compactDropdownButton.alpha = 1.0;
  self.expandedIntroStackView.alpha = 1.0;
  self.compactDropdownButton.transform = CGAffineTransformIdentity;
  self.expandedIntroStackView.transform = CGAffineTransformIdentity;
  BOOL shouldAnimateTransition = animated && !UIAccessibilityIsReduceMotionEnabled() && self.view.window != nil;
  if (shouldAnimateTransition) {
    [self.view layoutIfNeeded];
  }

  self.compactDropdownButton.hidden = !showsCompactButton;
  self.expandedIntroStackView.hidden = !showsExpandedIntro;
  if (revealsCompactButton) {
    self.compactDropdownButton.hidden = NO;
    self.compactDropdownButton.alpha = 0.0;
    self.compactDropdownButton.transform = CGAffineTransformMakeTranslation(0.0, -MRRHomeRecipeListTransitionLift * 0.5);
  }
  if (revealsExpandedIntro) {
    self.expandedIntroStackView.hidden = NO;
    self.expandedIntroStackView.alpha = 0.0;
    self.expandedIntroStackView.transform = CGAffineTransformMakeTranslation(0.0, MRRHomeRecipeListTransitionLift);
  }

  CGFloat cornerRadius = (showsCompactButton && !showsExpandedIntro) ? 24.0 : 30.0;
  CGFloat shadowRadius = (showsCompactButton && !showsExpandedIntro) ? 14.0f : 18.0f;
  CGSize shadowOffset = (showsCompactButton && !showsExpandedIntro) ? CGSizeMake(0.0, 6.0) : CGSizeMake(0.0, 10.0);
  if (!shouldAnimateTransition) {
    self.introCardView.layer.cornerRadius = cornerRadius;
    self.introCardSurfaceView.layer.cornerRadius = cornerRadius;
    self.introCardView.layer.shadowRadius = shadowRadius;
    self.introCardView.layer.shadowOffset = shadowOffset;
    [self.view layoutIfNeeded];
    self.introCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.introCardView.bounds cornerRadius:cornerRadius].CGPath;
    return;
  }

  [UIView animateWithDuration:MRRHomeRecipeListTransitionDuration
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     self.introCardView.layer.cornerRadius = cornerRadius;
                     self.introCardSurfaceView.layer.cornerRadius = cornerRadius;
                     self.introCardView.layer.shadowRadius = shadowRadius;
                     self.introCardView.layer.shadowOffset = shadowOffset;
                     if (showsCompactButton) {
                       self.compactDropdownButton.alpha = 1.0;
                       self.compactDropdownButton.transform = CGAffineTransformIdentity;
                     }
                     if (showsExpandedIntro) {
                       self.expandedIntroStackView.alpha = 1.0;
                       self.expandedIntroStackView.transform = CGAffineTransformIdentity;
                     }
                     [self.view layoutIfNeeded];
                     self.introCardView.layer.shadowPath =
                         [UIBezierPath bezierPathWithRoundedRect:self.introCardView.bounds cornerRadius:cornerRadius].CGPath;
                   }
                   completion:^(BOOL finished) {
                     self.compactDropdownButton.alpha = 1.0;
                     self.expandedIntroStackView.alpha = 1.0;
                     self.compactDropdownButton.transform = CGAffineTransformIdentity;
                     self.expandedIntroStackView.transform = CGAffineTransformIdentity;
                     self.compactDropdownButton.hidden = !showsCompactButton;
                     self.expandedIntroStackView.hidden = !showsExpandedIntro;
                     self.introCardView.layer.shadowPath =
                         [UIBezierPath bezierPathWithRoundedRect:self.introCardView.bounds cornerRadius:cornerRadius].CGPath;
                   }];
}

- (void)updateIntroPresentationForScrollOffset:(CGFloat)scrollOffset animated:(BOOL)animated {
  if (![self usesCollapsibleCuratedIntro]) {
    if (self.introCompact) {
      self.introCompact = NO;
      self.introDropdownExpanded = YES;
      [self updateIntroPresentationAnimated:animated];
    }
    return;
  }

  CGFloat verticalOffset = MAX(scrollOffset + self.collectionView.adjustedContentInset.top, 0.0);
  CGFloat compactThreshold = self.introCompact ? MRRHomeRecipeListCompactReleaseOffset : MRRHomeRecipeListCompactTriggerOffset;
  BOOL shouldCompact = verticalOffset >= compactThreshold;
  if (shouldCompact == self.introCompact) {
    return;
  }

  self.introCompact = shouldCompact;
  self.introDropdownExpanded = !shouldCompact;
  [self updateIntroPresentationAnimated:animated];
}

- (void)handleCompactDropdownButtonTapped:(id)sender {
  if (![self usesCollapsibleCuratedIntro] || !self.introCompact) {
    return;
  }

  self.introDropdownExpanded = !self.introDropdownExpanded;
  [self updateIntroPresentationAnimated:YES];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (scrollView != self.collectionView) {
    return;
  }

  [self updateIntroPresentationForScrollOffset:scrollView.contentOffset.y animated:YES];
}

- (NSString *)introSummaryText {
  if (self.recipes.count == 0) {
    return self.emptyMessage;
  }

  if ([self.screenTitle isEqualToString:@"Search Results"]) {
    return @"Matching recipes, arranged for calmer scanning and quicker decisions.";
  }

  if ([self isWeeklyIntroScreen]) {
    return @"A sharper look at the week's highlights, with more breathing room.";
  }

  if ([self isRecommendationIntroScreen]) {
    return @"A curated selection with more breathing room and clearer hierarchy.";
  }

  if ([self.screenTitle hasSuffix:@"Picks"]) {
    return @"Curated picks, presented with a quieter editorial rhythm.";
  }

  return @"A curated selection with more breathing room and clearer hierarchy.";
}

@end
