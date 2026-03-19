#import "HomeSectionHeaderView.h"

static UIColor *MRRHomeHeaderDynamicColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRHomeHeaderNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeHeaderDynamicColor(lightColor, darkColor);
}

@interface MRRHomeSectionHeaderButton : UIButton
@end

@implementation MRRHomeSectionHeaderButton

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  CGRect bounds = self.bounds;
  CGFloat horizontalInset = MAX(0.0, (44.0 - CGRectGetWidth(bounds)) * 0.5);
  CGFloat verticalInset = MAX(0.0, (44.0 - CGRectGetHeight(bounds)) * 0.5);
  CGRect expandedBounds = CGRectInset(bounds, -horizontalInset, -verticalInset);
  return CGRectContainsPoint(expandedBounds, point);
}

@end

@interface HomeSectionHeaderView ()

@property(nonatomic, retain, readwrite) UILabel *titleLabel;
@property(nonatomic, retain, readwrite) UIButton *seeAllButton;

@end

@implementation HomeSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 0;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.textColor = MRRHomeHeaderNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                   [UIColor colorWithWhite:0.96 alpha:1.0]);
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UIButton *seeAllButton = [[[MRRHomeSectionHeaderButton alloc] initWithFrame:CGRectZero] autorelease];
    seeAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    seeAllButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    seeAllButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
    seeAllButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    seeAllButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    UIColor *accentColor = MRRHomeHeaderNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                   [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
    seeAllButton.tintColor = accentColor;
    [seeAllButton setTitleColor:accentColor forState:UIControlStateNormal];
    seeAllButton.layer.cornerRadius = 14.0;
    seeAllButton.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    [seeAllButton setTitle:@"See all" forState:UIControlStateNormal];
    [self addSubview:seeAllButton];
    self.seeAllButton = seeAllButton;

    [NSLayoutConstraint activateConstraints:@[
      [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor],
      [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:seeAllButton.leadingAnchor constant:-12.0],
      [titleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

      [seeAllButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [seeAllButton.topAnchor constraintEqualToAnchor:self.topAnchor]
    ]];
  }

  return self;
}

- (void)dealloc {
  [_seeAllButton release];
  [_titleLabel release];
  [super dealloc];
}

- (void)configureWithTitle:(NSString *)title identifierPrefix:(NSString *)identifierPrefix showsSeeAll:(BOOL)showsSeeAll {
  self.titleLabel.text = title;
  self.titleLabel.accessibilityIdentifier = [NSString stringWithFormat:@"%@.titleLabel", identifierPrefix];
  self.seeAllButton.hidden = !showsSeeAll;
  self.seeAllButton.accessibilityIdentifier = [NSString stringWithFormat:@"%@.seeAllButton", identifierPrefix];
  self.seeAllButton.accessibilityLabel = [NSString stringWithFormat:@"See all %@", title];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  CGFloat availableWidth = CGRectGetWidth(self.bounds) - CGRectGetWidth(self.seeAllButton.bounds) - 12.0;
  self.titleLabel.preferredMaxLayoutWidth = MAX(availableWidth, 0.0);
}

@end
