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
    titleLabel.textColor = MRRHomeHeaderNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0],
                                                   [UIColor colorWithWhite:0.96 alpha:1.0]);
    [self addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UIButton *seeAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    seeAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    seeAllButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    seeAllButton.tintColor = MRRHomeHeaderNamedColor(@"HomeAccentColor", [UIColor colorWithRed:0.13 green:0.60 blue:0.45 alpha:1.0],
                                                     [UIColor colorWithRed:0.42 green:0.84 blue:0.66 alpha:1.0]);
    [seeAllButton setTitle:@"See all" forState:UIControlStateNormal];
    [self addSubview:seeAllButton];
    self.seeAllButton = seeAllButton;

    [NSLayoutConstraint activateConstraints:@[
      [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor],
      [titleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

      [seeAllButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.trailingAnchor constant:12.0],
      [seeAllButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [seeAllButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor]
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
}

@end
