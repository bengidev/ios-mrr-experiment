#import "ProfileViewController.h"

#import "../Authentication/MRRAuthErrorMapper.h"
#import "../Authentication/MRRAuthSession.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSyncingLogoutController.h"
#import "../../Layout/MRRLiquidGlassStyling.h"

static UIColor *MRRProfileDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRProfileNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRProfileDynamicFallbackColor(lightColor, darkColor);
}

@interface ProfileViewController ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain, nullable) id<MRRLogoutCoordinating> logoutController;
@property(nonatomic, retain) UIStackView *stackView;
@property(nonatomic, retain) UIView *summaryCardView;
@property(nonatomic, retain) UILabel *displayNameLabel;
@property(nonatomic, retain) UILabel *emailLabel;
@property(nonatomic, retain) UILabel *providerLabel;
@property(nonatomic, retain) UILabel *emailVerificationLabel;
@property(nonatomic, retain) UILabel *statusLabel;
@property(nonatomic, retain) UIButton *logoutButton;
@property(nonatomic, assign, getter=isPerformingLogout) BOOL performingLogout;

- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (void)handleLogoutTapped:(id)sender;
- (void)performConfirmedLogout;
- (void)updateLogoutUIForInProgress:(BOOL)inProgress;
- (void)presentLogoutConfirmationAlert;
- (void)presentLogoutError:(NSError *)error;

@end

@implementation ProfileViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session {
  return [self initWithAuthenticationController:authenticationController session:session logoutController:nil];
}

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                                logoutController:(id<MRRLogoutCoordinating>)logoutController {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(session != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _authenticationController = [authenticationController retain];
    _session = [session retain];
    _logoutController = [logoutController retain];
  }

  return self;
}

- (void)dealloc {
  [_logoutButton release];
  [_statusLabel release];
  [_emailVerificationLabel release];
  [_providerLabel release];
  [_emailLabel release];
  [_displayNameLabel release];
  [_summaryCardView release];
  [_stackView release];
  [_logoutController release];
  [_session release];
  [_authenticationController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Profile";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"profile.view";
  self.view.backgroundColor =
      MRRProfileNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.10 alpha:1.0]);

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
  summaryCardView.accessibilityIdentifier = @"profile.summaryCard";
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:summaryCardView];
  [stackView addArrangedSubview:summaryCardView];
  self.summaryCardView = summaryCardView;

  UILabel *eyebrowLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold]
                                        color:MRRProfileNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                                   [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
  eyebrowLabel.text = @"SIGNED IN";
  eyebrowLabel.accessibilityIdentifier = @"profile.eyebrowLabel";
  [summaryCardView addSubview:eyebrowLabel];

  UILabel *displayNameLabel =
      [self labelWithFont:[UIFont boldSystemFontOfSize:30.0]
                    color:MRRProfileNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  displayNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
  displayNameLabel.accessibilityIdentifier = @"profile.displayNameLabel";
  displayNameLabel.numberOfLines = 0;
  displayNameLabel.text = [self.session displayNameOrFallback];
  [summaryCardView addSubview:displayNameLabel];
  self.displayNameLabel = displayNameLabel;

  UILabel *emailLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0]
                                      color:MRRProfileNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                                 [UIColor colorWithWhite:0.70 alpha:1.0])];
  emailLabel.translatesAutoresizingMaskIntoConstraints = NO;
  emailLabel.accessibilityIdentifier = @"profile.emailLabel";
  emailLabel.numberOfLines = 0;
  emailLabel.text = self.session.email.length > 0 ? self.session.email : @"No email returned";
  [summaryCardView addSubview:emailLabel];
  self.emailLabel = emailLabel;

  UILabel *providerLabel =
      [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                    color:MRRProfileNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  providerLabel.translatesAutoresizingMaskIntoConstraints = NO;
  providerLabel.accessibilityIdentifier = @"profile.providerLabel";
  providerLabel.numberOfLines = 0;
  providerLabel.text = [NSString stringWithFormat:@"Provider: %@", MRRAuthDisplayNameForProviderType(self.session.providerType)];
  [summaryCardView addSubview:providerLabel];
  self.providerLabel = providerLabel;

  UILabel *emailVerificationLabel =
      [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                    color:MRRProfileNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                               [UIColor colorWithWhite:0.96 alpha:1.0])];
  emailVerificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
  emailVerificationLabel.accessibilityIdentifier = @"profile.emailVerificationLabel";
  emailVerificationLabel.numberOfLines = 0;
  emailVerificationLabel.text = [NSString stringWithFormat:@"Email verified: %@", self.session.emailVerified ? @"Yes" : @"No"];
  [summaryCardView addSubview:emailVerificationLabel];
  self.emailVerificationLabel = emailVerificationLabel;

  UILabel *statusLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0]
                                       color:MRRProfileNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                                  [UIColor colorWithWhite:0.70 alpha:1.0])];
  statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  statusLabel.accessibilityIdentifier = @"profile.statusLabel";
  statusLabel.numberOfLines = 0;
  statusLabel.text = @"Your authentication session is active and ready for future subscription wiring.";
  [summaryCardView addSubview:statusLabel];
  self.statusLabel = statusLabel;

  UIButton *logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
  logoutButton.translatesAutoresizingMaskIntoConstraints = NO;
  logoutButton.accessibilityIdentifier = @"profile.logoutButton";
  [logoutButton setTitle:@"Log Out" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRolePrimary toButton:logoutButton];
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

    [emailVerificationLabel.topAnchor constraintEqualToAnchor:providerLabel.bottomAnchor constant:8.0],
    [emailVerificationLabel.leadingAnchor constraintEqualToAnchor:summaryCardView.leadingAnchor constant:22.0],
    [emailVerificationLabel.trailingAnchor constraintEqualToAnchor:summaryCardView.trailingAnchor constant:-22.0],

    [statusLabel.topAnchor constraintEqualToAnchor:emailVerificationLabel.bottomAnchor constant:8.0],
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
  if (self.isPerformingLogout) {
    return;
  }

  [self presentLogoutConfirmationAlert];
}

- (void)performConfirmedLogout {
  if (self.isPerformingLogout) {
    return;
  }

  [self updateLogoutUIForInProgress:YES];
  if (self.logoutController != nil) {
    __block ProfileViewController *blockSelf = self;
    [self.logoutController performLogoutForSession:self.session completion:^(NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        ProfileViewController *strongSelf = blockSelf;
        if (strongSelf == nil) {
          return;
        }

        [strongSelf updateLogoutUIForInProgress:NO];
        if (error != nil) {
          [strongSelf presentLogoutError:error];
        }
      });
    }];
    return;
  }

  NSError *signOutError = nil;
  BOOL didSignOut = [self.authenticationController signOut:&signOutError];
  [self updateLogoutUIForInProgress:NO];
  if (!didSignOut || signOutError != nil) {
    [self presentLogoutError:signOutError];
  }
}

- (void)updateLogoutUIForInProgress:(BOOL)inProgress {
  self.performingLogout = inProgress;
  self.logoutButton.enabled = !inProgress;
  [self.logoutButton setTitle:(inProgress ? @"Syncing your recipes..." : @"Log Out") forState:UIControlStateNormal];
  [self.logoutButton setTitle:(inProgress ? @"Syncing your recipes..." : @"Log Out") forState:UIControlStateDisabled];
  self.statusLabel.text = inProgress
                              ? @"Syncing saved recipes and your created recipes before logout so everything stays available after you sign back in."
                              : @"Your authentication session is active and ready for future subscription wiring.";
}

- (void)presentLogoutConfirmationAlert {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Log out?"
                                                                           message:@"You will return to onboarding until another account signs in."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"profile.logoutAlert";

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
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Couldn't Log Out"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"profile.logoutErrorAlert";
  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Retry"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                                                      [self performConfirmedLogout];
                                                    }]];
  [self presentViewController:alertController animated:YES completion:nil];
}

@end
