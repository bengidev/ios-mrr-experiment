#import "OnboardingRecipeCarouselCell.h"

#include <math.h>

#import <QuartzCore/QuartzCore.h>

#import "../../Data/OnboardingStateController.h"
#import "../../../../Layout/MRRLayoutScaling.h"

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

static CGFloat const MRRPureCarouselCardBaseWidth = 176.0;
static CGFloat const MRRPureCarouselCardBaseHeight = 196.0;

@interface OnboardingRecipeCarouselCell ()

@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UIImageView *imageView;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *metadataLabel;
@property(nonatomic, retain) UILabel *hintLabel;
@property(nonatomic, retain) NSLayoutConstraint *titleLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *titleTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *titleBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataBottomConstraint;

- (void)buildViewHierarchy;
- (void)applyAccessibilityIdentifiersForRecipe:(OnboardingRecipe *)recipe;
- (void)updateAdaptiveMetricsForCardSize:(CGSize)cardSize;

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
  [_metadataBottomConstraint release];
  [_metadataTrailingConstraint release];
  [_metadataLeadingConstraint release];
  [_titleBottomConstraint release];
  [_titleTrailingConstraint release];
  [_titleLeadingConstraint release];
  [_hintLabel release];
  [_metadataLabel release];
  [_titleLabel release];
  [_imageView release];
  [_cardView release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  [self updateAdaptiveMetricsForCardSize:self.contentView.bounds.size];
}

- (void)prepareForReuse {
  [super prepareForReuse];

  self.imageView.image = nil;
  self.titleLabel.text = nil;
  self.metadataLabel.text = nil;
  self.hintLabel.hidden = YES;
  self.titleLabel.accessibilityIdentifier = nil;
  self.metadataLabel.accessibilityIdentifier = nil;
  self.hintLabel.accessibilityIdentifier = nil;
}

- (void)configureWithRecipe:(OnboardingRecipe *)recipe {
  NSString *compactCalorieText = [recipe.calorieText stringByReplacingOccurrencesOfString:@" kcal" withString:@""];

  self.imageView.image = [UIImage imageNamed:recipe.assetName];
  self.titleLabel.text = recipe.title;
  self.metadataLabel.text = [NSString stringWithFormat:@"◷ %@   🔥 %@", recipe.durationText, compactCalorieText];
  self.hintLabel.text = nil;
  self.hintLabel.hidden = YES;
  [self applyAccessibilityIdentifiersForRecipe:recipe];
}

#pragma mark - View Setup

- (void)buildViewHierarchy {
  self.layer.shadowOpacity = 0.25f;
  self.layer.shadowRadius = 20.0f;
  self.layer.shadowOffset = CGSizeMake(0.0, 12.0);

  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.layer.cornerRadius = 20.0;
  cardView.clipsToBounds = YES;
  cardView.layer.borderWidth = 1.2;
  cardView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.16] CGColor];
  cardView.backgroundColor = MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.16 alpha:1.0]);
  [self.contentView addSubview:cardView];
  self.cardView = cardView;

  UIImageView *imageView = [[[UIImageView alloc] init] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  [cardView addSubview:imageView];
  self.imageView = imageView;

  UIView *bottomOverlayView = [[[UIView alloc] init] autorelease];
  bottomOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  bottomOverlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.30];
  [cardView addSubview:bottomOverlayView];

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  titleLabel.textColor = [UIColor whiteColor];
  titleLabel.numberOfLines = 2;
  titleLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.70];
  titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
  [cardView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *metadataLabel = [[[UILabel alloc] init] autorelease];
  metadataLabel.translatesAutoresizingMaskIntoConstraints = NO;
  metadataLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
  metadataLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.88];
  metadataLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.60];
  metadataLabel.shadowOffset = CGSizeMake(0.0, 1.0);
  metadataLabel.adjustsFontSizeToFitWidth = YES;
  metadataLabel.minimumScaleFactor = 0.84;
  [cardView addSubview:metadataLabel];
  self.metadataLabel = metadataLabel;

  UILabel *hintLabel = [[[UILabel alloc] init] autorelease];
  hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
  hintLabel.hidden = YES;
  [cardView addSubview:hintLabel];
  self.hintLabel = hintLabel;

  self.metadataLeadingConstraint = [metadataLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:14.0];
  self.metadataTrailingConstraint = [metadataLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-14.0];
  self.metadataBottomConstraint = [metadataLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-14.0];
  self.titleLeadingConstraint = [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:14.0];
  self.titleTrailingConstraint = [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-14.0];
  self.titleBottomConstraint = [titleLabel.bottomAnchor constraintEqualToAnchor:metadataLabel.topAnchor constant:-6.0];

  [NSLayoutConstraint activateConstraints:@[
    [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
    [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
    [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

    [imageView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [bottomOverlayView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [bottomOverlayView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [bottomOverlayView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],
    [bottomOverlayView.heightAnchor constraintEqualToAnchor:cardView.heightAnchor multiplier:0.30],

    self.metadataLeadingConstraint,
    self.metadataTrailingConstraint,
    self.metadataBottomConstraint,

    self.titleLeadingConstraint,
    self.titleTrailingConstraint,
    self.titleBottomConstraint
  ]];
}

- (void)applyAccessibilityIdentifiersForRecipe:(OnboardingRecipe *)recipe {
  NSString *identifierPrefix = [NSString stringWithFormat:@"onboarding.carouselCell.%@", recipe.assetName];
  self.titleLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".titleLabel"];
  self.metadataLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".metadataLabel"];
  self.hintLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".hintLabel"];
}

- (void)updateAdaptiveMetricsForCardSize:(CGSize)cardSize {
  CGFloat cardWidth = cardSize.width;
  CGFloat cardHeight = cardSize.height;
  if (cardWidth <= 0.0 || cardHeight <= 0.0) {
    return;
  }

  CGFloat horizontalPadding = 0.0;
  CGFloat bottomPadding = 0.0;
  CGFloat titleSpacing = 0.0;
  CGFloat cornerRadius = 0.0;
  CGFloat titleFontSize = 0.0;
  CGFloat metadataFontSize = 0.0;
  CGFloat shadowRadius = 0.0;
  CGFloat shadowOffsetY = 0.0;

  CGFloat widthScaleFactor = cardWidth / MRRPureCarouselCardBaseWidth;
  CGFloat heightScaleFactor = cardHeight / MRRPureCarouselCardBaseHeight;
  CGFloat minDimensionScaleFactor = MIN(widthScaleFactor, heightScaleFactor);

  horizontalPadding = MRRLayoutRoundedMetric(14.0 * widthScaleFactor);
  bottomPadding = MRRLayoutRoundedMetric(14.0 * heightScaleFactor);
  titleSpacing = MRRLayoutRoundedMetric(5.0 * heightScaleFactor);
  cornerRadius = MRRLayoutRoundedMetric(20.0 * minDimensionScaleFactor);
  titleFontSize = MRRLayoutRoundedMetric(19.0 * widthScaleFactor);
  metadataFontSize = MRRLayoutRoundedMetric(12.5 * widthScaleFactor);
  shadowRadius = MRRLayoutRoundedMetric(18.0 * heightScaleFactor);
  shadowOffsetY = MRRLayoutRoundedMetric(10.0 * heightScaleFactor);

  self.cardView.layer.cornerRadius = cornerRadius;
  self.titleLeadingConstraint.constant = horizontalPadding;
  self.titleTrailingConstraint.constant = -horizontalPadding;
  self.titleBottomConstraint.constant = -titleSpacing;
  self.metadataLeadingConstraint.constant = horizontalPadding;
  self.metadataTrailingConstraint.constant = -horizontalPadding;
  self.metadataBottomConstraint.constant = -bottomPadding;
  self.titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
  self.metadataLabel.font = [UIFont systemFontOfSize:metadataFontSize weight:UIFontWeightMedium];
  self.titleLabel.preferredMaxLayoutWidth = MAX(cardWidth - (horizontalPadding * 2.0), 0.0);
  self.metadataLabel.preferredMaxLayoutWidth = MAX(cardWidth - (horizontalPadding * 2.0), 0.0);
  self.layer.shadowRadius = shadowRadius;
  self.layer.shadowOffset = CGSizeMake(0.0, shadowOffsetY);
  self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
}

@end
