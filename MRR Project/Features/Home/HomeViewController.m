#import "HomeViewController.h"

#import "../Authentication/MRRAuthErrorMapper.h"
#import "../Authentication/MRRAuthSession.h"

static UIColor *MRRHomeDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRHomeNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeDynamicFallbackColor(lightColor, darkColor);
}

@interface HomeViewController ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain) UIStackView *stackView;
@property(nonatomic, retain) UIView *summaryCardView;
@property(nonatomic, retain) UILabel *displayNameLabel;
@property(nonatomic, retain) UILabel *emailLabel;
@property(nonatomic, retain) UILabel *providerLabel;
@property(nonatomic, retain) UILabel *statusLabel;
@property(nonatomic, retain) UIButton *logoutButton;

- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (void)handleLogoutTapped:(id)sender;
- (void)performConfirmedLogout;
- (void)presentLogoutConfirmationAlert;
- (void)presentLogoutError:(NSError *)error;

@end

@implementation HomeViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(session != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _authenticationController = [authenticationController retain];
    _session = [session retain];
  }

  return self;
}

- (void)dealloc {
  [_logoutButton release];
  [_statusLabel release];
  [_providerLabel release];
  [_emailLabel release];
  [_displayNameLabel release];
  [_summaryCardView release];
  [_stackView release];
  [_session release];
  [_authenticationController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Home";
  self.view.accessibilityIdentifier = @"home.view";
  self.view.backgroundColor =
      MRRHomeNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.10 alpha:1.0]);

  [self buildViewHierarchy];
}

- (void)buildViewHierarchy {
  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 20.0;
  [self.view addSubview:stackView];
  self.stackView = stackView;

  UIView *summaryCardView = [[[UIView alloc] init] autorelease];
  summaryCardView.translatesAutoresizingMaskIntoConstraints = NO;
  summaryCardView.accessibilityIdentifier = @"home.summaryCard";
  summaryCardView.backgroundColor =
      MRRHomeNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.14 alpha:1.0]);
  summaryCardView.layer.cornerRadius = 28.0;
  summaryCardView.layer.borderWidth = 1.0;
  summaryCardView.layer.borderColor = [[MRRHomeNamedColor(@"TextPrimaryColor", [UIColor blackColor], [UIColor whiteColor])
      colorWithAlphaComponent:0.08] CGColor];
  [stackView addArrangedSubview:summaryCardView];
  self.summaryCardView = summaryCardView;

  UILabel *eyebrowLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold]
                                        color:MRRHomeNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
  eyebrowLabel.text = @"SIGNED IN";
  eyebrowLabel.accessibilityIdentifier = @"home.eyebrowLabel";
  [summaryCardView addSubview:eyebrowLabel];

  UILabel *displayNameLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:30.0]
                                            color:MRRHomeNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                                    [UIColor colorWithWhite:0.96 alpha:1.0])];
  displayNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
  displayNameLabel.accessibilityIdentifier = @"home.displayNameLabel";
  displayNameLabel.numberOfLines = 0;
  displayNameLabel.text = [self.session displayNameOrFallback];
  [summaryCardView addSubview:displayNameLabel];
  self.displayNameLabel = displayNameLabel;

  UILabel *emailLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0]
                                      color:MRRHomeNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                              [UIColor colorWithWhite:0.70 alpha:1.0])];
  emailLabel.translatesAutoresizingMaskIntoConstraints = NO;
  emailLabel.accessibilityIdentifier = @"home.emailLabel";
  emailLabel.numberOfLines = 0;
  emailLabel.text = self.session.email.length > 0 ? self.session.email : @"No email returned";
  [summaryCardView addSubview:emailLabel];
  self.emailLabel = emailLabel;

  UILabel *providerLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                         color:MRRHomeNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.96 alpha:1.0])];
  providerLabel.translatesAutoresizingMaskIntoConstraints = NO;
  providerLabel.accessibilityIdentifier = @"home.providerLabel";
  providerLabel.numberOfLines = 0;
  providerLabel.text = [NSString stringWithFormat:@"Provider: %@", MRRAuthDisplayNameForProviderType(self.session.providerType)];
  [summaryCardView addSubview:providerLabel];
  self.providerLabel = providerLabel;

  UILabel *statusLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0]
                                       color:MRRHomeNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                               [UIColor colorWithWhite:0.70 alpha:1.0])];
  statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  statusLabel.accessibilityIdentifier = @"home.statusLabel";
  statusLabel.numberOfLines = 0;
  statusLabel.text = @"Your authentication session is active and ready for future subscription wiring.";
  [summaryCardView addSubview:statusLabel];
  self.statusLabel = statusLabel;

  UIButton *logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
  logoutButton.translatesAutoresizingMaskIntoConstraints = NO;
  logoutButton.accessibilityIdentifier = @"home.logoutButton";
  logoutButton.backgroundColor = [UIColor colorWithRed:0.76 green:0.18 blue:0.21 alpha:1.0];
  logoutButton.layer.cornerRadius = 18.0;
  logoutButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
  [logoutButton setTitle:@"Log Out" forState:UIControlStateNormal];
  [logoutButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [logoutButton addTarget:self action:@selector(handleLogoutTapped:) forControlEvents:UIControlEventTouchUpInside];
  [stackView addArrangedSubview:logoutButton];
  self.logoutButton = logoutButton;

  [NSLayoutConstraint activateConstraints:@[
    [stackView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],

    [eyebrowLabel.topAnchor constraintEqualToAnchor:summaryCardView.topAnchor constant:22.0],
    [eyebrowLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [eyebrowLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],

    [displayNameLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:12.0],
    [displayNameLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [displayNameLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],

    [emailLabel.topAnchor constraintEqualToAnchor:displayNameLabel.bottomAnchor constant:8.0],
    [emailLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [emailLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],

    [providerLabel.topAnchor constraintEqualToAnchor:emailLabel.bottomAnchor constant:18.0],
    [providerLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [providerLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],

    [statusLabel.topAnchor constraintEqualToAnchor:providerLabel.bottomAnchor constant:8.0],
    [statusLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [statusLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],
    [statusLabel.bottomAnchor constraintEqualToAnchor:summaryCardView.bottomAnchor constant:-22.0],

    [logoutButton.heightAnchor constraintEqualToConstant:54.0]
  ]];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.font = font;
  label.textColor = color;
  return label;
}

- (void)handleLogoutTapped:(id)sender {
  [self presentLogoutConfirmationAlert];
}

- (void)performConfirmedLogout {
  NSError *signOutError = nil;
  BOOL didSignOut = [self.authenticationController signOut:&signOutError];
  if (!didSignOut || signOutError != nil) {
    [self presentLogoutError:signOutError];
    return;
  }

  [self.delegate homeViewControllerDidSignOut:self];
}

- (void)presentLogoutConfirmationAlert {
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Log out?"
                                          message:@"You will return to onboarding until another account signs in."
                                   preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"home.logoutAlert";

  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Log Out"
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(__unused UIAlertAction *action) {
                                                    [self performConfirmedLogout];
                                                  }]];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)presentLogoutError:(NSError *)error {
  NSString *message = [MRRAuthErrorMapper messageForError:error];
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Couldn't Log Out"
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"home.logoutErrorAlert";
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alertController animated:YES completion:nil];
}

@end
