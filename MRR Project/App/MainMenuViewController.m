#import "MainMenuViewController.h"

@implementation MainMenuViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Main Menus";
  self.view.backgroundColor = [self namedColor:@"CanvasBackground" fallback:[UIColor whiteColor]];
  self.view.tintColor = [self namedColor:@"AccentColor" fallback:self.view.tintColor];
  self.view.accessibilityIdentifier = @"mainMenu.view";

  UIStackView* stackView = [self buildStackView];
  [self.view addSubview:stackView];

  [stackView addArrangedSubview:[self buildTitleLabel]];
  [stackView addArrangedSubview:[self buildSummaryLabel]];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0]
  ]];
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
                                 color:[self namedColor:@"PrimaryText" fallback:[UIColor blackColor]]];
  label.textAlignment = NSTextAlignmentCenter;
  label.accessibilityIdentifier = @"mainMenu.titleLabel";
  return label;
}

- (UILabel*)buildSummaryLabel {
  UILabel* label = [self labelWithText:@"Onboarding is complete. This screen is a simple placeholder for the next app flow."
                                  font:[UIFont systemFontOfSize:17.0]
                                 color:[self namedColor:@"SecondaryText" fallback:[UIColor darkGrayColor]]];
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

@end
