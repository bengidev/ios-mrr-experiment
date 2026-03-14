#import "MRREmailAuthenticationViewController.h"

#import "MRRAuthErrorMapper.h"

static UIColor *MRRAuthDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRAuthNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRAuthDynamicFallbackColor(lightColor, darkColor);
}

static UIActivityIndicatorViewStyle MRRAuthLoadingIndicatorStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIActivityIndicatorViewStyleMedium;
  }

  return UIActivityIndicatorViewStyleGray;
}

@interface MRREmailAuthenticationViewController () <UITextFieldDelegate>

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, assign) MRREmailAuthenticationMode mode;
@property(nonatomic, copy, nullable) NSString *prefilledEmail;
@property(nonatomic, assign, getter=isPendingLinkFlow) BOOL pendingLinkFlow;
@property(nonatomic, retain) UIView *cardView;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *helperLabel;
@property(nonatomic, retain) UISegmentedControl *modeControl;
@property(nonatomic, retain) UITextField *emailField;
@property(nonatomic, retain) UITextField *passwordField;
@property(nonatomic, retain) UILabel *errorLabel;
@property(nonatomic, retain) UIButton *submitButton;
@property(nonatomic, retain) UIActivityIndicatorView *loadingIndicator;

- (void)buildViewHierarchy;
- (void)applyCurrentModeText;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secureEntry:(BOOL)secureEntry;
- (void)handleModeChanged:(UISegmentedControl *)sender;
- (void)handleCloseTapped:(id)sender;
- (void)handleSubmitTapped:(id)sender;
- (void)setLoading:(BOOL)loading;
- (void)showError:(NSError *)error;
- (void)showValidationErrorMessage:(NSString *)message;
- (NSString *)trimmedValueForTextField:(UITextField *)textField;

@end

@implementation MRREmailAuthenticationViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                            mode:(MRREmailAuthenticationMode)mode
                                   prefilledEmail:(NSString *)prefilledEmail
                                  pendingLinkFlow:(BOOL)pendingLinkFlow {
  NSParameterAssert(authenticationController != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _authenticationController = [authenticationController retain];
    _mode = mode;
    _prefilledEmail = [prefilledEmail copy];
    _pendingLinkFlow = pendingLinkFlow;
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  }

  return self;
}

- (void)dealloc {
  [_loadingIndicator release];
  [_submitButton release];
  [_errorLabel release];
  [_passwordField release];
  [_emailField release];
  [_modeControl release];
  [_helperLabel release];
  [_titleLabel release];
  [_cardView release];
  [_prefilledEmail release];
  [_authenticationController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.58];
  self.view.accessibilityIdentifier = @"auth.emailModal.view";

  [self buildViewHierarchy];
  [self applyCurrentModeText];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  if (self.emailField.text.length == 0) {
    [self.emailField becomeFirstResponder];
    return;
  }

  [self.passwordField becomeFirstResponder];
}

- (void)buildViewHierarchy {
  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.accessibilityIdentifier = @"auth.emailModal.cardView";
  cardView.backgroundColor = MRRAuthNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.14 alpha:1.0]);
  cardView.layer.cornerRadius = 28.0;
  cardView.layer.masksToBounds = YES;
  [self.view addSubview:cardView];
  self.cardView = cardView;

  UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  closeButton.accessibilityIdentifier = @"auth.emailModal.closeButton";
  closeButton.layer.cornerRadius = 17.0;
  closeButton.backgroundColor = [MRRAuthNamedColor(@"TextPrimaryColor", [UIColor blackColor], [UIColor whiteColor]) colorWithAlphaComponent:0.08];
  [closeButton setTitle:@"X" forState:UIControlStateNormal];
  [closeButton setTitleColor:MRRAuthNamedColor(@"TextPrimaryColor", [UIColor blackColor], [UIColor whiteColor])
                    forState:UIControlStateNormal];
  [closeButton addTarget:self action:@selector(handleCloseTapped:) forControlEvents:UIControlEventTouchUpInside];
  [cardView addSubview:closeButton];

  UILabel *titleLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:28.0]
                                      color:MRRAuthNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                              [UIColor colorWithWhite:0.96 alpha:1.0])];
  titleLabel.accessibilityIdentifier = @"auth.emailModal.titleLabel";
  titleLabel.numberOfLines = 0;
  [cardView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *helperLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0]
                                       color:MRRAuthNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0],
                                                               [UIColor colorWithWhite:0.70 alpha:1.0])];
  helperLabel.accessibilityIdentifier = @"auth.emailModal.helperLabel";
  helperLabel.numberOfLines = 0;
  [cardView addSubview:helperLabel];
  self.helperLabel = helperLabel;

  UISegmentedControl *modeControl = [[[UISegmentedControl alloc] initWithItems:@[ @"Create Account", @"Sign In" ]] autorelease];
  modeControl.translatesAutoresizingMaskIntoConstraints = NO;
  modeControl.accessibilityIdentifier = @"auth.emailModal.modeControl";
  modeControl.selectedSegmentIndex = self.mode;
  modeControl.enabled = !self.isPendingLinkFlow;
  [modeControl addTarget:self action:@selector(handleModeChanged:) forControlEvents:UIControlEventValueChanged];
  [cardView addSubview:modeControl];
  self.modeControl = modeControl;

  UITextField *emailField = [self textFieldWithPlaceholder:@"Email address" secureEntry:NO];
  emailField.accessibilityIdentifier = @"auth.emailModal.emailField";
  emailField.keyboardType = UIKeyboardTypeEmailAddress;
  emailField.textContentType = UITextContentTypeEmailAddress;
  emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  emailField.autocorrectionType = UITextAutocorrectionTypeNo;
  emailField.returnKeyType = UIReturnKeyNext;
  emailField.delegate = self;
  emailField.text = self.prefilledEmail;
  [cardView addSubview:emailField];
  self.emailField = emailField;

  UITextField *passwordField = [self textFieldWithPlaceholder:@"Password" secureEntry:YES];
  passwordField.accessibilityIdentifier = @"auth.emailModal.passwordField";
  passwordField.textContentType = UITextContentTypePassword;
  passwordField.returnKeyType = UIReturnKeyGo;
  passwordField.delegate = self;
  [cardView addSubview:passwordField];
  self.passwordField = passwordField;

  UILabel *errorLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                      color:[UIColor colorWithRed:0.76 green:0.18 blue:0.21 alpha:1.0]];
  errorLabel.accessibilityIdentifier = @"auth.emailModal.errorLabel";
  errorLabel.numberOfLines = 0;
  errorLabel.hidden = YES;
  [cardView addSubview:errorLabel];
  self.errorLabel = errorLabel;

  UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
  submitButton.translatesAutoresizingMaskIntoConstraints = NO;
  submitButton.accessibilityIdentifier = @"auth.emailModal.submitButton";
  submitButton.backgroundColor =
      MRRAuthNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                        [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  submitButton.layer.cornerRadius = 18.0;
  submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
  [submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [submitButton addTarget:self action:@selector(handleSubmitTapped:) forControlEvents:UIControlEventTouchUpInside];
  [cardView addSubview:submitButton];
  self.submitButton = submitButton;

  UIActivityIndicatorView *loadingIndicator =
      [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:MRRAuthLoadingIndicatorStyle()] autorelease];
  loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  loadingIndicator.accessibilityIdentifier = @"auth.emailModal.loadingIndicator";
  loadingIndicator.color = [UIColor whiteColor];
  loadingIndicator.hidesWhenStopped = YES;
  [submitButton addSubview:loadingIndicator];
  self.loadingIndicator = loadingIndicator;

  [NSLayoutConstraint activateConstraints:@[
    [cardView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],

    [closeButton.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
    [closeButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
    [closeButton.widthAnchor constraintEqualToConstant:34.0],
    [closeButton.heightAnchor constraintEqualToConstant:34.0],

    [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:24.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

    [helperLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
    [helperLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [helperLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],

    [modeControl.topAnchor constraintEqualToAnchor:helperLabel.bottomAnchor constant:18.0],
    [modeControl.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [modeControl.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],

    [emailField.topAnchor constraintEqualToAnchor:modeControl.bottomAnchor constant:18.0],
    [emailField.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [emailField.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],
    [emailField.heightAnchor constraintEqualToConstant:52.0],

    [passwordField.topAnchor constraintEqualToAnchor:emailField.bottomAnchor constant:12.0],
    [passwordField.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [passwordField.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],
    [passwordField.heightAnchor constraintEqualToConstant:52.0],

    [errorLabel.topAnchor constraintEqualToAnchor:passwordField.bottomAnchor constant:12.0],
    [errorLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [errorLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],

    [submitButton.topAnchor constraintEqualToAnchor:errorLabel.bottomAnchor constant:16.0],
    [submitButton.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
    [submitButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],
    [submitButton.heightAnchor constraintEqualToConstant:54.0],
    [submitButton.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

    [loadingIndicator.centerXAnchor constraintEqualToAnchor:submitButton.centerXAnchor],
    [loadingIndicator.centerYAnchor constraintEqualToAnchor:submitButton.centerYAnchor]
  ]];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = font;
  label.textColor = color;
  return label;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secureEntry:(BOOL)secureEntry {
  UITextField *textField = [[[UITextField alloc] init] autorelease];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.borderStyle = UITextBorderStyleRoundedRect;
  textField.secureTextEntry = secureEntry;
  textField.placeholder = placeholder;
  textField.backgroundColor =
      MRRAuthNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.10 alpha:1.0]);
  textField.textColor =
      MRRAuthNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
  return textField;
}

- (void)applyCurrentModeText {
  BOOL isSignUpMode = self.mode == MRREmailAuthenticationModeSignUp;
  self.titleLabel.text = isSignUpMode ? @"Create your Culina account" : @"Welcome back";

  if (self.isPendingLinkFlow) {
    self.helperLabel.text = @"Email ini sudah punya akun. Sign in untuk menautkan Google ke akun yang sudah ada.";
  } else if (isSignUpMode) {
    self.helperLabel.text = @"Gunakan email dan password untuk menyimpan progress serta membuka flow home yang sudah login.";
  } else {
    self.helperLabel.text = @"Masuk lagi dengan email yang sudah terdaftar di project ini.";
  }

  [self.submitButton setTitle:isSignUpMode ? @"Create Account" : @"Sign In"
                     forState:UIControlStateNormal];
}

- (void)handleModeChanged:(UISegmentedControl *)sender {
  self.mode = (MRREmailAuthenticationMode)sender.selectedSegmentIndex;
  [self applyCurrentModeText];
}

- (void)handleCloseTapped:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleSubmitTapped:(id)sender {
  NSString *email = [self trimmedValueForTextField:self.emailField];
  NSString *password = [self trimmedValueForTextField:self.passwordField];

  if (email.length == 0 || [email containsString:@"@"] == NO) {
    [self showValidationErrorMessage:@"Masukkan email yang valid untuk melanjutkan."];
    return;
  }

  if (password.length < 6) {
    [self showValidationErrorMessage:@"Password minimal 6 karakter."];
    return;
  }

  [self setLoading:YES];

  MRRAuthSessionCompletion completion = ^(MRRAuthSession *_Nullable session, NSError *_Nullable error) {
    if (error != nil) {
      [self setLoading:NO];
      [self showError:error];
      return;
    }

    if ([self.authenticationController hasPendingCredentialLink]) {
      [self.authenticationController linkCredentialIfNeededWithCompletion:^(NSError *_Nullable linkError) {
        [self setLoading:NO];
        if (linkError != nil) {
          [self showError:linkError];
          return;
        }

        [self.delegate emailAuthenticationViewControllerDidAuthenticate:self];
      }];
      return;
    }

    [self setLoading:NO];
    if (session != nil) {
      [self.delegate emailAuthenticationViewControllerDidAuthenticate:self];
    }
  };

  if (self.mode == MRREmailAuthenticationModeSignUp) {
    [self.authenticationController signUpWithEmail:email password:password completion:completion];
    return;
  }

  [self.authenticationController signInWithEmail:email password:password completion:completion];
}

- (void)setLoading:(BOOL)loading {
  self.modeControl.enabled = !loading && !self.isPendingLinkFlow;
  self.emailField.enabled = !loading;
  self.passwordField.enabled = !loading;
  self.submitButton.enabled = !loading;

  if (loading) {
    self.errorLabel.hidden = YES;
    self.errorLabel.text = nil;
    [self.loadingIndicator startAnimating];
    self.submitButton.titleLabel.alpha = 0.0;
  } else {
    [self.loadingIndicator stopAnimating];
    self.submitButton.titleLabel.alpha = 1.0;
  }
}

- (void)showError:(NSError *)error {
  NSString *message = [MRRAuthErrorMapper messageForError:error];
  if (message.length == 0) {
    return;
  }

  self.errorLabel.hidden = NO;
  self.errorLabel.text = message;
}

- (void)showValidationErrorMessage:(NSString *)message {
  self.errorLabel.hidden = NO;
  self.errorLabel.text = message;
}

- (NSString *)trimmedValueForTextField:(UITextField *)textField {
  return [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == self.emailField) {
    [self.passwordField becomeFirstResponder];
    return NO;
  }

  [self handleSubmitTapped:textField];
  return NO;
}

@end
