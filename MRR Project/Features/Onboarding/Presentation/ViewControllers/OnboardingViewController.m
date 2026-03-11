#import "OnboardingViewController.h"
#include <Foundation/NSObjCRuntime.h>
#include <UIKit/UIKit.h>

@implementation OnboardingViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Onboarding";
  self.view.backgroundColor = [self namedColor:@"CanvasBackground" fallback:[UIColor whiteColor]];
  self.view.tintColor = [self namedColor:@"AccentColor" fallback:self.view.tintColor];
  self.view.accessibilityIdentifier = @"onboarding.view";

  UIStackView* stackView = [self buildStackView];
  [self.view addSubview:stackView];

  [NSLayoutConstraint activateConstraints:@[
    [stackView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0]
  ]];

  UIImageView* illustrationView = [self buildIllustrationView];
  [stackView addArrangedSubview:illustrationView];
  [NSLayoutConstraint activateConstraints:@[ [illustrationView.heightAnchor constraintEqualToConstant:220.0] ]];

  UILabel* titleLabel = [self labelWithText:@"Welcome"
                                       font:[UIFont boldSystemFontOfSize:30.0]
                                      color:[self namedColor:@"PrimaryText" fallback:[UIColor blackColor]]];
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.accessibilityIdentifier = @"onboarding.titleLabel";
  [stackView addArrangedSubview:titleLabel];

  UILabel* summaryLabel = [self labelWithText:@"This is the first-launch onboarding screen. Tap "
                                              @"the button below to continue into the app."
                                         font:[UIFont systemFontOfSize:17.0]
                                        color:[self namedColor:@"SecondaryText" fallback:[UIColor darkGrayColor]]];
  summaryLabel.textAlignment = NSTextAlignmentCenter;
  [stackView addArrangedSubview:summaryLabel];

  UIButton* primaryButton = [self buildPrimaryButton];
  [stackView addArrangedSubview:primaryButton];
  [NSLayoutConstraint activateConstraints:@[ [primaryButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0] ]];
}

- (void)didTapPrimaryButton {
  [self.delegate onboardingViewControllerDidFinish:self];
}

- (UIStackView*)buildStackView {
  UIStackView* stackView = [[[UIStackView alloc] init] autorelease];
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 18.0;
  stackView.alignment = UIStackViewAlignmentFill;
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  return stackView;
}

- (UIImageView*)buildIllustrationView {
  UIImageView* imageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"OnboardingIllustration"]] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.backgroundColor = [self namedColor:@"CardBackground" fallback:[UIColor clearColor]];
  imageView.layer.cornerRadius = 28.0;
  imageView.clipsToBounds = YES;
  imageView.contentMode = UIViewContentModeScaleAspectFit;
  imageView.accessibilityIdentifier = @"onboarding.illustrationView";
  return imageView;
}

- (UIButton*)buildPrimaryButton {
  UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.backgroundColor = [self namedColor:@"PrimaryAction" fallback:[UIColor blackColor]];
  button.layer.cornerRadius = 12.0;
  button.contentEdgeInsets = UIEdgeInsetsMake(16.0, 20.0, 16.0, 20.0);
  button.accessibilityIdentifier = @"onboarding.primaryButton";
  button.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
  [button setTitle:@"Continue" forState:UIControlStateNormal];
  [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [button addTarget:self action:@selector(didTapPrimaryButton) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (UIColor*)namedColor:(NSString*)name fallback:(UIColor*)fallbackColor {
  UIColor* namedColor = [UIColor colorNamed:name];
  return namedColor ?: fallbackColor;
}

- (UILabel*)labelWithText:(NSString*)text font:(UIFont*)font color:(UIColor*)color {
  UILabel* label = [[[UILabel alloc] init] autorelease];
  label.text = text;
  label.font = font;
  label.textColor = color;
  label.numberOfLines = 0;
  return label;
}

@end
