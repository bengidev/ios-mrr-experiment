#import "OnboardingRecipeCarouselCell.h"

#import <QuartzCore/QuartzCore.h>

#import "../../Data/OnboardingStateController.h"

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

@interface OnboardingRecipeCarouselCell ()

@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UIImageView *imageView;
@property(nonatomic, retain) UILabel *subtitleLabel;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *metadataLabel;
@property(nonatomic, retain) UILabel *hintLabel;
@property(nonatomic, retain) UIView *badgeView;

- (void)buildViewHierarchy;
- (void)applyAccessibilityIdentifiersForRecipe:(OnboardingRecipe *)recipe;

@end

@implementation OnboardingRecipeCarouselCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.16f;
    self.layer.shadowRadius = 22.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.layer.masksToBounds = NO;

    [self buildViewHierarchy];
  }

  return self;
}

- (void)dealloc {
  [_badgeView release];
  [_hintLabel release];
  [_metadataLabel release];
  [_titleLabel release];
  [_subtitleLabel release];
  [_imageView release];
  [_cardView release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:28.0].CGPath;
}

- (void)prepareForReuse {
  [super prepareForReuse];

  self.imageView.image = nil;
  self.subtitleLabel.text = nil;
  self.titleLabel.text = nil;
  self.metadataLabel.text = nil;
  self.subtitleLabel.accessibilityIdentifier = nil;
  self.titleLabel.accessibilityIdentifier = nil;
  self.metadataLabel.accessibilityIdentifier = nil;
  self.hintLabel.accessibilityIdentifier = nil;
}

- (void)configureWithRecipe:(OnboardingRecipe *)recipe {
  self.imageView.image = [UIImage imageNamed:recipe.assetName];
  self.subtitleLabel.text = [recipe.subtitle uppercaseString];
  self.titleLabel.text = recipe.title;
  self.metadataLabel.text = [NSString stringWithFormat:@"%@ / %@", recipe.durationText, recipe.calorieText];
  self.hintLabel.text = @"Tap for ingredients and steps";
  [self applyAccessibilityIdentifiersForRecipe:recipe];
}

#pragma mark - View Setup

- (void)buildViewHierarchy {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.layer.cornerRadius = 28.0;
  cardView.clipsToBounds = YES;
  cardView.backgroundColor = MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.16 alpha:1.0]);
  [self.contentView addSubview:cardView];
  self.cardView = cardView;

  UIImageView *imageView = [[[UIImageView alloc] init] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  [cardView addSubview:imageView];
  self.imageView = imageView;

  UIView *badgeView = [[[UIView alloc] init] autorelease];
  badgeView.translatesAutoresizingMaskIntoConstraints = NO;
  badgeView.backgroundColor = [MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                             [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])
      colorWithAlphaComponent:0.94];
  badgeView.layer.cornerRadius = 13.0;
  [cardView addSubview:badgeView];
  self.badgeView = badgeView;

  UILabel *subtitleLabel = [[[UILabel alloc] init] autorelease];
  subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  subtitleLabel.font = [UIFont boldSystemFontOfSize:11.0];
  subtitleLabel.textColor = [UIColor whiteColor];
  subtitleLabel.numberOfLines = 1;
  [badgeView addSubview:subtitleLabel];
  self.subtitleLabel = subtitleLabel;

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont boldSystemFontOfSize:28.0];
  titleLabel.textColor = [UIColor whiteColor];
  titleLabel.numberOfLines = 2;
  titleLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
  titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
  [cardView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *metadataLabel = [[[UILabel alloc] init] autorelease];
  metadataLabel.translatesAutoresizingMaskIntoConstraints = NO;
  metadataLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  metadataLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
  metadataLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.64];
  metadataLabel.shadowOffset = CGSizeMake(0.0, 1.0);
  [cardView addSubview:metadataLabel];
  self.metadataLabel = metadataLabel;

  UILabel *hintLabel = [[[UILabel alloc] init] autorelease];
  hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
  hintLabel.font = [UIFont systemFontOfSize:13.0];
  hintLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
  hintLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.64];
  hintLabel.shadowOffset = CGSizeMake(0.0, 1.0);
  [cardView addSubview:hintLabel];
  self.hintLabel = hintLabel;

  [NSLayoutConstraint activateConstraints:@[
    [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
    [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
    [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

    [imageView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [badgeView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [badgeView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],

    [subtitleLabel.topAnchor constraintEqualToAnchor:badgeView.topAnchor constant:7.0],
    [subtitleLabel.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:12.0],
    [subtitleLabel.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-12.0],
    [subtitleLabel.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor constant:-7.0],

    [hintLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
    [hintLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
    [hintLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

    [metadataLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
    [metadataLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
    [metadataLabel.bottomAnchor constraintEqualToAnchor:hintLabel.topAnchor constant:-8.0],

    [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
    [titleLabel.bottomAnchor constraintEqualToAnchor:metadataLabel.topAnchor constant:-10.0]
  ]];
}

- (void)applyAccessibilityIdentifiersForRecipe:(OnboardingRecipe *)recipe {
  NSString *identifierPrefix = [NSString stringWithFormat:@"onboarding.carouselCell.%@", recipe.assetName];
  self.subtitleLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".subtitleLabel"];
  self.titleLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".titleLabel"];
  self.metadataLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".metadataLabel"];
  self.hintLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".hintLabel"];
}

@end
