#import "SavedViewController.h"

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

static UIColor *MRRSavedDividerColor(void) {
  return MRRSavedBorderColor();
}

static UIColor *MRRSavedChipFillColor(void) {
  return MRRSavedMutedSurfaceColor();
}

static UIColor *MRRSavedHeartBubbleColor(void) {
  return MRRSavedDynamicFallbackColor([UIColor colorWithRed:0.93 green:0.43 blue:0.54 alpha:1.0],
                                      [UIColor colorWithRed:0.85 green:0.35 blue:0.48 alpha:1.0]);
}

static UIImage *MRRSavedSymbolImage(NSString *systemName, CGFloat pointSize, CGFloat weight) {
  if (@available(iOS 13.0, *)) {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:(UIImageSymbolWeight)weight];
    return [UIImage systemImageNamed:systemName withConfiguration:configuration];
  }

  return nil;
}

static NSDictionary<NSString *, id> *MRRSavedRecipe(NSString *identifier,
                                                    NSString *title,
                                                    NSString *assetName,
                                                    NSString *durationText,
                                                    NSString *popularityText) {
  return @{
    @"identifier" : identifier,
    @"title" : title,
    @"assetName" : assetName,
    @"durationText" : durationText,
    @"popularityText" : popularityText
  };
}

static NSDictionary<NSString *, id> *MRRSavedSection(NSString *identifier,
                                                     NSString *title,
                                                     NSString *countText,
                                                     NSArray<NSDictionary<NSString *, id> *> *recipes) {
  return @{
    @"identifier" : identifier,
    @"title" : title,
    @"countText" : countText,
    @"recipes" : recipes
  };
}

static NSArray<NSDictionary<NSString *, id> *> *MRRSavedSections(void) {
  static NSArray<NSDictionary<NSString *, id> *> *sections = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sections = [@[
      MRRSavedSection(@"salad", @"Salad", @"2", @[
        MRRSavedRecipe(@"caesarCrunch", @"Garden Caesar Crunch", @"avocado-toast", @"20 mins", @"140k views"),
        MRRSavedRecipe(@"spinachFeta", @"Spinach & Blueberry Feta Salad", @"greek-salad", @"15 mins", @"120k views")
      ]),
      MRRSavedSection(@"dessert", @"Dessert", @"10", @[]),
      MRRSavedSection(@"mainCourse", @"Main Course", @"4", @[]),
      MRRSavedSection(@"breakfast", @"Breakfast", @"2", @[]),
      MRRSavedSection(@"soup", @"Soup", @"5", @[])
    ] retain];
  });

  return sections;
}

@interface SavedViewController ()

@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIStackView *sectionsStackView;
@property(nonatomic, copy) NSString *expandedSectionIdentifier;

- (void)buildViewHierarchy;
- (void)reloadSections;
- (UIView *)sectionViewForSection:(NSDictionary<NSString *, id> *)section
                          atIndex:(NSUInteger)index
                         expanded:(BOOL)expanded;
- (UIView *)recipeCardViewForRecipe:(NSDictionary<NSString *, id> *)recipe;
- (UIView *)chipViewWithText:(NSString *)text;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (void)handleSectionTapped:(UIControl *)sender;

@end

@implementation SavedViewController

- (instancetype)init {
  return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc {
  [_expandedSectionIdentifier release];
  [_sectionsStackView release];
  [_contentView release];
  [_scrollView release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.expandedSectionIdentifier = @"salad";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"saved.view";
  self.view.backgroundColor = MRRSavedCanvasColor();

  [self buildViewHierarchy];
  [self reloadSections];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.alwaysBounceVertical = YES;
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

- (void)reloadSections {
  while (self.sectionsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.sectionsStackView.arrangedSubviews.firstObject;
    [self.sectionsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  NSArray<NSDictionary<NSString *, id> *> *sections = MRRSavedSections();
  for (NSUInteger index = 0; index < sections.count; index += 1) {
    NSDictionary<NSString *, id> *section = sections[index];
    NSString *identifier = section[@"identifier"];
    BOOL expanded = [self.expandedSectionIdentifier isEqualToString:identifier];
    [self.sectionsStackView addArrangedSubview:[self sectionViewForSection:section atIndex:index expanded:expanded]];
  }
}

- (UIView *)sectionViewForSection:(NSDictionary<NSString *, id> *)section
                          atIndex:(NSUInteger)index
                         expanded:(BOOL)expanded {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.backgroundColor = [UIColor clearColor];

  UIControl *headerControl = [[[UIControl alloc] init] autorelease];
  headerControl.translatesAutoresizingMaskIntoConstraints = NO;
  headerControl.tag = index;
  headerControl.accessibilityIdentifier = [NSString stringWithFormat:@"saved.sectionHeader.%@", section[@"identifier"]];
  headerControl.accessibilityLabel = [NSString stringWithFormat:@"%@, %@ saved recipes", section[@"title"], section[@"countText"]];
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
  countLabel.text = section[@"countText"];
  countLabel.adjustsFontForContentSizeCategory = YES;
  [headerControl addSubview:countLabel];

  UIImageView *chevronImageView = [[[UIImageView alloc] initWithImage:MRRSavedSymbolImage(expanded ? @"chevron.up" : @"chevron.down",
                                                                                            16.0,
                                                                                            UIFontWeightSemibold)] autorelease];
  chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
  chevronImageView.tintColor = MRRSavedPrimaryTextColor();
  [headerControl addSubview:chevronImageView];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor = MRRSavedDividerColor();
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
    [chevronImageView.widthAnchor constraintEqualToConstant:18.0],
    [chevronImageView.heightAnchor constraintEqualToConstant:18.0],

    [countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevronImageView.leadingAnchor constant:-12.0],

    [dividerView.topAnchor constraintEqualToAnchor:headerControl.bottomAnchor constant:14.0],
    [dividerView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [dividerView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    [dividerView.heightAnchor constraintEqualToConstant:1.0]
  ]];

  NSArray<NSDictionary<NSString *, id> *> *recipes = section[@"recipes"];
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

      for (NSDictionary<NSString *, id> *recipe in recipes) {
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
      placeholderView.layer.borderColor = [MRRSavedDividerColor() CGColor];
      [contentContainer addSubview:placeholderView];

      UILabel *placeholderLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                                color:MRRSavedSecondaryTextColor()];
      placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
      placeholderLabel.numberOfLines = 0;
      placeholderLabel.textAlignment = NSTextAlignmentCenter;
      placeholderLabel.text = [NSString stringWithFormat:@"Your %@ collection is ready for the next recipe worth keeping.",
                                                          [section[@"title"] lowercaseString]];
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

- (UIView *)recipeCardViewForRecipe:(NSDictionary<NSString *, id> *)recipe {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.backgroundColor = [UIColor clearColor];
  cardView.accessibilityIdentifier = [NSString stringWithFormat:@"saved.recipeCard.%@", recipe[@"identifier"]];
  cardView.isAccessibilityElement = YES;
  cardView.accessibilityTraits = UIAccessibilityTraitButton;
  cardView.accessibilityLabel =
      [NSString stringWithFormat:@"%@, %@, %@", recipe[@"title"], recipe[@"durationText"], recipe[@"popularityText"]];
  cardView.accessibilityHint = @"Saved recipe preview.";

  UIView *imageContainerView = [[[UIView alloc] init] autorelease];
  imageContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  imageContainerView.backgroundColor = MRRSavedMutedSurfaceColor();
  imageContainerView.layer.cornerRadius = 30.0;
  imageContainerView.layer.masksToBounds = YES;
  [cardView addSubview:imageContainerView];

  UIImageView *imageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:recipe[@"assetName"]]] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  imageView.layer.cornerRadius = 30.0;
  [imageContainerView addSubview:imageView];

  UIView *favoriteBubbleView = [[[UIView alloc] init] autorelease];
  favoriteBubbleView.translatesAutoresizingMaskIntoConstraints = NO;
  favoriteBubbleView.backgroundColor = MRRSavedHeartBubbleColor();
  favoriteBubbleView.layer.cornerRadius = 21.0;
  favoriteBubbleView.layer.shadowColor = [UIColor blackColor].CGColor;
  favoriteBubbleView.layer.shadowOpacity = 0.12f;
  favoriteBubbleView.layer.shadowRadius = 14.0f;
  favoriteBubbleView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
  [imageContainerView addSubview:favoriteBubbleView];

  UIImageView *heartImageView = [[[UIImageView alloc] initWithImage:MRRSavedSymbolImage(@"heart.fill", 16.0, UIFontWeightBold)] autorelease];
  heartImageView.translatesAutoresizingMaskIntoConstraints = NO;
  heartImageView.tintColor = [UIColor whiteColor];
  [favoriteBubbleView addSubview:heartImageView];

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold] color:MRRSavedPrimaryTextColor()];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.numberOfLines = 2;
  titleLabel.adjustsFontForContentSizeCategory = YES;
  titleLabel.text = recipe[@"title"];
  [cardView addSubview:titleLabel];

  UIStackView *chipsStackView = [[[UIStackView alloc] init] autorelease];
  chipsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  chipsStackView.axis = UILayoutConstraintAxisHorizontal;
  chipsStackView.spacing = 8.0;
  chipsStackView.alignment = UIStackViewAlignmentLeading;
  [chipsStackView addArrangedSubview:[self chipViewWithText:recipe[@"durationText"]]];
  [chipsStackView addArrangedSubview:[self chipViewWithText:recipe[@"popularityText"]]];
  [cardView addSubview:chipsStackView];

  [NSLayoutConstraint activateConstraints:@[
    [imageContainerView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [imageContainerView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [imageContainerView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [imageContainerView.heightAnchor constraintEqualToAnchor:imageContainerView.widthAnchor multiplier:1.20],

    [imageView.topAnchor constraintEqualToAnchor:imageContainerView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:imageContainerView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:imageContainerView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor],

    [favoriteBubbleView.widthAnchor constraintEqualToConstant:42.0],
    [favoriteBubbleView.heightAnchor constraintEqualToConstant:42.0],
    [favoriteBubbleView.trailingAnchor constraintEqualToAnchor:imageContainerView.trailingAnchor constant:-12.0],
    [favoriteBubbleView.bottomAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor constant:-12.0],

    [heartImageView.centerXAnchor constraintEqualToAnchor:favoriteBubbleView.centerXAnchor],
    [heartImageView.centerYAnchor constraintEqualToAnchor:favoriteBubbleView.centerYAnchor],
    [heartImageView.widthAnchor constraintEqualToConstant:18.0],
    [heartImageView.heightAnchor constraintEqualToConstant:18.0],

    [titleLabel.topAnchor constraintEqualToAnchor:imageContainerView.bottomAnchor constant:14.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],

    [chipsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [chipsStackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [chipsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor],
    [chipsStackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor]
  ]];

  return cardView;
}

- (UIView *)chipViewWithText:(NSString *)text {
  UIView *chipView = [[[UIView alloc] init] autorelease];
  chipView.translatesAutoresizingMaskIntoConstraints = NO;
  chipView.backgroundColor = MRRSavedChipFillColor();
  chipView.layer.cornerRadius = 14.0;

  UILabel *label = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRSavedPrimaryTextColor()];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.text = text;
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
  return label;
}

- (void)handleSectionTapped:(UIControl *)sender {
  NSDictionary<NSString *, id> *section = MRRSavedSections()[sender.tag];
  NSString *identifier = section[@"identifier"];
  BOOL willExpand = ![self.expandedSectionIdentifier isEqualToString:identifier];
  self.expandedSectionIdentifier = willExpand ? identifier : nil;

  [UIView transitionWithView:self.sectionsStackView
                    duration:0.28
                     options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                  animations:^{
                    [self reloadSections];
                    [self.view layoutIfNeeded];
                  }
                  completion:nil];
}

@end
