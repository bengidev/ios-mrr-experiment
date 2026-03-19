#import "OnboardingRecipeDetailViewController.h"

#import "../../../../Layout/MRRLiquidGlassStyling.h"
#import "../../../../Layout/MRRLayoutScaling.h"

static CGFloat const MRRRecipeDetailHeaderHeight = 292.0;
static CGFloat const MRRRecipeDetailButtonPressedScale = 0.97;
static CGFloat const MRRRecipeDetailButtonPressedAlpha = 0.88;

static UIColor *MRRDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRDynamicFallbackColor(lightColor, darkColor);
}

static UIView *MRRSkeletonBlockView(CGFloat height, NSString *accessibilityIdentifier) {
  UIView *view = [[[UIView alloc] init] autorelease];
  view.translatesAutoresizingMaskIntoConstraints = NO;
  view.backgroundColor = [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.78 alpha:1.0],
                                        [UIColor colorWithWhite:0.28 alpha:1.0]) colorWithAlphaComponent:0.32];
  view.layer.cornerRadius = height / 2.0;
  view.accessibilityIdentifier = accessibilityIdentifier;
  [NSLayoutConstraint activateConstraints:@[[view.heightAnchor constraintEqualToConstant:height]]];
  return view;
}

static void MRROnboardingDetailCompleteOnMainThread(void (^block)(void)) {
  if ([NSThread isMainThread]) {
    block();
    return;
  }

  dispatch_async(dispatch_get_main_queue(), block);
}

@interface OnboardingRecipeDetailViewController () <UIScrollViewDelegate>

@property(nonatomic, retain, readwrite) OnboardingRecipePreview *recipePreview;
@property(nonatomic, retain, readwrite, nullable) OnboardingRecipeDetail *recipeDetail;
@property(nonatomic, assign, readwrite, getter=isLoading) BOOL loading;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIImageView *heroImageView;
@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UIButton *closeButton;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UIView *headerCardView;
@property(nonatomic, retain) UILabel *subtitleLabel;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UIView *summaryCardView;
@property(nonatomic, retain) UILabel *summaryEyebrowLabel;
@property(nonatomic, retain) UILabel *summaryLabel;
@property(nonatomic, retain) UIButton *summaryToggleButton;
@property(nonatomic, retain) UIView *ingredientsSectionCardView;
@property(nonatomic, retain) UIView *ingredientsSectionBodyView;
@property(nonatomic, retain) UIView *ingredientsSectionDividerView;
@property(nonatomic, retain) UIButton *ingredientsToggleButton;
@property(nonatomic, retain) UIView *instructionsSectionCardView;
@property(nonatomic, retain) UIView *instructionsSectionBodyView;
@property(nonatomic, retain) UIView *instructionsSectionDividerView;
@property(nonatomic, retain) UIButton *instructionsToggleButton;
@property(nonatomic, retain) UIView *toolsSectionCardView;
@property(nonatomic, retain) UIView *toolsSectionBodyView;
@property(nonatomic, retain) UIView *toolsSectionDividerView;
@property(nonatomic, retain) UIButton *toolsToggleButton;
@property(nonatomic, retain) UIView *tagsSectionCardView;
@property(nonatomic, retain) UIView *tagsSectionBodyView;
@property(nonatomic, retain) UIView *tagsSectionDividerView;
@property(nonatomic, retain) UIButton *tagsToggleButton;
@property(nonatomic, retain) UIButton *startButton;
@property(nonatomic, retain) NSLayoutConstraint *cardTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *cardLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *cardTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *cardBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *heroContainerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *heroImageTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *heroImageHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *closeButtonTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *closeButtonTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *closeButtonWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint *closeButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *contentStackTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *contentStackLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *contentStackTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *contentStackBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *startButtonHeightConstraint;
@property(nonatomic, assign) NSUInteger heroImageRequestToken;
@property(nonatomic, assign) CGFloat lastRenderedTagViewportWidth;
@property(nonatomic, assign) BOOL summaryExpanded;
@property(nonatomic, assign) BOOL ingredientsExpanded;
@property(nonatomic, assign) BOOL instructionsExpanded;
@property(nonatomic, assign) BOOL toolsExpanded;
@property(nonatomic, assign) BOOL tagsExpanded;

- (void)buildViewHierarchy;
- (void)reloadContentStack;
- (void)configureStartButtonEnabled:(BOOL)enabled;
- (BOOL)usesSheetPresentationChrome;
- (UILabel *)buildLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UILabel *)sectionTitleLabelWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)recipeSurfaceCardViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier prominent:(BOOL)prominent;
- (nullable UIView *)sectionIconViewWithSystemName:(NSString *)systemName;
- (UIView *)titleHeaderCardView;
- (UIView *)titleHeaderSkeletonCardView;
- (UIView *)metadataChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)ingredientGridViewForIngredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients;
- (UIView *)ingredientChipWithIngredient:(OnboardingRecipeIngredient *)ingredient accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)ingredientsSectionViewForIngredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients;
- (UIView *)ingredientsSkeletonSectionView;
- (void)refreshIngredientsSectionAnimated:(BOOL)animated;
- (void)updateIngredientsToggleButtonAppearance;
- (UIView *)instructionsStackViewForInstructions:(NSArray<OnboardingRecipeInstruction *> *)instructions;
- (UIView *)instructionRowForInstruction:(OnboardingRecipeInstruction *)instruction index:(NSUInteger)index;
- (UIView *)instructionsSectionViewForInstructions:(NSArray<OnboardingRecipeInstruction *> *)instructions;
- (UIView *)instructionsSkeletonSectionView;
- (void)refreshInstructionsSectionAnimated:(BOOL)animated;
- (void)updateInstructionsToggleButtonAppearance;
- (UIView *)toolsSectionViewForTools:(NSArray<NSString *> *)tools;
- (UIView *)toolRowViewWithText:(NSString *)toolText index:(NSUInteger)index;
- (void)refreshToolsSectionAnimated:(BOOL)animated;
- (void)updateToolsToggleButtonAppearance;
- (UIView *)tagsSectionViewForTags:(NSArray<NSString *> *)tags;
- (UIView *)tagRowsViewForTags:(NSArray<NSString *> *)tags;
- (UIView *)tagChipViewWithText:(NSString *)tagText;
- (void)refreshTagsSectionAnimated:(BOOL)animated;
- (void)updateTagsToggleButtonAppearance;
- (void)refreshTagSectionLayoutIfNeededForViewportWidth:(CGFloat)viewportWidth;
- (UIView *)summarySectionViewForRecipeDetail:(OnboardingRecipeDetail *)recipeDetail;
- (UIView *)summarySkeletonSectionView;
- (BOOL)shouldAllowSummaryExpansionForText:(NSString *)summaryText;
- (void)refreshSummaryExpansionStateAnimated:(BOOL)animated;
- (void)updateSummaryToggleButtonAppearance;
- (UIView *)productContextViewForProductContext:(OnboardingRecipeProductContext *)productContext;
- (UIView *)sourceAttributionViewForRecipeDetail:(OnboardingRecipeDetail *)recipeDetail;
- (nullable UIView *)debugOriginBadgeViewIfNeeded;
- (NSString *)detailIdentifierForSuffix:(NSString *)suffix;
- (void)didTapCloseButton;
- (void)didTapStartCookingButton;
- (void)didTapIngredientsToggleButton;
- (void)didTapInstructionsToggleButton;
- (void)didTapToolsToggleButton;
- (void)didTapTagsToggleButton;
- (void)didTapSummaryToggleButton;
- (void)didTapSourceButton;
- (void)refreshHeroImage;
- (void)configurePressFeedbackForButton:(UIButton *)button;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;
- (void)updateLayoutMetricsIfNeeded;
- (CGSize)layoutViewportSize;
- (BOOL)usesNavigationPresentationChrome;

@end

@implementation OnboardingRecipeDetailViewController

- (instancetype)initWithRecipePreview:(OnboardingRecipePreview *)recipePreview loading:(BOOL)loading {
  NSParameterAssert(recipePreview != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _recipePreview = [recipePreview retain];
    _loading = loading;
    _debugOrigin = OnboardingRecipeDetailDebugOriginUnknown;
    if (!loading) {
      _recipeDetail = [recipePreview.fallbackDetail retain];
    }
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  }

  return self;
}

- (instancetype)initWithRecipePreview:(OnboardingRecipePreview *)recipePreview recipeDetail:(OnboardingRecipeDetail *)recipeDetail {
  NSParameterAssert(recipeDetail != nil);

  self = [self initWithRecipePreview:recipePreview loading:NO];
  if (self) {
    [_recipeDetail release];
    _recipeDetail = [recipeDetail retain];
  }

  return self;
}

- (void)dealloc {
  [_startButtonHeightConstraint release];
  [_contentStackBottomConstraint release];
  [_contentStackTrailingConstraint release];
  [_contentStackLeadingConstraint release];
  [_contentStackTopConstraint release];
  [_closeButtonHeightConstraint release];
  [_closeButtonWidthConstraint release];
  [_closeButtonTrailingConstraint release];
  [_closeButtonTopConstraint release];
  [_heroImageHeightConstraint release];
  [_heroImageTopConstraint release];
  [_heroContainerHeightConstraint release];
  [_cardBottomConstraint release];
  [_cardTrailingConstraint release];
  [_cardLeadingConstraint release];
  [_cardTopConstraint release];
  [_startButton release];
  [_instructionsSectionCardView release];
  [_instructionsToggleButton release];
  [_instructionsSectionDividerView release];
  [_instructionsSectionBodyView release];
  [_toolsToggleButton release];
  [_toolsSectionDividerView release];
  [_toolsSectionBodyView release];
  [_toolsSectionCardView release];
  [_tagsToggleButton release];
  [_tagsSectionDividerView release];
  [_tagsSectionBodyView release];
  [_tagsSectionCardView release];
  [_ingredientsToggleButton release];
  [_ingredientsSectionDividerView release];
  [_ingredientsSectionBodyView release];
  [_ingredientsSectionCardView release];
  [_summaryToggleButton release];
  [_summaryLabel release];
  [_summaryEyebrowLabel release];
  [_summaryCardView release];
  [_titleLabel release];
  [_subtitleLabel release];
  [_headerCardView release];
  [_contentStackView release];
  [_closeButton release];
  [_cardView release];
  [_heroImageView release];
  [_scrollView release];
  [_recipeDetail release];
  [_recipePreview release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if ([self usesNavigationPresentationChrome]) {
    self.view.backgroundColor = MRRNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.08 alpha:1.0]);
  } else {
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.58];
  }
  self.view.accessibilityIdentifier = @"onboarding.recipeDetail.view";

  [self buildViewHierarchy];
  [self reloadContentStack];
  [self refreshHeroImage];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  if ([self usesNavigationPresentationChrome]) {
    [self.navigationController setNavigationBarHidden:YES animated:animated];
  }
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateLayoutMetricsIfNeeded];
}

- (void)updateWithRecipeDetail:(OnboardingRecipeDetail *)recipeDetail {
  [self updateWithRecipeDetail:recipeDetail debugOrigin:self.debugOrigin];
}

- (void)updateWithRecipeDetail:(OnboardingRecipeDetail *)recipeDetail debugOrigin:(OnboardingRecipeDetailDebugOrigin)debugOrigin {
  NSParameterAssert(recipeDetail != nil);

  [_recipeDetail release];
  _recipeDetail = [recipeDetail retain];
  self.loading = NO;
  self.summaryExpanded = NO;
  self.debugOrigin = debugOrigin;
  if (self.isViewLoaded) {
    [self reloadContentStack];
    [self refreshHeroImage];
  }
}

#pragma mark - View Setup

- (BOOL)usesSheetPresentationChrome {
  return self.navigationController != nil && self.navigationController.modalPresentationStyle == UIModalPresentationPageSheet;
}

- (BOOL)usesNavigationPresentationChrome {
  if (self.navigationController == nil) {
    return NO;
  }

  UIModalPresentationStyle presentationStyle = self.navigationController.modalPresentationStyle;
  return presentationStyle == UIModalPresentationPageSheet || presentationStyle == UIModalPresentationFullScreen;
}

- (void)buildViewHierarchy {
  BOOL usesNavigationChrome = [self usesNavigationPresentationChrome];
  UIView *surfaceView = self.view;

  if (!usesNavigationChrome) {
    UIView *cardView = [[[UIView alloc] init] autorelease];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:cardView];
    cardView.layer.masksToBounds = YES;
    [self.view addSubview:cardView];
    self.cardView = cardView;
    surfaceView = cardView;
  }

  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.delegate = self;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  [surfaceView addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];

  UIView *heroContainerView = [[[UIView alloc] init] autorelease];
  heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  heroContainerView.clipsToBounds = YES;
  [contentView addSubview:heroContainerView];

  UIImageView *heroImageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:self.recipePreview.assetName]] autorelease];
  heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
  heroImageView.contentMode = UIViewContentModeScaleAspectFill;
  heroImageView.clipsToBounds = YES;
  heroImageView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"heroImageView"];
  [heroContainerView addSubview:heroImageView];
  self.heroImageView = heroImageView;

  UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  closeButton.accessibilityIdentifier = @"onboarding.recipeDetail.closeButton";
  closeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
  closeButton.layer.cornerRadius = 19.0;
  closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  [closeButton setTitle:@"X" forState:UIControlStateNormal];
  [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [self configurePressFeedbackForButton:closeButton];
  [closeButton addTarget:self action:@selector(didTapCloseButton) forControlEvents:UIControlEventTouchUpInside];
  [heroContainerView addSubview:closeButton];
  self.closeButton = closeButton;

  UIStackView *contentStackView = [[[UIStackView alloc] init] autorelease];
  contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
  contentStackView.axis = UILayoutConstraintAxisVertical;
  contentStackView.spacing = 16.0;
  [contentView addSubview:contentStackView];
  self.contentStackView = contentStackView;

  UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
  startButton.translatesAutoresizingMaskIntoConstraints = NO;
  startButton.accessibilityIdentifier = @"onboarding.recipeDetail.startCookingButton";
  [startButton setTitle:@"Start Cooking" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRolePrimary toButton:startButton];
  [self configurePressFeedbackForButton:startButton];
  [startButton addTarget:self action:@selector(didTapStartCookingButton) forControlEvents:UIControlEventTouchUpInside];
  self.startButton = startButton;

  self.heroContainerHeightConstraint = [heroContainerView.heightAnchor constraintEqualToConstant:MRRRecipeDetailHeaderHeight];
  self.contentStackTopConstraint = [contentStackView.topAnchor constraintEqualToAnchor:heroContainerView.bottomAnchor constant:-56.0];
  self.contentStackLeadingConstraint = [contentStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0];
  self.contentStackTrailingConstraint = [contentStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0];
  self.contentStackBottomConstraint = [contentStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0];
  self.startButtonHeightConstraint = [startButton.heightAnchor constraintGreaterThanOrEqualToConstant:60.0];

  NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
  self.closeButtonTopConstraint = [self.closeButton.topAnchor constraintEqualToAnchor:heroContainerView.topAnchor constant:18.0];
  self.closeButtonTrailingConstraint = [self.closeButton.trailingAnchor constraintEqualToAnchor:heroContainerView.trailingAnchor constant:-18.0];
  self.closeButtonWidthConstraint = [self.closeButton.widthAnchor constraintEqualToConstant:38.0];
  self.closeButtonHeightConstraint = [self.closeButton.heightAnchor constraintEqualToConstant:38.0];

  if (usesNavigationChrome) {
    [constraints addObjectsFromArray:@[
      [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
      [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
      [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
      self.closeButtonTopConstraint,
      self.closeButtonTrailingConstraint,
      self.closeButtonWidthConstraint,
      self.closeButtonHeightConstraint
    ]];
  } else {
    self.cardTopConstraint = [self.cardView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0];
    self.cardLeadingConstraint = [self.cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0];
    self.cardTrailingConstraint = [self.cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0];
    self.cardBottomConstraint = [self.cardView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0];
    [constraints addObjectsFromArray:@[
      self.cardTopConstraint,
      self.cardLeadingConstraint,
      self.cardTrailingConstraint,
      self.cardBottomConstraint,
      [scrollView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
      [scrollView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
      [scrollView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
      [scrollView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor],
      self.closeButtonTopConstraint,
      self.closeButtonTrailingConstraint,
      self.closeButtonWidthConstraint,
      self.closeButtonHeightConstraint
    ]];
  }

  [constraints addObjectsFromArray:@[
    [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

    [heroContainerView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
    [heroContainerView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [heroContainerView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    self.heroContainerHeightConstraint,

    self.contentStackTopConstraint,
    self.contentStackLeadingConstraint,
    self.contentStackTrailingConstraint,
    self.contentStackBottomConstraint,
    self.startButtonHeightConstraint
  ]];
  [NSLayoutConstraint activateConstraints:constraints];

  self.heroImageTopConstraint = [heroImageView.topAnchor constraintEqualToAnchor:heroContainerView.topAnchor];
  self.heroImageHeightConstraint = [heroImageView.heightAnchor constraintEqualToConstant:MRRRecipeDetailHeaderHeight];
  [NSLayoutConstraint activateConstraints:@[
    self.heroImageTopConstraint,
    [heroImageView.leadingAnchor constraintEqualToAnchor:heroContainerView.leadingAnchor],
    [heroImageView.trailingAnchor constraintEqualToAnchor:heroContainerView.trailingAnchor],
    self.heroImageHeightConstraint
  ]];
}

- (void)reloadContentStack {
  NSArray<UIView *> *arrangedSubviews = [self.contentStackView.arrangedSubviews copy];
  for (UIView *arrangedSubview in arrangedSubviews) {
    [self.contentStackView removeArrangedSubview:arrangedSubview];
    [arrangedSubview removeFromSuperview];
  }
  [arrangedSubviews release];

  self.subtitleLabel = nil;
  self.titleLabel = nil;
  self.headerCardView = nil;
  self.summaryCardView = nil;
  self.summaryEyebrowLabel = nil;
  self.summaryLabel = nil;
  self.summaryToggleButton = nil;
  self.ingredientsSectionCardView = nil;
  self.ingredientsSectionBodyView = nil;
  self.ingredientsSectionDividerView = nil;
  self.ingredientsToggleButton = nil;
  self.instructionsSectionCardView = nil;
  self.instructionsSectionBodyView = nil;
  self.instructionsSectionDividerView = nil;
  self.instructionsToggleButton = nil;
  self.toolsSectionCardView = nil;
  self.toolsSectionBodyView = nil;
  self.toolsSectionDividerView = nil;
  self.toolsToggleButton = nil;
  self.tagsSectionCardView = nil;
  self.tagsSectionBodyView = nil;
  self.tagsSectionDividerView = nil;
  self.tagsToggleButton = nil;
  self.lastRenderedTagViewportWidth = 0.0;
  self.ingredientsExpanded = NO;
  self.instructionsExpanded = NO;
  self.toolsExpanded = NO;
  self.tagsExpanded = NO;

  if (self.isLoading || self.recipeDetail == nil) {
    [self.contentStackView addArrangedSubview:[self titleHeaderSkeletonCardView]];
    [self.contentStackView addArrangedSubview:[self summarySkeletonSectionView]];
    [self.contentStackView addArrangedSubview:[self ingredientsSkeletonSectionView]];
    [self.contentStackView addArrangedSubview:[self instructionsSkeletonSectionView]];
    [self configureStartButtonEnabled:NO];
  } else {
    [self.contentStackView addArrangedSubview:[self titleHeaderCardView]];
    [self.contentStackView addArrangedSubview:[self summarySectionViewForRecipeDetail:self.recipeDetail]];
    [self.contentStackView addArrangedSubview:[self ingredientsSectionViewForIngredients:self.recipeDetail.ingredients]];
    [self.contentStackView addArrangedSubview:[self instructionsSectionViewForInstructions:self.recipeDetail.instructions]];
    if (self.recipeDetail.tools.count > 0) {
      [self.contentStackView addArrangedSubview:[self toolsSectionViewForTools:self.recipeDetail.tools]];
    }
    if (self.recipeDetail.tags.count > 0) {
      [self.contentStackView addArrangedSubview:[self tagsSectionViewForTags:self.recipeDetail.tags]];
    }

    if (self.recipeDetail.productContext != nil) {
      [self.contentStackView addArrangedSubview:[self productContextViewForProductContext:self.recipeDetail.productContext]];
    }

    UIView *sourceAttributionView = [self sourceAttributionViewForRecipeDetail:self.recipeDetail];
    if (sourceAttributionView != nil) {
      [self.contentStackView addArrangedSubview:sourceAttributionView];
    }

    [self configureStartButtonEnabled:YES];
  }

  [self.contentStackView addArrangedSubview:self.startButton];
}

- (void)configureStartButtonEnabled:(BOOL)enabled {
  self.startButton.enabled = enabled;
  self.startButton.alpha = enabled ? 1.0 : 0.58;
}

- (void)refreshHeroImage {
  self.heroImageView.image = [UIImage imageNamed:self.recipePreview.assetName];
  if (self.isLoading || self.recipeDetail.heroImageURLString.length == 0) {
    return;
  }

  NSURL *imageURL = [NSURL URLWithString:self.recipeDetail.heroImageURLString];
  if (imageURL == nil) {
    return;
  }

  self.heroImageRequestToken += 1;
  NSUInteger requestToken = self.heroImageRequestToken;
  __block OnboardingRecipeDetailViewController *blockSelf = self;
  NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithURL:imageURL
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                                if (error != nil || data == nil) {
                                                                  return;
                                                                }

                                                                UIImage *image = [[[UIImage alloc] initWithData:data] autorelease];
                                                                if (image == nil) {
                                                                  return;
                                                                }

                                                                MRROnboardingDetailCompleteOnMainThread(^{
                                                                  OnboardingRecipeDetailViewController *strongSelf = blockSelf;
                                                                  if (strongSelf == nil || requestToken != strongSelf.heroImageRequestToken) {
                                                                    return;
                                                                  }

                                                                  strongSelf.heroImageView.image = image;
                                                                });
                                                              }];
  [dataTask resume];
}

- (void)configurePressFeedbackForButton:(UIButton *)button {
  button.adjustsImageWhenHighlighted = NO;

  UIControlEvents touchDownEvents = UIControlEventTouchDown | UIControlEventTouchDragEnter;
  UIControlEvents touchUpEvents =
      UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit;

  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:touchDownEvents];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:touchUpEvents];
}

- (void)handlePressableButtonTouchDown:(UIButton *)sender {
  if (!sender.enabled) {
    return;
  }

  CGAffineTransform targetTransform = UIAccessibilityIsReduceMotionEnabled()
                                          ? CGAffineTransformIdentity
                                          : CGAffineTransformMakeScale(MRRRecipeDetailButtonPressedScale, MRRRecipeDetailButtonPressedScale);
  [UIView animateWithDuration:0.12
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     sender.transform = targetTransform;
                     sender.alpha = MRRRecipeDetailButtonPressedAlpha;
                   }
                   completion:nil];
}

- (void)handlePressableButtonTouchUp:(UIButton *)sender {
  [UIView animateWithDuration:0.16
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     sender.transform = CGAffineTransformIdentity;
                     sender.alpha = sender.enabled ? 1.0 : 0.58;
                   }
                   completion:nil];
}

- (UILabel *)buildLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.text = text;
  label.font = font;
  label.textColor = color;
  label.numberOfLines = 1;
  return label;
}

- (UILabel *)sectionTitleLabelWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UILabel *label = [self buildLabelWithText:text
                                       font:[UIFont boldSystemFontOfSize:20.0]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                          [UIColor colorWithWhite:0.96 alpha:1.0])];
  label.accessibilityIdentifier = accessibilityIdentifier;
  return label;
}

- (UIView *)recipeSurfaceCardViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier prominent:(BOOL)prominent {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.accessibilityIdentifier = accessibilityIdentifier;
  [MRRLiquidGlassStyling applySurfaceRole:prominent ? MRRGlassSurfaceRoleElevatedCard : MRRGlassSurfaceRoleOverlay toView:cardView];
  cardView.backgroundColor =
      [MRRNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.14 alpha:1.0])
          colorWithAlphaComponent:(prominent ? 0.94 : 0.58)];
  cardView.layer.cornerRadius = prominent ? 28.0 : 22.0;
  cardView.layer.borderWidth = 1.0;
  cardView.layer.borderColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:(prominent ? 0.10 : 0.16)].CGColor;
  return cardView;
}

- (nullable UIView *)sectionIconViewWithSystemName:(NSString *)systemName {
  if (@available(iOS 13.0, *)) {
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium];
    UIImage *iconImage = [UIImage systemImageNamed:systemName withConfiguration:symbolConfiguration];
    if (iconImage == nil) {
      iconImage = [UIImage systemImageNamed:systemName];
    }
    if (iconImage == nil) {
      return nil;
    }

    UIImageView *iconView = [[[UIImageView alloc] initWithImage:iconImage] autorelease];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                       [UIColor colorWithWhite:0.92 alpha:1.0]);
    [iconView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [iconView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [iconView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [iconView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [NSLayoutConstraint activateConstraints:@[
      [iconView.widthAnchor constraintEqualToConstant:20.0],
      [iconView.heightAnchor constraintEqualToConstant:20.0]
    ]];
    return iconView;
  }

  return nil;
}

- (UIView *)titleHeaderCardView {
  UIView *cardView = [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"headerCardView"] prominent:YES];
  self.headerCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIStackView *topRow = [[[UIStackView alloc] init] autorelease];
  topRow.axis = UILayoutConstraintAxisHorizontal;
  topRow.alignment = UIStackViewAlignmentCenter;
  topRow.spacing = 10.0;

  UIView *debugBadgeView = [self debugOriginBadgeViewIfNeeded];
  if (debugBadgeView != nil) {
    [topRow addArrangedSubview:debugBadgeView];
    UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
    [topRow addArrangedSubview:flexibleSpacer];
    [stackView addArrangedSubview:topRow];
  }

  UILabel *subtitleLabel = [self buildLabelWithText:[self.recipeDetail.subtitle uppercaseString]
                                               font:[UIFont boldSystemFontOfSize:12.0]
                                              color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                  [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  subtitleLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"subtitleLabel"];
  [stackView addArrangedSubview:subtitleLabel];
  self.subtitleLabel = subtitleLabel;

  UILabel *titleLabel = [self buildLabelWithText:self.recipeDetail.title
                                            font:[UIFont boldSystemFontOfSize:32.0]
                                           color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  titleLabel.numberOfLines = 0;
  titleLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"titleLabel"];
  [stackView addArrangedSubview:titleLabel];
  self.titleLabel = titleLabel;

  UIStackView *metadataStackView = [[[UIStackView alloc] init] autorelease];
  metadataStackView.axis = UILayoutConstraintAxisHorizontal;
  metadataStackView.spacing = 10.0;
  metadataStackView.alignment = UIStackViewAlignmentFill;
  metadataStackView.distribution = UIStackViewDistributionFillProportionally;
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipeDetail.durationText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"durationChip"]]];
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipeDetail.calorieText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"calorieChip"]]];
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipeDetail.servingsText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"servingsChip"]]];
  [stackView addArrangedSubview:metadataStackView];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-20.0]
  ]];

  return cardView;
}

- (UIView *)titleHeaderSkeletonCardView {
  UIView *cardView = [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"headerCardSkeletonView"] prominent:YES];
  self.headerCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIStackView *topRow = [[[UIStackView alloc] init] autorelease];
  topRow.axis = UILayoutConstraintAxisHorizontal;
  topRow.alignment = UIStackViewAlignmentCenter;
  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [topRow addArrangedSubview:flexibleSpacer];
  UIView *accessorySkeletonView = MRRSkeletonBlockView(34.0, [self detailIdentifierForSuffix:@"headerAccessorySkeletonView"]);
  [NSLayoutConstraint activateConstraints:@[[accessorySkeletonView.widthAnchor constraintEqualToConstant:34.0]]];
  [topRow addArrangedSubview:accessorySkeletonView];
  [stackView addArrangedSubview:topRow];

  UILabel *subtitleLabel = [self buildLabelWithText:[self.recipePreview.subtitle uppercaseString]
                                               font:[UIFont boldSystemFontOfSize:12.0]
                                              color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                  [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  subtitleLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"subtitleLabel"];
  [stackView addArrangedSubview:subtitleLabel];
  self.subtitleLabel = subtitleLabel;

  [stackView addArrangedSubview:MRRSkeletonBlockView(40.0, [self detailIdentifierForSuffix:@"titleSkeletonView"])];
  [stackView addArrangedSubview:MRRSkeletonBlockView(28.0, [self detailIdentifierForSuffix:@"titleSkeletonView.secondary"])];

  UIStackView *metadataStackView = [[[UIStackView alloc] init] autorelease];
  metadataStackView.axis = UILayoutConstraintAxisHorizontal;
  metadataStackView.spacing = 10.0;
  metadataStackView.distribution = UIStackViewDistributionFillEqually;
  [metadataStackView addArrangedSubview:MRRSkeletonBlockView(36.0, [self detailIdentifierForSuffix:@"durationChip"])];
  [metadataStackView addArrangedSubview:MRRSkeletonBlockView(36.0, [self detailIdentifierForSuffix:@"calorieChip"])];
  [metadataStackView addArrangedSubview:MRRSkeletonBlockView(36.0, [self detailIdentifierForSuffix:@"servingsChip"])];
  [stackView addArrangedSubview:metadataStackView];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-20.0]
  ]];

  return cardView;
}

- (UIView *)ingredientsSectionViewForIngredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"ingredientsSectionCardView"] prominent:NO];
  self.ingredientsSectionCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIView *headerContainer = [[[UIView alloc] init] autorelease];
  headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  headerButton.translatesAutoresizingMaskIntoConstraints = NO;
  headerButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"ingredientsHeaderButton"];
  [headerButton addTarget:self action:@selector(didTapIngredientsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [headerContainer addSubview:headerButton];

  UIStackView *headerRow = [[[UIStackView alloc] init] autorelease];
  headerRow.translatesAutoresizingMaskIntoConstraints = NO;
  headerRow.axis = UILayoutConstraintAxisHorizontal;
  headerRow.alignment = UIStackViewAlignmentCenter;
  headerRow.spacing = 12.0;
  headerRow.userInteractionEnabled = NO;
  [headerContainer addSubview:headerRow];

  UIView *iconView = [self sectionIconViewWithSystemName:@"fork.knife.circle"];
  if (iconView != nil) {
    iconView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"ingredientsIconView"];
    [headerRow addArrangedSubview:iconView];
  }

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Ingredients" accessibilityIdentifier:[self detailIdentifierForSuffix:@"ingredientsTitleLabel"]];
  [headerRow addArrangedSubview:titleLabel];

  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [headerRow addArrangedSubview:flexibleSpacer];

  UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
  toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
  toggleButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"ingredientsToggleButton"];
  toggleButton.tintColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                         [UIColor colorWithWhite:0.92 alpha:1.0]);
  [toggleButton addTarget:self action:@selector(didTapIngredientsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [NSLayoutConstraint activateConstraints:@[
    [toggleButton.widthAnchor constraintEqualToConstant:28.0],
    [toggleButton.heightAnchor constraintEqualToConstant:28.0]
  ]];
  [headerContainer addSubview:toggleButton];
  self.ingredientsToggleButton = toggleButton;

  [NSLayoutConstraint activateConstraints:@[
    [headerButton.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerButton.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [headerButton.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [headerRow.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerRow.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerRow.trailingAnchor constraintEqualToAnchor:toggleButton.leadingAnchor constant:-12.0],
    [headerRow.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [toggleButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [toggleButton.centerYAnchor constraintEqualToAnchor:headerContainer.centerYAnchor]
  ]];
  [stackView addArrangedSubview:headerContainer];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"ingredientsSectionDividerView"];
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.10];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];
  self.ingredientsSectionDividerView = dividerView;

  UIView *bodyView = [self ingredientGridViewForIngredients:ingredients];
  bodyView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"ingredientsSectionBodyView"];
  [stackView addArrangedSubview:bodyView];
  self.ingredientsSectionBodyView = bodyView;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  [self refreshIngredientsSectionAnimated:NO];
  return cardView;
}

- (UIView *)ingredientsSkeletonSectionView {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"ingredientsSkeletonSectionView"] prominent:NO];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIStackView *headerRow = [[[UIStackView alloc] init] autorelease];
  headerRow.axis = UILayoutConstraintAxisHorizontal;
  headerRow.alignment = UIStackViewAlignmentCenter;
  headerRow.spacing = 12.0;
  UIView *iconSkeletonView = MRRSkeletonBlockView(24.0, [self detailIdentifierForSuffix:@"ingredientsIconSkeletonView"]);
  [NSLayoutConstraint activateConstraints:@[[iconSkeletonView.widthAnchor constraintEqualToConstant:24.0]]];
  [headerRow addArrangedSubview:iconSkeletonView];
  [headerRow addArrangedSubview:MRRSkeletonBlockView(24.0, [self detailIdentifierForSuffix:@"ingredientsTitleLabel"])];
  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [headerRow addArrangedSubview:flexibleSpacer];
  UIView *toggleSkeletonView = MRRSkeletonBlockView(24.0, [self detailIdentifierForSuffix:@"ingredientsToggleSkeletonView"]);
  [NSLayoutConstraint activateConstraints:@[[toggleSkeletonView.widthAnchor constraintEqualToConstant:24.0]]];
  [headerRow addArrangedSubview:toggleSkeletonView];
  [stackView addArrangedSubview:headerRow];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.08];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];

  [stackView addArrangedSubview:MRRSkeletonBlockView(92.0, [self detailIdentifierForSuffix:@"ingredientsSkeletonView"])];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  return cardView;
}

- (UIView *)instructionsSectionViewForInstructions:(NSArray<OnboardingRecipeInstruction *> *)instructions {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"instructionsSectionCardView"] prominent:NO];
  self.instructionsSectionCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIView *headerContainer = [[[UIView alloc] init] autorelease];
  headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  headerButton.translatesAutoresizingMaskIntoConstraints = NO;
  headerButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"instructionsHeaderButton"];
  [headerButton addTarget:self action:@selector(didTapInstructionsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [headerContainer addSubview:headerButton];

  UIStackView *headerRow = [[[UIStackView alloc] init] autorelease];
  headerRow.translatesAutoresizingMaskIntoConstraints = NO;
  headerRow.axis = UILayoutConstraintAxisHorizontal;
  headerRow.alignment = UIStackViewAlignmentCenter;
  headerRow.spacing = 12.0;
  headerRow.userInteractionEnabled = NO;
  [headerContainer addSubview:headerRow];

  UIView *iconView = [self sectionIconViewWithSystemName:@"list.number"];
  if (iconView != nil) {
    iconView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"instructionsIconView"];
    [headerRow addArrangedSubview:iconView];
  }

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Methods" accessibilityIdentifier:[self detailIdentifierForSuffix:@"instructionsTitleLabel"]];
  [headerRow addArrangedSubview:titleLabel];

  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [headerRow addArrangedSubview:flexibleSpacer];

  UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
  toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
  toggleButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"instructionsToggleButton"];
  toggleButton.tintColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                         [UIColor colorWithWhite:0.92 alpha:1.0]);
  [toggleButton addTarget:self action:@selector(didTapInstructionsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [NSLayoutConstraint activateConstraints:@[
    [toggleButton.widthAnchor constraintEqualToConstant:28.0],
    [toggleButton.heightAnchor constraintEqualToConstant:28.0]
  ]];
  [headerContainer addSubview:toggleButton];
  self.instructionsToggleButton = toggleButton;

  [NSLayoutConstraint activateConstraints:@[
    [headerButton.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerButton.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [headerButton.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [headerRow.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerRow.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerRow.trailingAnchor constraintEqualToAnchor:toggleButton.leadingAnchor constant:-12.0],
    [headerRow.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [toggleButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [toggleButton.centerYAnchor constraintEqualToAnchor:headerContainer.centerYAnchor]
  ]];
  [stackView addArrangedSubview:headerContainer];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"instructionsSectionDividerView"];
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.10];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];
  self.instructionsSectionDividerView = dividerView;

  UIView *bodyView = [self instructionsStackViewForInstructions:instructions];
  bodyView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"instructionsSectionBodyView"];
  [stackView addArrangedSubview:bodyView];
  self.instructionsSectionBodyView = bodyView;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  [self refreshInstructionsSectionAnimated:NO];
  return cardView;
}

- (UIView *)instructionsSkeletonSectionView {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"instructionsSkeletonSectionView"] prominent:NO];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  [stackView addArrangedSubview:MRRSkeletonBlockView(24.0, [self detailIdentifierForSuffix:@"instructionsTitleLabel"])];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.08];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];
  [stackView addArrangedSubview:MRRSkeletonBlockView(132.0, [self detailIdentifierForSuffix:@"instructionsSkeletonView"])];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  return cardView;
}

- (UIView *)toolsSectionViewForTools:(NSArray<NSString *> *)tools {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"toolsSectionCardView"] prominent:NO];
  self.toolsSectionCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIView *headerContainer = [[[UIView alloc] init] autorelease];
  headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  headerButton.translatesAutoresizingMaskIntoConstraints = NO;
  headerButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"toolsHeaderButton"];
  [headerButton addTarget:self action:@selector(didTapToolsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [headerContainer addSubview:headerButton];

  UIStackView *headerRow = [[[UIStackView alloc] init] autorelease];
  headerRow.translatesAutoresizingMaskIntoConstraints = NO;
  headerRow.axis = UILayoutConstraintAxisHorizontal;
  headerRow.alignment = UIStackViewAlignmentCenter;
  headerRow.spacing = 12.0;
  headerRow.userInteractionEnabled = NO;
  [headerContainer addSubview:headerRow];

  UIView *iconView = [self sectionIconViewWithSystemName:@"wrench.and.screwdriver"];
  if (iconView != nil) {
    iconView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"toolsIconView"];
    [headerRow addArrangedSubview:iconView];
  }

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Tools & Equipment" accessibilityIdentifier:[self detailIdentifierForSuffix:@"toolsTitleLabel"]];
  [headerRow addArrangedSubview:titleLabel];

  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [headerRow addArrangedSubview:flexibleSpacer];

  UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
  toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
  toggleButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"toolsToggleButton"];
  toggleButton.tintColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                         [UIColor colorWithWhite:0.92 alpha:1.0]);
  [toggleButton addTarget:self action:@selector(didTapToolsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [NSLayoutConstraint activateConstraints:@[
    [toggleButton.widthAnchor constraintEqualToConstant:28.0],
    [toggleButton.heightAnchor constraintEqualToConstant:28.0]
  ]];
  [headerContainer addSubview:toggleButton];
  self.toolsToggleButton = toggleButton;

  [NSLayoutConstraint activateConstraints:@[
    [headerButton.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerButton.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [headerButton.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [headerRow.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerRow.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerRow.trailingAnchor constraintEqualToAnchor:toggleButton.leadingAnchor constant:-12.0],
    [headerRow.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [toggleButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [toggleButton.centerYAnchor constraintEqualToAnchor:headerContainer.centerYAnchor]
  ]];
  [stackView addArrangedSubview:headerContainer];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"toolsSectionDividerView"];
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.10];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];
  self.toolsSectionDividerView = dividerView;

  UIStackView *bodyStackView = [[[UIStackView alloc] init] autorelease];
  bodyStackView.translatesAutoresizingMaskIntoConstraints = NO;
  bodyStackView.axis = UILayoutConstraintAxisVertical;
  bodyStackView.spacing = 14.0;
  bodyStackView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"toolsSectionBodyView"];
  for (NSUInteger index = 0; index < tools.count; index++) {
    [bodyStackView addArrangedSubview:[self toolRowViewWithText:tools[index] index:index + 1]];
  }
  [stackView addArrangedSubview:bodyStackView];
  self.toolsSectionBodyView = bodyStackView;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  [self refreshToolsSectionAnimated:NO];
  return cardView;
}

- (UIView *)toolRowViewWithText:(NSString *)toolText index:(NSUInteger)index {
  UIView *rowView = [[[UIView alloc] init] autorelease];
  rowView.translatesAutoresizingMaskIntoConstraints = NO;
  rowView.accessibilityIdentifier = [self detailIdentifierForSuffix:[NSString stringWithFormat:@"toolRow.%lu", (unsigned long)index]];
  rowView.backgroundColor = [MRRNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.16 alpha:1.0])
      colorWithAlphaComponent:0.92];
  rowView.layer.cornerRadius = 16.0;

  UIView *dotView = [[[UIView alloc] init] autorelease];
  dotView.translatesAutoresizingMaskIntoConstraints = NO;
  dotView.backgroundColor = [UIColor colorWithRed:0.10 green:0.60 blue:0.13 alpha:1.0];
  dotView.layer.cornerRadius = 5.0;
  [rowView addSubview:dotView];

  UILabel *label = [self buildLabelWithText:toolText
                                       font:[UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                          [UIColor colorWithWhite:0.94 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.numberOfLines = 0;
  label.accessibilityIdentifier = [NSString stringWithFormat:@"%@.label", rowView.accessibilityIdentifier];
  [rowView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [rowView.heightAnchor constraintGreaterThanOrEqualToConstant:52.0],
    [dotView.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:18.0],
    [dotView.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
    [dotView.widthAnchor constraintEqualToConstant:10.0],
    [dotView.heightAnchor constraintEqualToConstant:10.0],
    [label.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:15.0],
    [label.leadingAnchor constraintEqualToAnchor:dotView.trailingAnchor constant:16.0],
    [label.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-18.0],
    [label.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor constant:-15.0]
  ]];

  return rowView;
}

- (UIView *)tagsSectionViewForTags:(NSArray<NSString *> *)tags {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"tagsSectionCardView"] prominent:NO];
  self.tagsSectionCardView = cardView;
  self.lastRenderedTagViewportWidth = [self layoutViewportSize].width;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 14.0;
  [cardView addSubview:stackView];

  UIView *headerContainer = [[[UIView alloc] init] autorelease];
  headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  headerButton.translatesAutoresizingMaskIntoConstraints = NO;
  headerButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsHeaderButton"];
  [headerButton addTarget:self action:@selector(didTapTagsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [headerContainer addSubview:headerButton];

  UIStackView *headerRow = [[[UIStackView alloc] init] autorelease];
  headerRow.translatesAutoresizingMaskIntoConstraints = NO;
  headerRow.axis = UILayoutConstraintAxisHorizontal;
  headerRow.alignment = UIStackViewAlignmentCenter;
  headerRow.spacing = 12.0;
  headerRow.userInteractionEnabled = NO;
  [headerContainer addSubview:headerRow];

  UIView *iconView = [self sectionIconViewWithSystemName:@"tag"];
  if (iconView != nil) {
    iconView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsIconView"];
    [headerRow addArrangedSubview:iconView];
  }

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Tags" accessibilityIdentifier:[self detailIdentifierForSuffix:@"tagsTitleLabel"]];
  [headerRow addArrangedSubview:titleLabel];

  UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
  [headerRow addArrangedSubview:flexibleSpacer];

  UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
  toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
  toggleButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsToggleButton"];
  toggleButton.tintColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                         [UIColor colorWithWhite:0.92 alpha:1.0]);
  [toggleButton addTarget:self action:@selector(didTapTagsToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [NSLayoutConstraint activateConstraints:@[
    [toggleButton.widthAnchor constraintEqualToConstant:28.0],
    [toggleButton.heightAnchor constraintEqualToConstant:28.0]
  ]];
  [headerContainer addSubview:toggleButton];
  self.tagsToggleButton = toggleButton;

  [NSLayoutConstraint activateConstraints:@[
    [headerButton.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerButton.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [headerButton.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [headerRow.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
    [headerRow.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
    [headerRow.trailingAnchor constraintEqualToAnchor:toggleButton.leadingAnchor constant:-12.0],
    [headerRow.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    [toggleButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
    [toggleButton.centerYAnchor constraintEqualToAnchor:headerContainer.centerYAnchor]
  ]];
  [stackView addArrangedSubview:headerContainer];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsSectionDividerView"];
  dividerView.backgroundColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.10];
  [NSLayoutConstraint activateConstraints:@[[dividerView.heightAnchor constraintEqualToConstant:1.0]]];
  [stackView addArrangedSubview:dividerView];
  self.tagsSectionDividerView = dividerView;

  UIView *bodyView = [self tagRowsViewForTags:tags];
  bodyView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsSectionBodyView"];
  [stackView addArrangedSubview:bodyView];
  self.tagsSectionBodyView = bodyView;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  [self refreshTagsSectionAnimated:NO];
  return cardView;
}

- (void)refreshTagSectionLayoutIfNeededForViewportWidth:(CGFloat)viewportWidth {
  if (viewportWidth <= 0.0 || self.isLoading || self.recipeDetail == nil || self.recipeDetail.tags.count == 0 || self.tagsSectionCardView == nil) {
    return;
  }

  if (ABS(viewportWidth - self.lastRenderedTagViewportWidth) < 1.0) {
    return;
  }

  NSUInteger sectionIndex = [self.contentStackView.arrangedSubviews indexOfObject:self.tagsSectionCardView];
  if (sectionIndex == NSNotFound) {
    self.lastRenderedTagViewportWidth = viewportWidth;
    return;
  }

  UIView *previousTagsSectionCardView = [self.tagsSectionCardView retain];
  UIView *replacementSectionView = [self tagsSectionViewForTags:self.recipeDetail.tags];
  [self.contentStackView insertArrangedSubview:replacementSectionView atIndex:sectionIndex];
  [self.contentStackView removeArrangedSubview:previousTagsSectionCardView];
  [previousTagsSectionCardView removeFromSuperview];
  [previousTagsSectionCardView release];
  self.lastRenderedTagViewportWidth = viewportWidth;
}

- (UIView *)tagRowsViewForTags:(NSArray<NSString *> *)tags {
  UIStackView *rowsStackView = [[[UIStackView alloc] init] autorelease];
  rowsStackView.axis = UILayoutConstraintAxisVertical;
  rowsStackView.spacing = 10.0;
  rowsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  rowsStackView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagsWrapView"];

  CGSize viewportSize = [self layoutViewportSize];
  CGFloat availableWidth = MAX(viewportSize.width - 72.0, 220.0);
  CGFloat maximumChipWidth = MAX(MIN(availableWidth * 0.62, 240.0), 132.0);
  UIFont *font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];

  UIStackView *currentRow = nil;
  CGFloat currentRowWidth = 0.0;
  for (NSUInteger index = 0; index < tags.count; index++) {
    NSString *tagText = tags[index];
    UIView *chipView = [self tagChipViewWithText:tagText];
    chipView.accessibilityIdentifier = [self detailIdentifierForSuffix:[NSString stringWithFormat:@"tagChip.%lu", (unsigned long)(index + 1)]];

    CGFloat chipWidth = MIN(ceil([tagText sizeWithAttributes:@{NSFontAttributeName : font}].width) + 28.0, maximumChipWidth);
    CGFloat projectedWidth = currentRowWidth > 0.0 ? currentRowWidth + 10.0 + chipWidth : chipWidth;
    if (currentRow == nil || projectedWidth > availableWidth) {
      if (currentRow != nil) {
        UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
        [currentRow addArrangedSubview:flexibleSpacer];
      }
      currentRow = [[[UIStackView alloc] init] autorelease];
      currentRow.axis = UILayoutConstraintAxisHorizontal;
      currentRow.alignment = UIStackViewAlignmentCenter;
      currentRow.spacing = 10.0;
      currentRow.distribution = UIStackViewDistributionFill;
      [rowsStackView addArrangedSubview:currentRow];
      currentRowWidth = 0.0;
      projectedWidth = chipWidth;
    }

    [currentRow addArrangedSubview:chipView];
    currentRowWidth = projectedWidth;
  }

  if (currentRow != nil) {
    UIView *flexibleSpacer = [[[UIView alloc] init] autorelease];
    [currentRow addArrangedSubview:flexibleSpacer];
  }

  return rowsStackView;
}

- (UIView *)tagChipViewWithText:(NSString *)tagText {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.backgroundColor = MRRNamedColor(@"TagChipBackgroundColor", [UIColor colorWithRed:0.90 green:0.97 blue:0.90 alpha:1.0],
                                           [UIColor colorWithRed:0.12 green:0.22 blue:0.12 alpha:1.0]);
  chipView.layer.cornerRadius = 16.0;

  UILabel *label = [self buildLabelWithText:tagText
                                       font:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                      color:MRRNamedColor(@"TagChipForegroundColor", [UIColor colorWithRed:0.10 green:0.52 blue:0.14 alpha:1.0],
                                                          [UIColor colorWithRed:0.62 green:0.86 blue:0.64 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.numberOfLines = 1;
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  label.accessibilityIdentifier = [self detailIdentifierForSuffix:@"tagChip.label"];
  [chipView addSubview:label];

  CGSize viewportSize = [self layoutViewportSize];
  CGFloat availableWidth = MAX(viewportSize.width - 72.0, 220.0);
  CGFloat maximumChipWidth = MAX(MIN(availableWidth * 0.62, 240.0), 132.0);
  [chipView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [chipView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [NSLayoutConstraint activateConstraints:@[
    [chipView.widthAnchor constraintLessThanOrEqualToConstant:maximumChipWidth],
    [label.topAnchor constraintEqualToAnchor:chipView.topAnchor constant:8.0],
    [label.leadingAnchor constraintEqualToAnchor:chipView.leadingAnchor constant:14.0],
    [label.trailingAnchor constraintEqualToAnchor:chipView.trailingAnchor constant:-14.0],
    [label.bottomAnchor constraintEqualToAnchor:chipView.bottomAnchor constant:-8.0]
  ]];

  return chipView;
}

- (UIView *)summarySectionViewForRecipeDetail:(OnboardingRecipeDetail *)recipeDetail {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryCardView"];
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:cardView];
  cardView.backgroundColor = [MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.15 alpha:1.0])
      colorWithAlphaComponent:0.58];
  cardView.layer.cornerRadius = 22.0;
  cardView.layer.borderWidth = 1.0;
  cardView.layer.borderColor =
      [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                     [UIColor colorWithWhite:0.92 alpha:1.0]) colorWithAlphaComponent:0.16].CGColor;
  self.summaryCardView = cardView;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 12.0;
  [cardView addSubview:stackView];

  UILabel *eyebrowLabel = [self buildLabelWithText:@"Chef Notes"
                                              font:[UIFont systemFontOfSize:11.0 weight:UIFontWeightBold]
                                             color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                 [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  eyebrowLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryEyebrowLabel"];
  [stackView addArrangedSubview:eyebrowLabel];
  self.summaryEyebrowLabel = eyebrowLabel;

  UILabel *summaryLabel = [self buildLabelWithText:recipeDetail.summaryText
                                              font:[UIFont systemFontOfSize:16.0]
                                             color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.70 alpha:1.0])];
  summaryLabel.numberOfLines = 0;
  summaryLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryLabel"];
  [stackView addArrangedSubview:summaryLabel];
  self.summaryLabel = summaryLabel;

  UIButton *summaryToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
  summaryToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
  summaryToggleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  summaryToggleButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryToggleButton"];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleInline toButton:summaryToggleButton];
  [summaryToggleButton addTarget:self action:@selector(didTapSummaryToggleButton) forControlEvents:UIControlEventTouchUpInside];
  [stackView addArrangedSubview:summaryToggleButton];
  self.summaryToggleButton = summaryToggleButton;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  self.summaryExpanded = NO;
  [self refreshSummaryExpansionStateAnimated:NO];
  return cardView;
}

- (UIView *)summarySkeletonSectionView {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryCardSkeletonView"];
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:cardView];
  cardView.backgroundColor = [MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.15 alpha:1.0])
      colorWithAlphaComponent:0.42];
  cardView.layer.cornerRadius = 22.0;

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 12.0;
  [cardView addSubview:stackView];

  [stackView addArrangedSubview:MRRSkeletonBlockView(12.0, [self detailIdentifierForSuffix:@"summaryEyebrowSkeletonView"])];
  [stackView addArrangedSubview:MRRSkeletonBlockView(18.0, [self detailIdentifierForSuffix:@"summarySkeletonView"])];
  [stackView addArrangedSubview:MRRSkeletonBlockView(18.0, [self detailIdentifierForSuffix:@"summarySkeletonView.secondary"])];
  [stackView addArrangedSubview:MRRSkeletonBlockView(18.0, [self detailIdentifierForSuffix:@"summarySkeletonView.tertiary"])];
  [stackView addArrangedSubview:MRRSkeletonBlockView(38.0, [self detailIdentifierForSuffix:@"summaryToggleSkeletonView"])];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  return cardView;
}

- (BOOL)shouldAllowSummaryExpansionForText:(NSString *)summaryText {
  if (summaryText.length <= 180) {
    return NO;
  }

  NSArray<NSString *> *components =
      [summaryText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSUInteger wordCount = 0;
  for (NSString *component in components) {
    if (component.length > 0) {
      wordCount += 1;
    }
  }

  return wordCount > 26;
}

- (void)refreshSummaryExpansionStateAnimated:(BOOL)animated {
  if (self.summaryLabel == nil) {
    return;
  }

  BOOL canExpand = [self shouldAllowSummaryExpansionForText:self.summaryLabel.text];
  self.summaryToggleButton.hidden = !canExpand;
  self.summaryLabel.numberOfLines = canExpand && !self.summaryExpanded ? 4 : 0;
  [self updateSummaryToggleButtonAppearance];

  if (!animated || self.view.window == nil) {
    return;
  }

  [UIView animateWithDuration:0.2
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)updateSummaryToggleButtonAppearance {
  if (self.summaryToggleButton == nil) {
    return;
  }

  NSString *title = self.summaryExpanded ? @"Show less" : @"Read more";
  CGSize viewportSize = [self layoutViewportSize];
  CGFloat fontSize = viewportSize.width > 0.0 ? MRRLayoutScaledValue(14.0, viewportSize, MRRLayoutScaleAxisWidth) : 14.0;
  UIColor *foregroundColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                           [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *configuration = self.summaryToggleButton.configuration;
    if (configuration != nil) {
      configuration.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
      configuration.baseForegroundColor = foregroundColor;
      NSAttributedString *attributedTitle =
          [[[NSAttributedString alloc] initWithString:title
                                           attributes:@{
                                             NSFontAttributeName : [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold],
                                             NSForegroundColorAttributeName : foregroundColor
                                           }] autorelease];
      configuration.attributedTitle = attributedTitle;
      self.summaryToggleButton.configuration = configuration;
      return;
    }
  }

  [self.summaryToggleButton setTitle:title forState:UIControlStateNormal];
  [self.summaryToggleButton setTitleColor:foregroundColor forState:UIControlStateNormal];
  self.summaryToggleButton.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold];
  self.summaryToggleButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
}

- (void)refreshIngredientsSectionAnimated:(BOOL)animated {
  if (self.ingredientsSectionBodyView == nil || self.ingredientsToggleButton == nil) {
    return;
  }

  self.ingredientsSectionBodyView.hidden = !self.ingredientsExpanded;
  self.ingredientsSectionDividerView.hidden = !self.ingredientsExpanded;
  [self updateIngredientsToggleButtonAppearance];

  if (!animated || self.view.window == nil) {
    return;
  }

  [UIView animateWithDuration:0.22
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)updateIngredientsToggleButtonAppearance {
  if (self.ingredientsToggleButton == nil) {
    return;
  }

  NSString *fallbackTitle = self.ingredientsExpanded ? @"Hide" : @"Show";
  UIColor *foregroundColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                           [UIColor colorWithWhite:0.92 alpha:1.0]);
  [self.ingredientsToggleButton setTitle:nil forState:UIControlStateNormal];
  [self.ingredientsToggleButton setTitleColor:foregroundColor forState:UIControlStateNormal];

  if (@available(iOS 13.0, *)) {
    NSString *symbolName = self.ingredientsExpanded ? @"chevron.down" : @"chevron.right";
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [self.ingredientsToggleButton setImage:image forState:UIControlStateNormal];
    self.ingredientsToggleButton.tintColor = foregroundColor;
    return;
  }

  [self.ingredientsToggleButton setTitle:fallbackTitle forState:UIControlStateNormal];
}

- (void)refreshInstructionsSectionAnimated:(BOOL)animated {
  if (self.instructionsSectionBodyView == nil || self.instructionsToggleButton == nil) {
    return;
  }

  self.instructionsSectionBodyView.hidden = !self.instructionsExpanded;
  self.instructionsSectionDividerView.hidden = !self.instructionsExpanded;
  [self updateInstructionsToggleButtonAppearance];

  if (!animated || self.view.window == nil) {
    return;
  }

  [UIView animateWithDuration:0.22
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)updateInstructionsToggleButtonAppearance {
  if (self.instructionsToggleButton == nil) {
    return;
  }

  NSString *fallbackTitle = self.instructionsExpanded ? @"Hide" : @"Show";
  UIColor *foregroundColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                           [UIColor colorWithWhite:0.92 alpha:1.0]);
  [self.instructionsToggleButton setTitle:nil forState:UIControlStateNormal];
  [self.instructionsToggleButton setTitleColor:foregroundColor forState:UIControlStateNormal];

  if (@available(iOS 13.0, *)) {
    NSString *symbolName = self.instructionsExpanded ? @"chevron.down" : @"chevron.right";
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [self.instructionsToggleButton setImage:image forState:UIControlStateNormal];
    self.instructionsToggleButton.tintColor = foregroundColor;
    return;
  }

  [self.instructionsToggleButton setTitle:fallbackTitle forState:UIControlStateNormal];
}

- (void)refreshToolsSectionAnimated:(BOOL)animated {
  if (self.toolsSectionBodyView == nil || self.toolsToggleButton == nil) {
    return;
  }

  self.toolsSectionBodyView.hidden = !self.toolsExpanded;
  self.toolsSectionDividerView.hidden = !self.toolsExpanded;
  [self updateToolsToggleButtonAppearance];

  if (!animated || self.view.window == nil) {
    return;
  }

  [UIView animateWithDuration:0.22
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)updateToolsToggleButtonAppearance {
  if (self.toolsToggleButton == nil) {
    return;
  }

  NSString *fallbackTitle = self.toolsExpanded ? @"Hide" : @"Show";
  UIColor *foregroundColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                           [UIColor colorWithWhite:0.92 alpha:1.0]);
  [self.toolsToggleButton setTitle:nil forState:UIControlStateNormal];
  [self.toolsToggleButton setTitleColor:foregroundColor forState:UIControlStateNormal];

  if (@available(iOS 13.0, *)) {
    NSString *symbolName = self.toolsExpanded ? @"chevron.down" : @"chevron.right";
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [self.toolsToggleButton setImage:image forState:UIControlStateNormal];
    self.toolsToggleButton.tintColor = foregroundColor;
    return;
  }

  [self.toolsToggleButton setTitle:fallbackTitle forState:UIControlStateNormal];
}

- (void)refreshTagsSectionAnimated:(BOOL)animated {
  if (self.tagsSectionBodyView == nil || self.tagsToggleButton == nil) {
    return;
  }

  self.tagsSectionBodyView.hidden = !self.tagsExpanded;
  self.tagsSectionDividerView.hidden = !self.tagsExpanded;
  [self updateTagsToggleButtonAppearance];

  if (!animated || self.view.window == nil) {
    return;
  }

  [UIView animateWithDuration:0.22
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                              UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)updateTagsToggleButtonAppearance {
  if (self.tagsToggleButton == nil) {
    return;
  }

  NSString *fallbackTitle = self.tagsExpanded ? @"Hide" : @"Show";
  UIColor *foregroundColor = MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.18 alpha:1.0],
                                           [UIColor colorWithWhite:0.92 alpha:1.0]);
  [self.tagsToggleButton setTitle:nil forState:UIControlStateNormal];
  [self.tagsToggleButton setTitleColor:foregroundColor forState:UIControlStateNormal];

  if (@available(iOS 13.0, *)) {
    NSString *symbolName = self.tagsExpanded ? @"chevron.down" : @"chevron.right";
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [self.tagsToggleButton setImage:image forState:UIControlStateNormal];
    self.tagsToggleButton.tintColor = foregroundColor;
    return;
  }

  [self.tagsToggleButton setTitle:fallbackTitle forState:UIControlStateNormal];
}

- (UIView *)metadataChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.accessibilityIdentifier = accessibilityIdentifier;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleBadge toView:chipView];

  UILabel *label = [self buildLabelWithText:text
                                       font:[UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                          [UIColor colorWithWhite:0.96 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".label"];
  [chipView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [label.topAnchor constraintEqualToAnchor:chipView.topAnchor constant:9.0],
    [label.leadingAnchor constraintEqualToAnchor:chipView.leadingAnchor constant:12.0],
    [label.trailingAnchor constraintEqualToAnchor:chipView.trailingAnchor constant:-12.0],
    [label.bottomAnchor constraintEqualToAnchor:chipView.bottomAnchor constant:-9.0]
  ]];

  return chipView;
}

- (UIView *)ingredientGridViewForIngredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients {
  UIStackView *rowsStackView = [[[UIStackView alloc] init] autorelease];
  rowsStackView.axis = UILayoutConstraintAxisVertical;
  rowsStackView.spacing = 12.0;
  rowsStackView.translatesAutoresizingMaskIntoConstraints = NO;

  for (NSUInteger index = 0; index < ingredients.count; index++) {
    [rowsStackView addArrangedSubview:[self ingredientChipWithIngredient:ingredients[index]
                                                  accessibilityIdentifier:[self detailIdentifierForSuffix:[NSString stringWithFormat:
                                                                                                          @"ingredientChip.%lu",
                                                                                                          (unsigned long)(index + 1)]]]];
  }

  return rowsStackView;
}

- (UIView *)ingredientChipWithIngredient:(OnboardingRecipeIngredient *)ingredient accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIStackView *rowStackView = [[[UIStackView alloc] init] autorelease];
  rowStackView.translatesAutoresizingMaskIntoConstraints = NO;
  rowStackView.axis = UILayoutConstraintAxisHorizontal;
  rowStackView.alignment = UIStackViewAlignmentTop;
  rowStackView.spacing = 12.0;
  rowStackView.accessibilityIdentifier = accessibilityIdentifier;

  UIView *bulletView = [[[UIView alloc] init] autorelease];
  bulletView.translatesAutoresizingMaskIntoConstraints = NO;
  bulletView.backgroundColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                             [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  bulletView.layer.cornerRadius = 4.0;
  [NSLayoutConstraint activateConstraints:@[
    [bulletView.widthAnchor constraintEqualToConstant:8.0],
    [bulletView.heightAnchor constraintEqualToConstant:8.0]
  ]];

  UIView *bulletOffsetContainer = [[[UIView alloc] init] autorelease];
  bulletOffsetContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [bulletOffsetContainer addSubview:bulletView];
  [NSLayoutConstraint activateConstraints:@[
    [bulletOffsetContainer.widthAnchor constraintEqualToConstant:10.0],
    [bulletOffsetContainer.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
    [bulletView.topAnchor constraintEqualToAnchor:bulletOffsetContainer.topAnchor constant:6.0],
    [bulletView.centerXAnchor constraintEqualToAnchor:bulletOffsetContainer.centerXAnchor]
  ]];

  UILabel *label = [self buildLabelWithText:ingredient.displayText
                                       font:[UIFont systemFontOfSize:15.0]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                          [UIColor colorWithWhite:0.94 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.numberOfLines = 0;
  label.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".label"];
  [rowStackView addArrangedSubview:bulletOffsetContainer];
  [rowStackView addArrangedSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [bulletOffsetContainer.widthAnchor constraintEqualToConstant:10.0]
  ]];

  return rowStackView;
}

- (UIView *)instructionsStackViewForInstructions:(NSArray<OnboardingRecipeInstruction *> *)instructions {
  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 16.0;
  stackView.translatesAutoresizingMaskIntoConstraints = NO;

  for (NSUInteger index = 0; index < instructions.count; index++) {
    [stackView addArrangedSubview:[self instructionRowForInstruction:instructions[index] index:index + 1]];
  }

  return stackView;
}

- (UIView *)instructionRowForInstruction:(OnboardingRecipeInstruction *)instruction index:(NSUInteger)index {
  UIStackView *rowStackView = [[[UIStackView alloc] init] autorelease];
  rowStackView.axis = UILayoutConstraintAxisHorizontal;
  rowStackView.spacing = 12.0;
  rowStackView.alignment = UIStackViewAlignmentTop;

  UIView *badgeView = [[[UIView alloc] init] autorelease];
  badgeView.translatesAutoresizingMaskIntoConstraints = NO;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleBadge toView:badgeView];
  [NSLayoutConstraint activateConstraints:@[
    [badgeView.widthAnchor constraintEqualToConstant:36.0],
    [badgeView.heightAnchor constraintEqualToConstant:36.0]
  ]];

  UILabel *indexLabel = [self buildLabelWithText:[NSString stringWithFormat:@"%lu", (unsigned long)index]
                                            font:[UIFont boldSystemFontOfSize:15.0]
                                           color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                               [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  indexLabel.translatesAutoresizingMaskIntoConstraints = NO;
  indexLabel.accessibilityIdentifier =
      [self detailIdentifierForSuffix:[NSString stringWithFormat:@"instructionRow.%lu.indexLabel", (unsigned long)index]];
  [badgeView addSubview:indexLabel];

  [NSLayoutConstraint activateConstraints:@[
    [indexLabel.centerXAnchor constraintEqualToAnchor:badgeView.centerXAnchor],
    [indexLabel.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor]
  ]];

  UIStackView *textStackView = [[[UIStackView alloc] init] autorelease];
  textStackView.axis = UILayoutConstraintAxisVertical;
  textStackView.spacing = 4.0;

  UILabel *titleLabel = [self buildLabelWithText:instruction.title
                                            font:[UIFont boldSystemFontOfSize:17.0]
                                           color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  titleLabel.accessibilityIdentifier =
      [self detailIdentifierForSuffix:[NSString stringWithFormat:@"instructionRow.%lu.titleLabel", (unsigned long)index]];
  UILabel *bodyLabel = [self buildLabelWithText:instruction.detailText
                                           font:[UIFont systemFontOfSize:15.0]
                                          color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                              [UIColor colorWithWhite:0.70 alpha:1.0])];
  bodyLabel.numberOfLines = 0;
  bodyLabel.accessibilityIdentifier =
      [self detailIdentifierForSuffix:[NSString stringWithFormat:@"instructionRow.%lu.bodyLabel", (unsigned long)index]];
  [textStackView addArrangedSubview:titleLabel];
  [textStackView addArrangedSubview:bodyLabel];

  [rowStackView addArrangedSubview:badgeView];
  [rowStackView addArrangedSubview:textStackView];

  return rowStackView;
}

- (UIView *)productContextViewForProductContext:(OnboardingRecipeProductContext *)productContext {
  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"productContextCardView"] prominent:NO];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 10.0;
  [cardView addSubview:stackView];

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Product Context" accessibilityIdentifier:[self detailIdentifierForSuffix:@"productContextTitleLabel"]];
  [stackView addArrangedSubview:titleLabel];

  NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:productContext.productName];
  if (productContext.brandText.length > 0) {
    [lines addObject:[NSString stringWithFormat:@"Brand: %@", productContext.brandText]];
  }
  if (productContext.quantityText.length > 0) {
    [lines addObject:[NSString stringWithFormat:@"Pack size: %@", productContext.quantityText]];
  }
  if (productContext.nutritionGradeText.length > 0) {
    [lines addObject:[NSString stringWithFormat:@"Nutrition grade: %@", productContext.nutritionGradeText]];
  }

  UILabel *bodyLabel = [self buildLabelWithText:[lines componentsJoinedByString:@"\n"]
                                           font:[UIFont systemFontOfSize:15.0]
                                          color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                              [UIColor colorWithWhite:0.70 alpha:1.0])];
  bodyLabel.numberOfLines = 0;
  bodyLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"productContextBodyLabel"];
  [stackView addArrangedSubview:bodyLabel];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  return cardView;
}

- (UIView *)sourceAttributionViewForRecipeDetail:(OnboardingRecipeDetail *)recipeDetail {
  if (recipeDetail.sourceName.length == 0 && recipeDetail.sourceURLString.length == 0) {
    return nil;
  }

  UIView *cardView =
      [self recipeSurfaceCardViewWithAccessibilityIdentifier:[self detailIdentifierForSuffix:@"sourceCardView"] prominent:NO];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 10.0;
  [cardView addSubview:stackView];

  UILabel *titleLabel =
      [self sectionTitleLabelWithText:@"Source" accessibilityIdentifier:[self detailIdentifierForSuffix:@"sourceTitleLabel"]];
  [stackView addArrangedSubview:titleLabel];

  NSString *captionText = recipeDetail.sourceName.length > 0 ? recipeDetail.sourceName : recipeDetail.sourceURLString;
  UILabel *captionLabel = [self buildLabelWithText:captionText
                                              font:[UIFont systemFontOfSize:15.0]
                                             color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.70 alpha:1.0])];
  captionLabel.numberOfLines = 0;
  captionLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"sourceCaptionLabel"];
  [stackView addArrangedSubview:captionLabel];

  if (recipeDetail.sourceURLString.length > 0) {
    UIButton *sourceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sourceButton.translatesAutoresizingMaskIntoConstraints = NO;
    sourceButton.accessibilityIdentifier = [self detailIdentifierForSuffix:@"sourceButton"];
    [sourceButton setTitle:@"View Source" forState:UIControlStateNormal];
    [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleInline toButton:sourceButton];
    [self configurePressFeedbackForButton:sourceButton];
    [sourceButton addTarget:self action:@selector(didTapSourceButton) forControlEvents:UIControlEventTouchUpInside];
    [stackView addArrangedSubview:sourceButton];
  }

  [NSLayoutConstraint activateConstraints:@[
    [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
    [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0]
  ]];

  return cardView;
}

- (UIView *)debugOriginBadgeViewIfNeeded {
#if DEBUG
  if (self.debugOrigin == OnboardingRecipeDetailDebugOriginUnknown) {
    return nil;
  }

  NSString *badgeText = self.debugOrigin == OnboardingRecipeDetailDebugOriginLive ? @"LIVE" : @"FALLBACK";
  UIColor *badgeTintColor =
      self.debugOrigin == OnboardingRecipeDetailDebugOriginLive ? [UIColor colorWithRed:0.16 green:0.56 blue:0.32 alpha:1.0]
                                                                : [UIColor colorWithRed:0.82 green:0.48 blue:0.16 alpha:1.0];

  UIView *badgeView = [[[UIView alloc] init] autorelease];
  badgeView.translatesAutoresizingMaskIntoConstraints = NO;
  badgeView.accessibilityIdentifier = [self detailIdentifierForSuffix:@"debugSourceBadge"];
  badgeView.backgroundColor = [badgeTintColor colorWithAlphaComponent:0.12];
  badgeView.layer.cornerRadius = 10.0;
  badgeView.layer.borderWidth = 1.0;
  badgeView.layer.borderColor = [badgeTintColor colorWithAlphaComponent:0.28].CGColor;

  UILabel *label = [self buildLabelWithText:badgeText
                                       font:[UIFont systemFontOfSize:11.0 weight:UIFontWeightBold]
                                      color:badgeTintColor];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.accessibilityIdentifier = [self detailIdentifierForSuffix:@"debugSourceBadge.label"];
  [badgeView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [label.topAnchor constraintEqualToAnchor:badgeView.topAnchor constant:5.0],
    [label.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:9.0],
    [label.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-9.0],
    [label.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor constant:-5.0]
  ]];

  return badgeView;
#else
  return nil;
#endif
}

- (NSString *)detailIdentifierForSuffix:(NSString *)suffix {
  return [NSString stringWithFormat:@"onboarding.recipeDetail.%@", suffix];
}

#pragma mark - Actions

- (void)didTapCloseButton {
  [self.delegate recipeDetailViewControllerDidClose:self];
}

- (void)didTapStartCookingButton {
  if (!self.startButton.enabled) {
    return;
  }

  [self.delegate recipeDetailViewControllerDidStartCooking:self];
}

- (void)didTapIngredientsToggleButton {
  self.ingredientsExpanded = !self.ingredientsExpanded;
  [self refreshIngredientsSectionAnimated:YES];
}

- (void)didTapInstructionsToggleButton {
  self.instructionsExpanded = !self.instructionsExpanded;
  [self refreshInstructionsSectionAnimated:YES];
}

- (void)didTapToolsToggleButton {
  self.toolsExpanded = !self.toolsExpanded;
  [self refreshToolsSectionAnimated:YES];
}

- (void)didTapTagsToggleButton {
  self.tagsExpanded = !self.tagsExpanded;
  [self refreshTagsSectionAnimated:YES];
}

- (void)didTapSummaryToggleButton {
  self.summaryExpanded = !self.summaryExpanded;
  [self refreshSummaryExpansionStateAnimated:YES];
}

- (void)didTapSourceButton {
  NSString *sourceURLString = self.recipeDetail.sourceURLString;
  NSURL *sourceURL = sourceURLString.length > 0 ? [NSURL URLWithString:sourceURLString] : nil;
  if (sourceURL == nil) {
    return;
  }

  if (@available(iOS 10.0, *)) {
    [[UIApplication sharedApplication] openURL:sourceURL options:@{} completionHandler:nil];
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[UIApplication sharedApplication] openURL:sourceURL];
#pragma clang diagnostic pop
}

- (void)updateLayoutMetricsIfNeeded {
  BOOL usesNavigationChrome = [self usesNavigationPresentationChrome];
  CGSize viewportSize = [self layoutViewportSize];
  if (viewportSize.width <= 0.0 || viewportSize.height <= 0.0) {
    return;
  }

  CGFloat cardTopInset = MRRLayoutScaledValue(14.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat cardSideInset = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat cardBottomInset = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat cardCornerRadius = MRRLayoutScaledValue(30.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  CGFloat headerHeight = MRRLayoutScaledValue(MRRRecipeDetailHeaderHeight, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat closeButtonInset = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat closeButtonSize = MRRLayoutScaledValue(38.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  CGFloat topSafeInset = CGRectGetMinY(self.view.safeAreaLayoutGuide.layoutFrame);
  CGFloat contentTopInset = -MRRLayoutScaledValue(56.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat contentSideInset = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat contentBottomInset = MRRLayoutScaledValue(28.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat stackSpacing = MRRLayoutScaledValue(16.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat subtitleFontSize = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat titleFontSize = MRRLayoutScaledValue(32.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat summaryFontSize = MRRLayoutScaledValue(16.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat prominentCardCornerRadius = MRRLayoutScaledValue(28.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  CGFloat sectionCardCornerRadius = MRRLayoutScaledValue(22.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  CGFloat startButtonHeight = MRRLayoutScaledValue(60.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat startButtonVerticalInset = MRRLayoutScaledValue(17.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat startButtonHorizontalInset = MRRLayoutScaledValue(20.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat startButtonFontSize = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisWidth);
  if (self.closeButton != nil) {
    self.closeButtonTopConstraint.constant = usesNavigationChrome ? topSafeInset + closeButtonInset : closeButtonInset;
    self.closeButtonTrailingConstraint.constant = -closeButtonInset;
    self.closeButtonWidthConstraint.constant = closeButtonSize;
    self.closeButtonHeightConstraint.constant = closeButtonSize;
    self.closeButton.layer.cornerRadius = closeButtonSize / 2.0;
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:MRRLayoutScaledValue(20.0, viewportSize, MRRLayoutScaleAxisWidth)];
  }

  if (!usesNavigationChrome) {
    self.cardTopConstraint.constant = cardTopInset;
    self.cardLeadingConstraint.constant = cardSideInset;
    self.cardTrailingConstraint.constant = -cardSideInset;
    self.cardBottomConstraint.constant = -cardBottomInset;
    self.cardView.layer.cornerRadius = cardCornerRadius;
  }
  self.heroContainerHeightConstraint.constant = headerHeight;
  self.contentStackTopConstraint.constant = contentTopInset;
  self.contentStackLeadingConstraint.constant = contentSideInset;
  self.contentStackTrailingConstraint.constant = -contentSideInset;
  self.contentStackBottomConstraint.constant = -contentBottomInset;
  self.contentStackView.spacing = stackSpacing;
  if (self.headerCardView != nil) {
    self.headerCardView.layer.cornerRadius = prominentCardCornerRadius;
  }
  if (self.subtitleLabel != nil) {
    self.subtitleLabel.font = [UIFont boldSystemFontOfSize:subtitleFontSize];
  }
  if (self.titleLabel != nil) {
    self.titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
  }
  if (self.summaryCardView != nil) {
    self.summaryCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  if (self.ingredientsSectionCardView != nil) {
    self.ingredientsSectionCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  if (self.instructionsSectionCardView != nil) {
    self.instructionsSectionCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  if (self.toolsSectionCardView != nil) {
    self.toolsSectionCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  if (self.tagsSectionCardView != nil) {
    self.tagsSectionCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  [self refreshTagSectionLayoutIfNeededForViewportWidth:viewportSize.width];
  if (self.tagsSectionCardView != nil) {
    self.tagsSectionCardView.layer.cornerRadius = sectionCardCornerRadius;
  }
  if (self.summaryEyebrowLabel != nil) {
    self.summaryEyebrowLabel.font = [UIFont systemFontOfSize:MRRLayoutScaledValue(11.0, viewportSize, MRRLayoutScaleAxisWidth)
                                                     weight:UIFontWeightBold];
  }
  if (self.summaryLabel != nil) {
    self.summaryLabel.font = [UIFont systemFontOfSize:summaryFontSize];
  }
  [self updateSummaryToggleButtonAppearance];
  self.startButtonHeightConstraint.constant = startButtonHeight;
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *configuration = self.startButton.configuration;
    if (configuration != nil) {
      UIColor *startButtonTitleColor = [MRRLiquidGlassStyling supportsNativeLiquidGlass]
                                           ? MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                           [UIColor colorWithWhite:0.96 alpha:1.0])
                                           : [UIColor whiteColor];
      configuration.contentInsets = NSDirectionalEdgeInsetsMake(startButtonVerticalInset, startButtonHorizontalInset, startButtonVerticalInset,
                                                                startButtonHorizontalInset);
      configuration.attributedTitle = [[[NSAttributedString alloc] initWithString:@"Start Cooking"
                                                                       attributes:@{
                                                                         NSFontAttributeName : [UIFont boldSystemFontOfSize:startButtonFontSize],
                                                                         NSForegroundColorAttributeName : startButtonTitleColor
                                                                       }] autorelease];
      self.startButton.configuration = configuration;
    }
  } else {
    self.startButton.titleLabel.font = [UIFont boldSystemFontOfSize:startButtonFontSize];
  }

  CGFloat offsetY = self.scrollView.contentOffset.y;
  if (offsetY < 0.0) {
    self.heroImageTopConstraint.constant = offsetY;
    self.heroImageHeightConstraint.constant = headerHeight - offsetY;
  } else {
    self.heroImageTopConstraint.constant = -offsetY * 0.32;
    self.heroImageHeightConstraint.constant = headerHeight;
  }
}

- (CGSize)layoutViewportSize {
  CGRect safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
  if (CGRectGetWidth(safeFrame) > 0.0 && CGRectGetHeight(safeFrame) > 0.0) {
    return safeFrame.size;
  }

  return self.view.bounds.size;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  CGFloat offsetY = scrollView.contentOffset.y;
  CGFloat headerHeight = self.heroContainerHeightConstraint.constant > 0.0 ? self.heroContainerHeightConstraint.constant : MRRRecipeDetailHeaderHeight;
  if (offsetY < 0.0) {
    self.heroImageTopConstraint.constant = offsetY;
    self.heroImageHeightConstraint.constant = headerHeight - offsetY;
    return;
  }

  self.heroImageTopConstraint.constant = -offsetY * 0.32;
  self.heroImageHeightConstraint.constant = headerHeight;
}

@end
