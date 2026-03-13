#import "OnboardingRecipeDetailViewController.h"

#import "../../../../Layout/MRRLayoutScaling.h"
#import "../../Data/OnboardingStateController.h"

static CGFloat const MRRRecipeDetailHeaderHeight = 292.0;

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

@interface OnboardingRecipeDetailViewController () <UIScrollViewDelegate>

@property(nonatomic, retain, readwrite) OnboardingRecipe *recipe;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIImageView *heroImageView;
@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UIButton *closeButton;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UILabel *subtitleLabel;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *summaryLabel;
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

- (void)buildViewHierarchy;
- (UILabel *)buildLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UILabel *)sectionTitleLabelWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)metadataChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)ingredientGridViewForIngredients:(NSArray<NSString *> *)ingredients;
- (UIView *)ingredientChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UIView *)instructionsStackViewForInstructions:(NSArray<OnboardingRecipeInstruction *> *)instructions;
- (UIView *)instructionRowForInstruction:(OnboardingRecipeInstruction *)instruction index:(NSUInteger)index;
- (NSString *)detailIdentifierForSuffix:(NSString *)suffix;
- (void)didTapCloseButton;
- (void)didTapStartCookingButton;
- (void)updateLayoutMetricsIfNeeded;
- (CGSize)layoutViewportSize;

@end

@implementation OnboardingRecipeDetailViewController

- (instancetype)initWithRecipe:(OnboardingRecipe *)recipe {
  NSParameterAssert(recipe != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _recipe = [recipe retain];
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
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
  [_summaryLabel release];
  [_titleLabel release];
  [_subtitleLabel release];
  [_contentStackView release];
  [_closeButton release];
  [_cardView release];
  [_heroImageView release];
  [_scrollView release];
  [_recipe release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.58];
  self.view.accessibilityIdentifier = @"onboarding.recipeDetail.view";

  [self buildViewHierarchy];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  [self updateLayoutMetricsIfNeeded];
}

#pragma mark - View Setup

- (void)buildViewHierarchy {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.backgroundColor = MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.14 alpha:1.0]);
  cardView.layer.cornerRadius = 30.0;
  cardView.layer.masksToBounds = YES;
  cardView.layer.borderWidth = 1.0;
  cardView.layer.borderColor = [[MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.45 alpha:1.0],
                                               [UIColor colorWithWhite:0.62 alpha:1.0]) colorWithAlphaComponent:0.18] CGColor];
  [self.view addSubview:cardView];
  self.cardView = cardView;

  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.delegate = self;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  [cardView addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];

  UIView *heroContainerView = [[[UIView alloc] init] autorelease];
  heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  heroContainerView.clipsToBounds = YES;
  [contentView addSubview:heroContainerView];

  UIImageView *heroImageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:self.recipe.assetName]] autorelease];
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
  [closeButton addTarget:self action:@selector(didTapCloseButton) forControlEvents:UIControlEventTouchUpInside];
  [heroContainerView addSubview:closeButton];
  self.closeButton = closeButton;

  UIStackView *contentStackView = [[[UIStackView alloc] init] autorelease];
  contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
  contentStackView.axis = UILayoutConstraintAxisVertical;
  contentStackView.spacing = 18.0;
  [contentView addSubview:contentStackView];
  self.contentStackView = contentStackView;

  UILabel *subtitleLabel = [self buildLabelWithText:[self.recipe.subtitle uppercaseString]
                                               font:[UIFont boldSystemFontOfSize:12.0]
                                              color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                  [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  subtitleLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"subtitleLabel"];
  [contentStackView addArrangedSubview:subtitleLabel];
  self.subtitleLabel = subtitleLabel;

  UILabel *titleLabel = [self buildLabelWithText:self.recipe.title
                                            font:[UIFont boldSystemFontOfSize:32.0]
                                           color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  titleLabel.numberOfLines = 0;
  titleLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"titleLabel"];
  [contentStackView addArrangedSubview:titleLabel];
  self.titleLabel = titleLabel;

  UIStackView *metadataStackView = [[[UIStackView alloc] init] autorelease];
  metadataStackView.axis = UILayoutConstraintAxisHorizontal;
  metadataStackView.spacing = 10.0;
  metadataStackView.alignment = UIStackViewAlignmentFill;
  metadataStackView.distribution = UIStackViewDistributionFillProportionally;
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipe.durationText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"durationChip"]]];
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipe.calorieText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"calorieChip"]]];
  [metadataStackView addArrangedSubview:[self metadataChipWithText:self.recipe.servingsText
                                           accessibilityIdentifier:[self detailIdentifierForSuffix:@"servingsChip"]]];
  [contentStackView addArrangedSubview:metadataStackView];

  UILabel *summaryLabel = [self buildLabelWithText:self.recipe.summaryText
                                              font:[UIFont systemFontOfSize:16.0]
                                             color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.70 alpha:1.0])];
  summaryLabel.numberOfLines = 0;
  summaryLabel.accessibilityIdentifier = [self detailIdentifierForSuffix:@"summaryLabel"];
  [contentStackView addArrangedSubview:summaryLabel];
  self.summaryLabel = summaryLabel;

  UILabel *ingredientsTitleLabel =
      [self sectionTitleLabelWithText:@"Ingredients" accessibilityIdentifier:[self detailIdentifierForSuffix:@"ingredientsTitleLabel"]];
  [contentStackView addArrangedSubview:ingredientsTitleLabel];
  UIView *ingredientsGridView = [self ingredientGridViewForIngredients:self.recipe.ingredients];
  [contentStackView addArrangedSubview:ingredientsGridView];

  UILabel *instructionsTitleLabel =
      [self sectionTitleLabelWithText:@"Method" accessibilityIdentifier:[self detailIdentifierForSuffix:@"instructionsTitleLabel"]];
  [contentStackView addArrangedSubview:instructionsTitleLabel];
  UIView *instructionsStackView = [self instructionsStackViewForInstructions:self.recipe.instructions];
  [contentStackView addArrangedSubview:instructionsStackView];

  UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
  startButton.translatesAutoresizingMaskIntoConstraints = NO;
  startButton.accessibilityIdentifier = @"onboarding.recipeDetail.startCookingButton";
  startButton.backgroundColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                              [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  startButton.layer.cornerRadius = 18.0;
  startButton.contentEdgeInsets = UIEdgeInsetsMake(17.0, 20.0, 17.0, 20.0);
  startButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
  [startButton setTitle:@"Start Cooking" forState:UIControlStateNormal];
  [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [startButton addTarget:self action:@selector(didTapStartCookingButton) forControlEvents:UIControlEventTouchUpInside];
  [contentStackView addArrangedSubview:startButton];
  self.startButton = startButton;

  self.cardTopConstraint = [cardView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0];
  self.cardLeadingConstraint = [cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0];
  self.cardTrailingConstraint = [cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0];
  self.cardBottomConstraint = [cardView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0];
  self.heroContainerHeightConstraint = [heroContainerView.heightAnchor constraintEqualToConstant:MRRRecipeDetailHeaderHeight];
  self.closeButtonTopConstraint = [closeButton.topAnchor constraintEqualToAnchor:heroContainerView.topAnchor constant:18.0];
  self.closeButtonTrailingConstraint = [closeButton.trailingAnchor constraintEqualToAnchor:heroContainerView.trailingAnchor constant:-18.0];
  self.closeButtonWidthConstraint = [closeButton.widthAnchor constraintEqualToConstant:38.0];
  self.closeButtonHeightConstraint = [closeButton.heightAnchor constraintEqualToConstant:38.0];
  self.contentStackTopConstraint = [contentStackView.topAnchor constraintEqualToAnchor:heroContainerView.bottomAnchor constant:24.0];
  self.contentStackLeadingConstraint = [contentStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0];
  self.contentStackTrailingConstraint = [contentStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0];
  self.contentStackBottomConstraint = [contentStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0];
  self.startButtonHeightConstraint = [startButton.heightAnchor constraintGreaterThanOrEqualToConstant:60.0];

  [NSLayoutConstraint activateConstraints:@[
    self.cardTopConstraint,
    self.cardLeadingConstraint,
    self.cardTrailingConstraint,
    self.cardBottomConstraint,

    [scrollView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

    [heroContainerView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
    [heroContainerView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [heroContainerView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    self.heroContainerHeightConstraint,

    self.closeButtonTopConstraint,
    self.closeButtonTrailingConstraint,
    self.closeButtonWidthConstraint,
    self.closeButtonHeightConstraint,

    self.contentStackTopConstraint,
    self.contentStackLeadingConstraint,
    self.contentStackTrailingConstraint,
    self.contentStackBottomConstraint,

    self.startButtonHeightConstraint
  ]];

  self.heroImageTopConstraint = [heroImageView.topAnchor constraintEqualToAnchor:heroContainerView.topAnchor];
  self.heroImageHeightConstraint = [heroImageView.heightAnchor constraintEqualToConstant:MRRRecipeDetailHeaderHeight];
  [NSLayoutConstraint activateConstraints:@[
    self.heroImageTopConstraint,
    [heroImageView.leadingAnchor constraintEqualToAnchor:heroContainerView.leadingAnchor],
    [heroImageView.trailingAnchor constraintEqualToAnchor:heroContainerView.trailingAnchor],
    self.heroImageHeightConstraint
  ]];
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

- (UIView *)metadataChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.accessibilityIdentifier = accessibilityIdentifier;
  chipView.backgroundColor = [MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]) colorWithAlphaComponent:0.12];
  chipView.layer.cornerRadius = 14.0;

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

- (UIView *)ingredientGridViewForIngredients:(NSArray<NSString *> *)ingredients {
  UIStackView *rowsStackView = [[[UIStackView alloc] init] autorelease];
  rowsStackView.axis = UILayoutConstraintAxisVertical;
  rowsStackView.spacing = 10.0;
  rowsStackView.translatesAutoresizingMaskIntoConstraints = NO;

  for (NSUInteger index = 0; index < ingredients.count; index += 2) {
    UIStackView *rowStackView = [[[UIStackView alloc] init] autorelease];
    rowStackView.axis = UILayoutConstraintAxisHorizontal;
    rowStackView.spacing = 10.0;
    rowStackView.distribution = UIStackViewDistributionFillEqually;

    [rowStackView addArrangedSubview:[self ingredientChipWithText:ingredients[index]
                                          accessibilityIdentifier:[self detailIdentifierForSuffix:[NSString stringWithFormat:
                                                                                                  @"ingredientChip.%lu",
                                                                                                  (unsigned long)(index + 1)]]]];
    if (index + 1 < ingredients.count) {
      [rowStackView addArrangedSubview:[self ingredientChipWithText:ingredients[index + 1]
                                            accessibilityIdentifier:[self detailIdentifierForSuffix:[NSString stringWithFormat:
                                                                                                    @"ingredientChip.%lu",
                                                                                                    (unsigned long)(index + 2)]]]];
    } else {
      UIView *placeholderView = [[[UIView alloc] init] autorelease];
      [rowStackView addArrangedSubview:placeholderView];
    }

    [rowsStackView addArrangedSubview:rowStackView];
  }

  return rowsStackView;
}

- (UIView *)ingredientChipWithText:(NSString *)text accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.accessibilityIdentifier = accessibilityIdentifier;
  chipView.backgroundColor = MRRNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.97 alpha:1.0],
                                           [UIColor colorWithWhite:0.10 alpha:1.0]);
  chipView.layer.cornerRadius = 16.0;
  chipView.layer.borderWidth = 1.0;
  chipView.layer.borderColor = [[MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                               [UIColor colorWithWhite:0.68 alpha:1.0]) colorWithAlphaComponent:0.14] CGColor];

  UILabel *label = [self buildLabelWithText:text
                                       font:[UIFont systemFontOfSize:14.0]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                          [UIColor colorWithWhite:0.96 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.numberOfLines = 0;
  label.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".label"];
  [chipView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [label.topAnchor constraintEqualToAnchor:chipView.topAnchor constant:12.0],
    [label.leadingAnchor constraintEqualToAnchor:chipView.leadingAnchor constant:12.0],
    [label.trailingAnchor constraintEqualToAnchor:chipView.trailingAnchor constant:-12.0],
    [label.bottomAnchor constraintEqualToAnchor:chipView.bottomAnchor constant:-12.0]
  ]];

  return chipView;
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
  badgeView.backgroundColor = [MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                             [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]) colorWithAlphaComponent:0.14];
  badgeView.layer.cornerRadius = 18.0;
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

- (NSString *)detailIdentifierForSuffix:(NSString *)suffix {
  return [NSString stringWithFormat:@"onboarding.recipeDetail.%@", suffix];
}

#pragma mark - Actions

- (void)didTapCloseButton {
  [self.delegate recipeDetailViewControllerDidClose:self];
}

- (void)didTapStartCookingButton {
  [self.delegate recipeDetailViewControllerDidStartCooking:self];
}

- (void)updateLayoutMetricsIfNeeded {
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
  CGFloat contentTopInset = MRRLayoutScaledValue(24.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat contentSideInset = MRRLayoutScaledValue(24.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat contentBottomInset = MRRLayoutScaledValue(28.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat stackSpacing = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat subtitleFontSize = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat titleFontSize = MRRLayoutScaledValue(32.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat summaryFontSize = MRRLayoutScaledValue(16.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat startButtonHeight = MRRLayoutScaledValue(60.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat startButtonCornerRadius = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  CGFloat startButtonVerticalInset = MRRLayoutScaledValue(17.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat startButtonHorizontalInset = MRRLayoutScaledValue(20.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat startButtonFontSize = MRRLayoutScaledValue(18.0, viewportSize, MRRLayoutScaleAxisWidth);

  self.cardTopConstraint.constant = cardTopInset;
  self.cardLeadingConstraint.constant = cardSideInset;
  self.cardTrailingConstraint.constant = -cardSideInset;
  self.cardBottomConstraint.constant = -cardBottomInset;
  self.cardView.layer.cornerRadius = cardCornerRadius;
  self.heroContainerHeightConstraint.constant = headerHeight;
  self.closeButtonTopConstraint.constant = closeButtonInset;
  self.closeButtonTrailingConstraint.constant = -closeButtonInset;
  self.closeButtonWidthConstraint.constant = closeButtonSize;
  self.closeButtonHeightConstraint.constant = closeButtonSize;
  self.closeButton.layer.cornerRadius = closeButtonSize / 2.0;
  self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:MRRLayoutScaledValue(20.0, viewportSize, MRRLayoutScaleAxisWidth)];
  self.contentStackTopConstraint.constant = contentTopInset;
  self.contentStackLeadingConstraint.constant = contentSideInset;
  self.contentStackTrailingConstraint.constant = -contentSideInset;
  self.contentStackBottomConstraint.constant = -contentBottomInset;
  self.contentStackView.spacing = stackSpacing;
  self.subtitleLabel.font = [UIFont boldSystemFontOfSize:subtitleFontSize];
  self.titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
  self.summaryLabel.font = [UIFont systemFontOfSize:summaryFontSize];
  self.startButtonHeightConstraint.constant = startButtonHeight;
  self.startButton.layer.cornerRadius = startButtonCornerRadius;
  self.startButton.contentEdgeInsets = UIEdgeInsetsMake(startButtonVerticalInset, startButtonHorizontalInset, startButtonVerticalInset,
                                                        startButtonHorizontalInset);
  self.startButton.titleLabel.font = [UIFont boldSystemFontOfSize:startButtonFontSize];

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
