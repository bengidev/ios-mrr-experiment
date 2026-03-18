#import "OnboardingRecipeCarouselCell.h"

#include <math.h>

#import <QuartzCore/QuartzCore.h>

#import "../../../../Layout/MRRLiquidGlassStyling.h"
#import "../../Data/OnboardingRecipeModels.h"
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

static UIColor *MRRPrimaryTextColor(void) {
  return MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRSecondaryTextColor(void) {
  return MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0], [UIColor colorWithWhite:0.63 alpha:1.0]);
}

static UIColor *MRRHighlightedTextBackdropColor(void) {
  return [MRRNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.16 alpha:1.0])
      colorWithAlphaComponent:0.5];
}

static CGFloat const MRRPureCarouselCardBaseWidth = 176.0;
static CGFloat const MRRPureCarouselCardBaseHeight = 196.0;

@interface OnboardingRecipeCarouselCell ()

@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UIImageView *imageView;
@property(nonatomic, retain) UIView *shimmerOverlayView;
@property(nonatomic, retain) UIView *textBackdropView;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *metadataLabel;
@property(nonatomic, retain) UILabel *hintLabel;
@property(nonatomic, retain) NSLayoutConstraint *textBackdropTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *titleLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *titleTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *titleBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *metadataBottomConstraint;

- (void)buildViewHierarchy;
- (void)applyAccessibilityIdentifiersForRecipePreview:(OnboardingRecipePreview *)recipePreview;
- (void)updateTextOverlayVisibility;
- (void)updateShimmerLoadingState;
- (void)updateAdaptiveMetricsForCardSize:(CGSize)cardSize;

@end

@implementation OnboardingRecipeCarouselCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _showsTextOverlay = YES;
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 0.0f;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.masksToBounds = NO;

    [self buildViewHierarchy];
  }

  return self;
}

- (void)dealloc {
  [_metadataBottomConstraint release];
  [_metadataTrailingConstraint release];
  [_metadataLeadingConstraint release];
  [_textBackdropTopConstraint release];
  [_titleBottomConstraint release];
  [_titleTrailingConstraint release];
  [_titleLeadingConstraint release];
  [_hintLabel release];
  [_metadataLabel release];
  [_titleLabel release];
  [_textBackdropView release];
  [_shimmerOverlayView release];
  [_imageView release];
  [_cardView release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [self.contentView layoutIfNeeded];
  [self.cardView layoutIfNeeded];
  [self.textBackdropView layoutIfNeeded];

  CALayer *textBackdropMaskLayer = self.textBackdropView.layer.mask;
  if (textBackdropMaskLayer != nil) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    textBackdropMaskLayer.frame = self.textBackdropView.bounds;
    [CATransaction commit];
  }

  for (CALayer *sublayer in self.shimmerOverlayView.layer.sublayers) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    sublayer.frame = self.shimmerOverlayView.bounds;
    [CATransaction commit];
  }

  [self updateAdaptiveMetricsForCardSize:self.contentView.bounds.size];
}

- (void)prepareForReuse {
  [super prepareForReuse];

  self.imageView.image = nil;
  self.titleLabel.text = nil;
  self.metadataLabel.text = nil;
  self.showsShimmerLoading = NO;
  self.hintLabel.hidden = YES;
  self.accessibilityIdentifier = nil;
  self.accessibilityLabel = nil;
  self.accessibilityHint = nil;
  self.accessibilityTraits = UIAccessibilityTraitNone;
  self.contentView.accessibilityIdentifier = nil;
  self.cardView.accessibilityIdentifier = nil;
  self.imageView.accessibilityIdentifier = nil;
  self.textBackdropView.accessibilityIdentifier = nil;
  self.titleLabel.accessibilityIdentifier = nil;
  self.metadataLabel.accessibilityIdentifier = nil;
  self.hintLabel.accessibilityIdentifier = nil;
  self.showsTextOverlay = YES;
}

- (void)configureWithRecipePreview:(OnboardingRecipePreview *)recipePreview {
  NSString *compactCalorieText = [recipePreview.fallbackDetail.calorieText stringByReplacingOccurrencesOfString:@" kcal" withString:@""];

  self.imageView.image = [UIImage imageNamed:recipePreview.assetName];
  self.titleLabel.text = recipePreview.title;
  self.metadataLabel.text = [NSString stringWithFormat:@"◷ %@   🔥 %@", recipePreview.fallbackDetail.durationText, compactCalorieText];
  self.hintLabel.text = nil;
  self.hintLabel.hidden = YES;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:self.textBackdropView];
  self.textBackdropView.backgroundColor = MRRHighlightedTextBackdropColor();
  self.isAccessibilityElement = YES;
  self.accessibilityTraits = UIAccessibilityTraitButton;
  self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", recipePreview.title, recipePreview.fallbackDetail.durationText,
                                                       recipePreview.fallbackDetail.calorieText];
  self.accessibilityHint = @"Opens recipe details.";
  [self applyAccessibilityIdentifiersForRecipePreview:recipePreview];
  [self updateTextOverlayVisibility];
  [self updateShimmerLoadingState];
}

#pragma mark - View Setup

- (void)buildViewHierarchy {
  self.layer.shadowOpacity = 0.0f;
  self.layer.shadowRadius = 0.0f;
  self.layer.shadowOffset = CGSizeZero;

  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.layer.cornerRadius = 20.0;
  cardView.clipsToBounds = YES;
  cardView.layer.borderWidth = 1.2;
  cardView.layer.borderColor = [[MRRPrimaryTextColor() colorWithAlphaComponent:0.14] CGColor];
  cardView.backgroundColor = MRRNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.16 alpha:1.0]);
  [self.contentView addSubview:cardView];
  self.cardView = cardView;

  UIImageView *imageView = [[[UIImageView alloc] init] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFill;
  imageView.clipsToBounds = YES;
  [cardView addSubview:imageView];
  self.imageView = imageView;

  UIView *shimmerOverlayView = [[[UIView alloc] init] autorelease];
  shimmerOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  shimmerOverlayView.hidden = YES;
  shimmerOverlayView.userInteractionEnabled = NO;
  shimmerOverlayView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16];
  [cardView addSubview:shimmerOverlayView];
  self.shimmerOverlayView = shimmerOverlayView;

  UIView *textBackdropView = [[[UIView alloc] init] autorelease];
  textBackdropView.translatesAutoresizingMaskIntoConstraints = NO;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:textBackdropView];
  textBackdropView.backgroundColor = MRRHighlightedTextBackdropColor();
  textBackdropView.userInteractionEnabled = NO;
  CAGradientLayer *textBackdropMaskLayer = [CAGradientLayer layer];
  textBackdropMaskLayer.startPoint = CGPointMake(0.5, 0.0);
  textBackdropMaskLayer.endPoint = CGPointMake(0.5, 1.0);
  textBackdropMaskLayer.colors = @[
    (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    (id)[UIColor colorWithWhite:1.0 alpha:0.78].CGColor,
    (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
    (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
  ];
  textBackdropMaskLayer.locations = @[ @0.0, @0.16, @0.28, @1.0 ];
  textBackdropMaskLayer.frame = textBackdropView.bounds;
  textBackdropView.layer.mask = textBackdropMaskLayer;
  [cardView addSubview:textBackdropView];
  self.textBackdropView = textBackdropView;

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  titleLabel.textColor = [MRRPrimaryTextColor() colorWithAlphaComponent:0.98];
  titleLabel.numberOfLines = 2;
  titleLabel.shadowColor = [UIColor clearColor];
  titleLabel.shadowOffset = CGSizeZero;
  [cardView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *metadataLabel = [[[UILabel alloc] init] autorelease];
  metadataLabel.translatesAutoresizingMaskIntoConstraints = NO;
  metadataLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
  metadataLabel.textColor = [MRRSecondaryTextColor() colorWithAlphaComponent:0.98];
  metadataLabel.shadowColor = [UIColor clearColor];
  metadataLabel.shadowOffset = CGSizeZero;
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
  self.textBackdropTopConstraint = [textBackdropView.topAnchor constraintEqualToAnchor:titleLabel.topAnchor constant:-12.0];

  [NSLayoutConstraint activateConstraints:@[
    [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
    [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
    [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

    [imageView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [shimmerOverlayView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
    [shimmerOverlayView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [shimmerOverlayView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [shimmerOverlayView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

    [textBackdropView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
    [textBackdropView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
    [textBackdropView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],
    self.textBackdropTopConstraint,

    self.metadataLeadingConstraint,
    self.metadataTrailingConstraint,
    self.metadataBottomConstraint,

    self.titleLeadingConstraint,
    self.titleTrailingConstraint,
    self.titleBottomConstraint
  ]];
}

- (void)applyAccessibilityIdentifiersForRecipePreview:(OnboardingRecipePreview *)recipePreview {
  NSString *identifierPrefix = [NSString stringWithFormat:@"onboarding.carouselCell.%@", recipePreview.assetName];
  self.accessibilityIdentifier = identifierPrefix;
  self.contentView.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".contentView"];
  self.cardView.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".cardView"];
  self.imageView.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".imageView"];
  self.shimmerOverlayView.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".shimmerOverlayView"];
  self.textBackdropView.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".textBackdropView"];
  self.titleLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".titleLabel"];
  self.metadataLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".metadataLabel"];
  self.hintLabel.accessibilityIdentifier = [identifierPrefix stringByAppendingString:@".hintLabel"];
}

- (void)setShowsTextOverlay:(BOOL)showsTextOverlay {
  if (_showsTextOverlay == showsTextOverlay) {
    return;
  }

  _showsTextOverlay = showsTextOverlay;
  [self updateTextOverlayVisibility];
}

- (void)updateTextOverlayVisibility {
  BOOL shouldShowOverlay = self.showsTextOverlay;
  self.textBackdropView.hidden = !shouldShowOverlay;
  self.titleLabel.hidden = !shouldShowOverlay;
  self.metadataLabel.hidden = !shouldShowOverlay;
}

- (void)setShowsShimmerLoading:(BOOL)showsShimmerLoading {
  if (_showsShimmerLoading == showsShimmerLoading) {
    return;
  }

  _showsShimmerLoading = showsShimmerLoading;
  [self updateShimmerLoadingState];
}

- (void)updateShimmerLoadingState {
  [self.shimmerOverlayView.layer removeAllAnimations];
  if (!self.showsShimmerLoading) {
    self.shimmerOverlayView.hidden = YES;
    self.accessibilityHint = @"Opens recipe details.";
    return;
  }

  self.shimmerOverlayView.hidden = NO;
  self.accessibilityHint = @"Loading recipe details.";

  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.frame = self.shimmerOverlayView.bounds;
  gradientLayer.startPoint = CGPointMake(0.0, 0.5);
  gradientLayer.endPoint = CGPointMake(1.0, 0.5);
  gradientLayer.colors = @[
    (id)[[UIColor whiteColor] colorWithAlphaComponent:0.04].CGColor,
    (id)[[UIColor whiteColor] colorWithAlphaComponent:0.34].CGColor,
    (id)[[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor
  ];
  gradientLayer.locations = @[ @0.0, @0.48, @1.0 ];
  [self.shimmerOverlayView.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
  [self.shimmerOverlayView.layer addSublayer:gradientLayer];

  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
  animation.fromValue = @(-CGRectGetWidth(self.shimmerOverlayView.bounds));
  animation.toValue = @(CGRectGetWidth(self.shimmerOverlayView.bounds));
  animation.duration = 1.15;
  animation.repeatCount = HUGE_VALF;
  animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  [gradientLayer addAnimation:animation forKey:@"mrr.shimmer.translation"];
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
  CGFloat backdropTopPadding = 0.0;
  CGFloat cornerRadius = 0.0;
  CGFloat titleFontSize = 0.0;
  CGFloat metadataFontSize = 0.0;
  CGFloat widthScaleFactor = cardWidth / MRRPureCarouselCardBaseWidth;
  CGFloat heightScaleFactor = cardHeight / MRRPureCarouselCardBaseHeight;
  CGFloat minDimensionScaleFactor = MIN(widthScaleFactor, heightScaleFactor);

  horizontalPadding = MRRLayoutRoundedMetric(14.0 * widthScaleFactor);
  bottomPadding = MRRLayoutRoundedMetric(14.0 * heightScaleFactor);
  titleSpacing = MRRLayoutRoundedMetric(5.0 * heightScaleFactor);
  backdropTopPadding = MRRLayoutRoundedMetric(12.0 * heightScaleFactor);
  cornerRadius = MRRLayoutRoundedMetric(20.0 * minDimensionScaleFactor);
  titleFontSize = MRRLayoutRoundedMetric(19.0 * widthScaleFactor);
  metadataFontSize = MRRLayoutRoundedMetric(12.5 * widthScaleFactor);

  self.cardView.layer.cornerRadius = cornerRadius;
  self.textBackdropTopConstraint.constant = -backdropTopPadding;
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
  self.layer.shadowPath = nil;
}

@end
