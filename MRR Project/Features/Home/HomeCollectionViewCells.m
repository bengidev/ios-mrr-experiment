#import "HomeCollectionViewCells.h"

static UIColor *MRRHomeCellDynamicColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRHomeCellNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeCellDynamicColor(lightColor, darkColor);
}

static UIColor *MRRHomeCategoryBadgeColor(NSString *identifier) {
  if ([identifier isEqualToString:HomeCategoryIdentifierBreakfast]) {
    return MRRHomeCellDynamicColor([UIColor colorWithRed:0.98 green:0.80 blue:0.44 alpha:1.0],
                                   [UIColor colorWithRed:0.83 green:0.61 blue:0.20 alpha:1.0]);
  }
  if ([identifier isEqualToString:HomeCategoryIdentifierLunch]) {
    return MRRHomeCellDynamicColor([UIColor colorWithRed:0.95 green:0.67 blue:0.37 alpha:1.0],
                                   [UIColor colorWithRed:0.83 green:0.51 blue:0.18 alpha:1.0]);
  }
  if ([identifier isEqualToString:HomeCategoryIdentifierDinner]) {
    return MRRHomeCellDynamicColor([UIColor colorWithRed:0.39 green:0.54 blue:0.90 alpha:1.0],
                                   [UIColor colorWithRed:0.28 green:0.40 blue:0.72 alpha:1.0]);
  }
  if ([identifier isEqualToString:HomeCategoryIdentifierDessert]) {
    return MRRHomeCellDynamicColor([UIColor colorWithRed:0.93 green:0.57 blue:0.67 alpha:1.0],
                                   [UIColor colorWithRed:0.77 green:0.36 blue:0.52 alpha:1.0]);
  }

  return MRRHomeCellDynamicColor([UIColor colorWithRed:0.35 green:0.73 blue:0.58 alpha:1.0],
                                 [UIColor colorWithRed:0.22 green:0.58 blue:0.42 alpha:1.0]);
}

@interface HomeCategoryCell ()

@property(nonatomic, retain) UIView *containerView;
@property(nonatomic, retain) UIView *badgeView;
@property(nonatomic, retain) UILabel *badgeLabel;
@property(nonatomic, retain) UILabel *titleLabel;

@end

@implementation HomeCategoryCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView.backgroundColor = [UIColor clearColor];

    UIView *containerView = [[[UIView alloc] init] autorelease];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.layer.cornerRadius = 24.0;
    containerView.layer.borderWidth = 1.0;
    containerView.layer.masksToBounds = NO;
    [self.contentView addSubview:containerView];
    self.containerView = containerView;

    UIView *badgeView = [[[UIView alloc] init] autorelease];
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.layer.cornerRadius = 16.0;
    [containerView addSubview:badgeView];
    self.badgeView = badgeView;

    UILabel *badgeLabel = [[[UILabel alloc] init] autorelease];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    badgeLabel.adjustsFontForContentSizeCategory = YES;
    badgeLabel.textColor = [UIColor whiteColor];
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    [badgeView addSubview:badgeLabel];
    self.badgeLabel = badgeLabel;

    UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 1;
    [containerView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
      [containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
      [containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
      [containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
      [containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

      [badgeView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:14.0],
      [badgeView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
      [badgeView.widthAnchor constraintEqualToConstant:32.0],
      [badgeView.heightAnchor constraintEqualToConstant:32.0],

      [badgeLabel.centerXAnchor constraintEqualToAnchor:badgeView.centerXAnchor],
      [badgeLabel.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor],

      [titleLabel.leadingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:12.0],
      [titleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-14.0],
      [titleLabel.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor]
    ]];
  }

  return self;
}

- (void)dealloc {
  [_titleLabel release];
  [_badgeLabel release];
  [_badgeView release];
  [_containerView release];
  [super dealloc];
}

- (void)configureWithCategory:(HomeCategory *)category selected:(BOOL)selected {
  self.accessibilityIdentifier = @"home.categoryCell";
  self.badgeLabel.text = category.badgeText;
  self.badgeView.backgroundColor = MRRHomeCategoryBadgeColor(category.identifier);
  self.titleLabel.text = category.title;
  self.titleLabel.textColor = selected ? [UIColor whiteColor]
                                       : MRRHomeCellNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.14 alpha:1.0],
                                                               [UIColor colorWithWhite:0.95 alpha:1.0]);

  UIColor *selectedColor = MRRHomeCellNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                 [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
  UIColor *surfaceColor = MRRHomeCellNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0],
                                                [UIColor colorWithWhite:0.16 alpha:1.0]);
  UIColor *borderColor = MRRHomeCellNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0],
                                               [UIColor colorWithWhite:0.24 alpha:1.0]);

  self.containerView.backgroundColor = selected ? selectedColor : surfaceColor;
  self.containerView.layer.borderColor = (selected ? [selectedColor colorWithAlphaComponent:0.82] : borderColor).CGColor;
  self.containerView.layer.shadowColor = [UIColor blackColor].CGColor;
  self.containerView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
  self.containerView.layer.shadowRadius = selected ? 18.0 : 12.0;
  self.containerView.layer.shadowOpacity = selected ? 0.18f : 0.06f;
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];

  CGFloat scale = highlighted ? 0.97 : 1.0;
  [UIView animateWithDuration:0.18
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     self.transform = CGAffineTransformMakeScale(scale, scale);
                   }
                   completion:nil];
}

@end

@interface HomeRecipeCardCell ()

@property(nonatomic, retain) UIView *surfaceView;
@property(nonatomic, retain) UIImageView *heroImageView;
@property(nonatomic, retain) UILabel *eyebrowLabel;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *subtitleLabel;
@property(nonatomic, retain) UILabel *summaryLabel;
@property(nonatomic, retain) NSLayoutConstraint *heroHeightConstraint;

@end

@implementation HomeRecipeCardCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView.backgroundColor = [UIColor clearColor];

    UIView *surfaceView = [[[UIView alloc] init] autorelease];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.layer.cornerRadius = 28.0;
    surfaceView.layer.borderWidth = 1.0;
    surfaceView.layer.borderColor = MRRHomeCellNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0],
                                                          [UIColor colorWithWhite:0.24 alpha:1.0]).CGColor;
    surfaceView.layer.shadowColor = [UIColor blackColor].CGColor;
    surfaceView.layer.shadowOpacity = 0.10f;
    surfaceView.layer.shadowRadius = 20.0f;
    surfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    surfaceView.backgroundColor = MRRHomeCellNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0],
                                                        [UIColor colorWithWhite:0.14 alpha:1.0]);
    [self.contentView addSubview:surfaceView];
    self.surfaceView = surfaceView;

    UIImageView *heroImageView = [[[UIImageView alloc] init] autorelease];
    heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    heroImageView.layer.cornerRadius = 24.0;
    heroImageView.clipsToBounds = YES;
    heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    heroImageView.backgroundColor = MRRHomeCellNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.96 alpha:1.0],
                                                          [UIColor colorWithWhite:0.18 alpha:1.0]);
    [surfaceView addSubview:heroImageView];
    self.heroImageView = heroImageView;

    UILabel *eyebrowLabel = [[[UILabel alloc] init] autorelease];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    eyebrowLabel.textColor = MRRHomeCellNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                   [UIColor colorWithWhite:0.74 alpha:1.0]);
    eyebrowLabel.numberOfLines = 1;
    [surfaceView addSubview:eyebrowLabel];
    self.eyebrowLabel = eyebrowLabel;

    UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightBold];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = MRRHomeCellNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                 [UIColor colorWithWhite:0.95 alpha:1.0]);
    titleLabel.numberOfLines = 2;
    [surfaceView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[[UILabel alloc] init] autorelease];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = MRRHomeCellNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                    [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
    subtitleLabel.numberOfLines = 1;
    [surfaceView addSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UILabel *summaryLabel = [[[UILabel alloc] init] autorelease];
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    summaryLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    summaryLabel.adjustsFontForContentSizeCategory = YES;
    summaryLabel.textColor = MRRHomeCellNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                   [UIColor colorWithWhite:0.72 alpha:1.0]);
    summaryLabel.numberOfLines = 2;
    [surfaceView addSubview:summaryLabel];
    self.summaryLabel = summaryLabel;

    self.heroHeightConstraint = [heroImageView.heightAnchor constraintEqualToConstant:190.0];

    [NSLayoutConstraint activateConstraints:@[
      [surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:2.0],
      [surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
      [surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
      [surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-2.0],

      [heroImageView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:10.0],
      [heroImageView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:10.0],
      [heroImageView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-10.0],
      self.heroHeightConstraint,

      [eyebrowLabel.topAnchor constraintEqualToAnchor:heroImageView.bottomAnchor constant:14.0],
      [eyebrowLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:16.0],
      [eyebrowLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],

      [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:6.0],
      [titleLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:16.0],
      [titleLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],

      [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
      [subtitleLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:16.0],
      [subtitleLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],

      [summaryLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8.0],
      [summaryLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:16.0],
      [summaryLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],
      [summaryLabel.bottomAnchor constraintLessThanOrEqualToAnchor:surfaceView.bottomAnchor constant:-16.0]
    ]];
  }

  return self;
}

- (void)dealloc {
  [_heroHeightConstraint release];
  [_summaryLabel release];
  [_subtitleLabel release];
  [_titleLabel release];
  [_eyebrowLabel release];
  [_heroImageView release];
  [_surfaceView release];
  [super dealloc];
}

- (void)prepareForReuse {
  [super prepareForReuse];
  self.heroImageView.image = nil;
  self.heroImageView.backgroundColor = MRRHomeCellNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.96 alpha:1.0],
                                                             [UIColor colorWithWhite:0.18 alpha:1.0]);
}

- (void)configureWithRecipeCard:(HomeRecipeCard *)recipeCard style:(HomeRecipeCardCellStyle)style {
  self.accessibilityIdentifier = @"home.recipeCardCell";
  self.heroImageView.image = [UIImage imageNamed:recipeCard.assetName];
  self.eyebrowLabel.text = [NSString stringWithFormat:@"%@  •  %@  •  %@",
                                                      recipeCard.durationText, recipeCard.calorieText, recipeCard.servingsText];
  self.titleLabel.text = recipeCard.title;
  self.subtitleLabel.text = [NSString stringWithFormat:@"By %@", recipeCard.sourceName];
  self.summaryLabel.text = recipeCard.summaryText;
  self.summaryLabel.hidden = style == HomeRecipeCardCellStyleRail;
  self.heroHeightConstraint.constant = style == HomeRecipeCardCellStyleRail ? 196.0 : 184.0;
  self.titleLabel.font = [UIFont systemFontOfSize:style == HomeRecipeCardCellStyleRail ? 28.0 : 24.0 weight:UIFontWeightBold];
  self.surfaceView.layer.shadowOpacity = style == HomeRecipeCardCellStyleRail ? 0.12f : 0.08f;
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];

  CGFloat scale = highlighted ? 0.975 : 1.0;
  [UIView animateWithDuration:0.20
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     self.transform = CGAffineTransformMakeScale(scale, scale);
                   }
                   completion:nil];
}

@end
