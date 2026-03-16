#import "SavedViewController.h"

#import "../../Layout/MRRLiquidGlassStyling.h"

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

@interface SavedViewController ()

@property(nonatomic, retain) UIView *messageCardView;
@property(nonatomic, retain) UILabel *headlineLabel;
@property(nonatomic, retain) UILabel *bodyLabel;

- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;

@end

@implementation SavedViewController

- (instancetype)init {
  return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc {
  [_bodyLabel release];
  [_headlineLabel release];
  [_messageCardView release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Saved";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"saved.view";
  self.view.backgroundColor = MRRSavedNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.10 alpha:1.0]);

  [self buildViewHierarchy];
}

- (void)buildViewHierarchy {
  UIView *messageCardView = [[[UIView alloc] init] autorelease];
  messageCardView.translatesAutoresizingMaskIntoConstraints = NO;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:messageCardView];
  [self.view addSubview:messageCardView];
  self.messageCardView = messageCardView;

  UILabel *headlineLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:28.0]
                                         color:MRRSavedNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                                  [UIColor colorWithWhite:0.96 alpha:1.0])];
  headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
  headlineLabel.numberOfLines = 0;
  headlineLabel.text = @"Saved feature coming soon.";
  [messageCardView addSubview:headlineLabel];
  self.headlineLabel = headlineLabel;

  UILabel *bodyLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0]
                                     color:MRRSavedNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                              [UIColor colorWithWhite:0.70 alpha:1.0])];
  bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
  bodyLabel.numberOfLines = 0;
  bodyLabel.text = @"This standalone feature is ready to be mounted inside Main Menu or presented as its own screen.";
  [messageCardView addSubview:bodyLabel];
  self.bodyLabel = bodyLabel;

  [NSLayoutConstraint activateConstraints:@[
    [messageCardView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [messageCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [messageCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],

    [headlineLabel.topAnchor constraintEqualToAnchor:messageCardView.topAnchor constant:24.0],
    [headlineLabel.leadingAnchor constraintEqualToAnchor:messageCardView.leadingAnchor constant:24.0],
    [headlineLabel.trailingAnchor constraintEqualToAnchor:messageCardView.trailingAnchor constant:-24.0],

    [bodyLabel.topAnchor constraintEqualToAnchor:headlineLabel.bottomAnchor constant:12.0],
    [bodyLabel.leadingAnchor constraintEqualToAnchor:messageCardView.leadingAnchor constant:24.0],
    [bodyLabel.trailingAnchor constraintEqualToAnchor:messageCardView.trailingAnchor constant:-24.0],
    [bodyLabel.bottomAnchor constraintEqualToAnchor:messageCardView.bottomAnchor constant:-24.0]
  ]];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.font = font;
  label.textColor = color;
  return label;
}

@end
