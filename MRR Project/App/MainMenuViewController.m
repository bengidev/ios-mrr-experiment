#import "MainMenuViewController.h"
#import "../Layout/MRRLayoutScaling.h"

@interface MainMenuViewController ()

@property(nonatomic, retain) UIStackView *stackView;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *summaryLabel;
@property(nonatomic, retain) NSLayoutConstraint *stackLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *stackTrailingConstraint;

- (UIStackView *)buildStackView;
- (UILabel *)buildTitleLabel;
- (UILabel *)buildSummaryLabel;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UIColor *)namedColor:(NSString *)name fallback:(UIColor *)fallbackColor;
- (void)updateLayoutMetricsIfNeeded;
- (CGSize)layoutViewportSize;

@end

@implementation MainMenuViewController

- (void)dealloc {
  [_stackTrailingConstraint release];
  [_stackLeadingConstraint release];
  [_summaryLabel release];
  [_titleLabel release];
  [_stackView release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Main Menus";
  self.view.backgroundColor = [self namedColor:@"BackgroundColor" fallback:[UIColor whiteColor]];
  self.view.tintColor = [self namedColor:@"TextPrimaryColor" fallback:self.view.tintColor];
  self.view.accessibilityIdentifier = @"mainMenu.view";

  UIStackView* stackView = [self buildStackView];
  [self.view addSubview:stackView];
  self.stackView = stackView;

  UILabel *titleLabel = [self buildTitleLabel];
  UILabel *summaryLabel = [self buildSummaryLabel];
  [stackView addArrangedSubview:titleLabel];
  [stackView addArrangedSubview:summaryLabel];
  self.titleLabel = titleLabel;
  self.summaryLabel = summaryLabel;

  self.stackLeadingConstraint = [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0];
  self.stackTrailingConstraint = [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    self.stackLeadingConstraint,
    self.stackTrailingConstraint,
  ]];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  [self updateLayoutMetricsIfNeeded];
}

- (UIStackView*)buildStackView {
  UIStackView* stackView = [[[UIStackView alloc] init] autorelease];
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 12.0;
  stackView.alignment = UIStackViewAlignmentFill;
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  return stackView;
}

- (UILabel*)buildTitleLabel {
  UILabel* label = [self labelWithText:@"Main Menus"
                                  font:[UIFont boldSystemFontOfSize:28.0]
                                 color:[self namedColor:@"TextPrimaryColor" fallback:[UIColor blackColor]]];
  label.textAlignment = NSTextAlignmentCenter;
  label.accessibilityIdentifier = @"mainMenu.titleLabel";
  return label;
}

- (UILabel*)buildSummaryLabel {
  UILabel* label = [self labelWithText:@"Onboarding is complete. This screen is a simple placeholder for the next app flow."
                                  font:[UIFont systemFontOfSize:17.0]
                                 color:[self namedColor:@"TextSecondaryColor" fallback:[UIColor darkGrayColor]]];
  label.textAlignment = NSTextAlignmentCenter;
  label.accessibilityIdentifier = @"mainMenu.summaryLabel";
  return label;
}

- (UILabel*)labelWithText:(NSString*)text font:(UIFont*)font color:(UIColor*)color {
  UILabel* label = [[[UILabel alloc] init] autorelease];
  label.text = text;
  label.font = font;
  label.textColor = color;
  label.numberOfLines = 0;
  return label;
}

- (UIColor*)namedColor:(NSString*)name fallback:(UIColor*)fallbackColor {
  UIColor* color = [UIColor colorNamed:name];
  return color ?: fallbackColor;
}

- (void)updateLayoutMetricsIfNeeded {
  CGSize viewportSize = [self layoutViewportSize];
  if (viewportSize.width <= 0.0 || viewportSize.height <= 0.0) {
    return;
  }

  CGFloat horizontalInset = MRRLayoutScaledValue(24.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat stackSpacing = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisHeight);
  CGFloat titleFontSize = MRRLayoutScaledValue(28.0, viewportSize, MRRLayoutScaleAxisWidth);
  CGFloat summaryFontSize = MRRLayoutScaledValue(17.0, viewportSize, MRRLayoutScaleAxisWidth);

  self.stackLeadingConstraint.constant = horizontalInset;
  self.stackTrailingConstraint.constant = -horizontalInset;
  self.stackView.spacing = stackSpacing;
  self.titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
  self.summaryLabel.font = [UIFont systemFontOfSize:summaryFontSize];
}

- (CGSize)layoutViewportSize {
  CGRect safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
  if (CGRectGetWidth(safeFrame) > 0.0 && CGRectGetHeight(safeFrame) > 0.0) {
    return safeFrame.size;
  }

  return self.view.bounds.size;
}

@end
