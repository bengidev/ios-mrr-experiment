#import "MRREmailAuthenticationViewController.h"

#import "../../../Authentication/MRRAuthErrorMapper.h"
#import "MRRForgotPasswordViewController.h"

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

static UIBlurEffectStyle MRRAuthLoadingOverlayBlurStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIBlurEffectStyleSystemChromeMaterial;
  }

  return UIBlurEffectStyleLight;
}

static UIColor *MRRAuthBackgroundColor(void) {
  return MRRAuthNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.08 alpha:1.0]);
}

static UIColor *MRRAuthPrimaryTextColor(void) {
  return MRRAuthNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.14 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRAuthSecondaryTextColor(void) {
  return MRRAuthNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.44 alpha:1.0], [UIColor colorWithWhite:0.68 alpha:1.0]);
}

static UIColor *MRRAuthFieldSurfaceColor(void) {
  return MRRAuthNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.14 alpha:1.0]);
}

static UIColor *MRRAuthFieldBorderColor(void) {
  return MRRAuthNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.15 alpha:0.12], [UIColor colorWithWhite:1.0 alpha:0.12]);
}

static UIColor *MRRAuthAccentColor(void) {
  return MRRAuthNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                           [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRAuthLoadingOverlayTintColor(void) { return [UIColor colorWithWhite:0.0 alpha:0.12]; }

static UIColor *MRRAuthLoadingPanelColor(void) {
  return MRRAuthNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:0.88], [UIColor colorWithWhite:0.16 alpha:0.9]);
}

static UIColor *MRRAuthLoadingIndicatorColor(void) { return MRRAuthPrimaryTextColor(); }

static CGFloat const MRRAuthSwitchButtonPressedScale = 0.97;
static CGFloat const MRRAuthSwitchButtonPressedAlpha = 0.88;
static CGFloat const MRRAuthKeyboardFieldGap = 18.0;

@interface MRREmailAuthenticationViewController () <UITextFieldDelegate>

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, assign) MRREmailAuthenticationMode mode;
@property(nonatomic, copy, nullable) NSString *prefilledEmail;
@property(nonatomic, assign, getter=isPendingLinkFlow) BOOL pendingLinkFlow;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIButton *backButton;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *helperLabel;
@property(nonatomic, retain) UIStackView *signUpFieldsStackView;
@property(nonatomic, retain) UILabel *firstNameLabel;
@property(nonatomic, retain) UITextField *firstNameField;
@property(nonatomic, retain) UILabel *lastNameLabel;
@property(nonatomic, retain) UITextField *lastNameField;
@property(nonatomic, retain) UILabel *emailLabel;
@property(nonatomic, retain) UITextField *emailField;
@property(nonatomic, retain) UILabel *passwordLabel;
@property(nonatomic, retain) UITextField *passwordField;
@property(nonatomic, retain) UIStackView *modeDetailsStackView;
@property(nonatomic, retain) UILabel *termsLabel;
@property(nonatomic, retain) UIStackView *forgotPasswordRow;
@property(nonatomic, retain) UIButton *forgotPasswordButton;
@property(nonatomic, retain) UILabel *errorLabel;
@property(nonatomic, retain) UIView *actionSpacerView;
@property(nonatomic, retain) UIButton *submitButton;
@property(nonatomic, retain) UIVisualEffectView *loadingOverlayView;
@property(nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, retain) UIStackView *footerStackView;
@property(nonatomic, retain) UILabel *footerPromptLabel;
@property(nonatomic, retain) UIButton *switchModeButton;
@property(nonatomic, assign) UITextField *activeTextField;
@property(nonatomic, retain) NSLayoutConstraint *emailSectionTopToHelperConstraint;
@property(nonatomic, retain) NSLayoutConstraint *emailSectionTopToSignUpFieldsConstraint;
@property(nonatomic, retain) NSLayoutConstraint *submitButtonTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *footerTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *footerBottomConstraint;

- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (UIStackView *)verticalSectionWithSpacing:(CGFloat)spacing;
- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secureEntry:(BOOL)secureEntry;
- (void)applyModeCopy;
- (void)registerForKeyboardNotifications;
- (void)unregisterForKeyboardNotifications;
- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification;
- (void)updateScrollInsetsForKeyboardFrame:(CGRect)keyboardFrame
                                  duration:(NSTimeInterval)duration
                            animationCurve:(UIViewAnimationCurve)animationCurve;
- (void)ensureRelevantControlVisibleForKeyboard;
- (void)handleBackgroundTap:(UITapGestureRecognizer *)gestureRecognizer;
- (void)configurePressFeedbackForButton:(UIButton *)button;
- (void)handlePressableButtonTouchDown:(UIButton *)button;
- (void)handlePressableButtonTouchUp:(UIButton *)button;
- (void)handleBackTapped:(id)sender;
- (void)handleSubmitTapped:(id)sender;
- (void)handleForgotPasswordTapped:(id)sender;
- (void)handleSwitchModeTapped:(id)sender;
- (void)pushForgotPasswordViewController;
- (void)setLoading:(BOOL)loading;
- (void)showError:(NSError *)error;
- (void)showValidationErrorMessage:(NSString *)message;
- (NSString *)trimmedValueForTextField:(UITextField *)textField;
- (void)replaceTopControllerWithMode:(MRREmailAuthenticationMode)mode;
- (void)presentPlaceholderAlertWithTitle:(NSString *)title message:(NSString *)message accessibilityIdentifier:(NSString *)accessibilityIdentifier;

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
  }

  return self;
}

- (void)dealloc {
  [self unregisterForKeyboardNotifications];
  [_footerBottomConstraint release];
  [_footerTopConstraint release];
  [_submitButtonTopConstraint release];
  [_emailSectionTopToSignUpFieldsConstraint release];
  [_emailSectionTopToHelperConstraint release];
  [_switchModeButton release];
  [_footerPromptLabel release];
  [_footerStackView release];
  [_loadingOverlayView release];
  [_loadingIndicator release];
  [_submitButton release];
  [_actionSpacerView release];
  [_errorLabel release];
  [_forgotPasswordButton release];
  [_forgotPasswordRow release];
  [_termsLabel release];
  [_modeDetailsStackView release];
  [_passwordField release];
  [_passwordLabel release];
  [_lastNameField release];
  [_lastNameLabel release];
  [_firstNameField release];
  [_firstNameLabel release];
  [_signUpFieldsStackView release];
  [_emailField release];
  [_emailLabel release];
  [_helperLabel release];
  [_titleLabel release];
  [_backButton release];
  [_contentView release];
  [_scrollView release];
  [_prefilledEmail release];
  [_authenticationController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = MRRAuthBackgroundColor();
  [self buildViewHierarchy];
  [self applyModeCopy];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self.navigationController setNavigationBarHidden:YES animated:NO];
  [self registerForKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  [self unregisterForKeyboardNotifications];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  scrollView.accessibilityIdentifier = @"auth.emailScreen.scrollView";
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  contentView.accessibilityIdentifier = @"auth.emailScreen.contentView";
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleBackgroundTap:)] autorelease];
  tapGestureRecognizer.cancelsTouchesInView = NO;
  [scrollView addGestureRecognizer:tapGestureRecognizer];

  UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
  backButton.translatesAutoresizingMaskIntoConstraints = NO;
  backButton.accessibilityIdentifier = @"auth.emailScreen.backButton";
  backButton.accessibilityLabel = @"Back";
  backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  backButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
  [backButton setTitle:@"←" forState:UIControlStateNormal];
  [backButton setTitleColor:MRRAuthPrimaryTextColor() forState:UIControlStateNormal];
  [backButton addTarget:self action:@selector(handleBackTapped:) forControlEvents:UIControlEventTouchUpInside];
  [contentView addSubview:backButton];
  self.backButton = backButton;

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:38.0 weight:UIFontWeightBold] color:MRRAuthPrimaryTextColor()];
  titleLabel.accessibilityIdentifier = @"auth.emailScreen.titleLabel";
  titleLabel.numberOfLines = 0;
  [contentView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *helperLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular] color:MRRAuthSecondaryTextColor()];
  helperLabel.accessibilityIdentifier = @"auth.emailScreen.helperLabel";
  helperLabel.numberOfLines = 0;
  [contentView addSubview:helperLabel];
  self.helperLabel = helperLabel;

  UIStackView *signUpFieldsStackView = [self verticalSectionWithSpacing:22.0];
  signUpFieldsStackView.accessibilityIdentifier = @"auth.signUp.fieldsStack";
  [contentView addSubview:signUpFieldsStackView];
  self.signUpFieldsStackView = signUpFieldsStackView;

  UIStackView *firstNameSection = [self verticalSectionWithSpacing:8.0];
  [signUpFieldsStackView addArrangedSubview:firstNameSection];

  UILabel *firstNameLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold] color:MRRAuthPrimaryTextColor()];
  firstNameLabel.accessibilityIdentifier = @"auth.signUp.firstNameLabel";
  firstNameLabel.text = @"First Name";
  [firstNameSection addArrangedSubview:firstNameLabel];
  self.firstNameLabel = firstNameLabel;

  UITextField *firstNameField = [self textFieldWithPlaceholder:@"Your first name" secureEntry:NO];
  firstNameField.accessibilityIdentifier = @"auth.signUp.firstNameField";
  firstNameField.returnKeyType = UIReturnKeyNext;
  firstNameField.delegate = self;
  [firstNameSection addArrangedSubview:firstNameField];
  self.firstNameField = firstNameField;

  UIStackView *lastNameSection = [self verticalSectionWithSpacing:8.0];
  [signUpFieldsStackView addArrangedSubview:lastNameSection];

  UILabel *lastNameLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold] color:MRRAuthPrimaryTextColor()];
  lastNameLabel.accessibilityIdentifier = @"auth.signUp.lastNameLabel";
  lastNameLabel.text = @"Last Name";
  [lastNameSection addArrangedSubview:lastNameLabel];
  self.lastNameLabel = lastNameLabel;

  UITextField *lastNameField = [self textFieldWithPlaceholder:@"Your last name" secureEntry:NO];
  lastNameField.accessibilityIdentifier = @"auth.signUp.lastNameField";
  lastNameField.returnKeyType = UIReturnKeyNext;
  lastNameField.delegate = self;
  [lastNameSection addArrangedSubview:lastNameField];
  self.lastNameField = lastNameField;

  UIStackView *emailSection = [self verticalSectionWithSpacing:8.0];
  [contentView addSubview:emailSection];

  UILabel *emailLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold] color:MRRAuthPrimaryTextColor()];
  emailLabel.accessibilityIdentifier = @"auth.emailScreen.emailLabel";
  emailLabel.text = @"Email";
  [emailSection addArrangedSubview:emailLabel];
  self.emailLabel = emailLabel;

  UITextField *emailField = [self textFieldWithPlaceholder:@"you@example.com" secureEntry:NO];
  emailField.accessibilityIdentifier = @"auth.emailScreen.emailField";
  emailField.keyboardType = UIKeyboardTypeEmailAddress;
  emailField.textContentType = UITextContentTypeEmailAddress;
  emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  emailField.autocorrectionType = UITextAutocorrectionTypeNo;
  emailField.returnKeyType = UIReturnKeyNext;
  emailField.delegate = self;
  emailField.text = self.prefilledEmail;
  [emailSection addArrangedSubview:emailField];
  self.emailField = emailField;

  UIStackView *passwordSection = [self verticalSectionWithSpacing:8.0];
  [contentView addSubview:passwordSection];

  UILabel *passwordLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold] color:MRRAuthPrimaryTextColor()];
  passwordLabel.accessibilityIdentifier = @"auth.emailScreen.passwordLabel";
  passwordLabel.text = @"Password";
  [passwordSection addArrangedSubview:passwordLabel];
  self.passwordLabel = passwordLabel;

  UITextField *passwordField = [self textFieldWithPlaceholder:@"Enter password" secureEntry:YES];
  passwordField.accessibilityIdentifier = @"auth.emailScreen.passwordField";
  passwordField.textContentType = UITextContentTypePassword;
  passwordField.returnKeyType = UIReturnKeyGo;
  passwordField.delegate = self;
  [passwordSection addArrangedSubview:passwordField];
  self.passwordField = passwordField;

  UIStackView *modeDetailsStackView = [self verticalSectionWithSpacing:8.0];
  modeDetailsStackView.accessibilityIdentifier = @"auth.emailScreen.modeDetailsStack";
  [contentView addSubview:modeDetailsStackView];
  self.modeDetailsStackView = modeDetailsStackView;

  UILabel *termsLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular] color:MRRAuthSecondaryTextColor()];
  termsLabel.accessibilityIdentifier = @"auth.signUp.termsLabel";
  termsLabel.numberOfLines = 0;
  termsLabel.text = @"By signing up you agree to the Culina portfolio terms and privacy placeholder.";
  [modeDetailsStackView addArrangedSubview:termsLabel];
  self.termsLabel = termsLabel;

  UIStackView *forgotPasswordRow = [[[UIStackView alloc] init] autorelease];
  forgotPasswordRow.translatesAutoresizingMaskIntoConstraints = NO;
  forgotPasswordRow.axis = UILayoutConstraintAxisHorizontal;
  forgotPasswordRow.alignment = UIStackViewAlignmentTrailing;
  forgotPasswordRow.distribution = UIStackViewDistributionFill;
  forgotPasswordRow.accessibilityIdentifier = @"auth.signIn.optionsRow";
  [modeDetailsStackView addArrangedSubview:forgotPasswordRow];
  self.forgotPasswordRow = forgotPasswordRow;

  UIView *forgotSpacer = [[[UIView alloc] init] autorelease];
  forgotSpacer.translatesAutoresizingMaskIntoConstraints = NO;
  [forgotPasswordRow addArrangedSubview:forgotSpacer];

  UIButton *forgotPasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
  forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
  forgotPasswordButton.accessibilityIdentifier = @"auth.signIn.forgotPasswordButton";
  forgotPasswordButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  [forgotPasswordButton setTitle:@"Forgot Password?" forState:UIControlStateNormal];
  [forgotPasswordButton setTitleColor:MRRAuthAccentColor() forState:UIControlStateNormal];
  [forgotPasswordButton addTarget:self action:@selector(handleForgotPasswordTapped:) forControlEvents:UIControlEventTouchUpInside];
  [forgotPasswordRow addArrangedSubview:forgotPasswordButton];
  self.forgotPasswordButton = forgotPasswordButton;

  UILabel *errorLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                      color:[UIColor colorWithRed:0.76 green:0.18 blue:0.21 alpha:1.0]];
  errorLabel.accessibilityIdentifier = @"auth.emailScreen.errorLabel";
  errorLabel.numberOfLines = 0;
  errorLabel.hidden = YES;
  [contentView addSubview:errorLabel];
  self.errorLabel = errorLabel;

  UIView *actionSpacerView = [[[UIView alloc] init] autorelease];
  actionSpacerView.translatesAutoresizingMaskIntoConstraints = NO;
  actionSpacerView.accessibilityIdentifier = @"auth.emailScreen.actionSpacer";
  [contentView addSubview:actionSpacerView];
  self.actionSpacerView = actionSpacerView;

  UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
  submitButton.translatesAutoresizingMaskIntoConstraints = NO;
  submitButton.accessibilityIdentifier = @"auth.emailScreen.submitButton";
  submitButton.backgroundColor = MRRAuthAccentColor();
  submitButton.layer.cornerRadius = 18.0;
  submitButton.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
  [submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [submitButton addTarget:self action:@selector(handleSubmitTapped:) forControlEvents:UIControlEventTouchUpInside];
  [contentView addSubview:submitButton];
  self.submitButton = submitButton;

  UIVisualEffectView *loadingOverlayView =
      [[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:MRRAuthLoadingOverlayBlurStyle()]] autorelease];
  loadingOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingOverlayView.accessibilityIdentifier = @"auth.emailScreen.loadingOverlay";
  loadingOverlayView.hidden = YES;
  loadingOverlayView.alpha = 0.0;
  loadingOverlayView.contentView.backgroundColor = MRRAuthLoadingOverlayTintColor();
  [self.view addSubview:loadingOverlayView];
  self.loadingOverlayView = loadingOverlayView;

  UIView *loadingContainerView = [[[UIView alloc] init] autorelease];
  loadingContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingContainerView.accessibilityIdentifier = @"auth.emailScreen.loadingContainer";
  loadingContainerView.backgroundColor = MRRAuthLoadingPanelColor();
  loadingContainerView.layer.cornerRadius = 22.0;
  loadingContainerView.clipsToBounds = YES;
  [loadingOverlayView.contentView addSubview:loadingContainerView];

  UIActivityIndicatorView *loadingIndicator =
      [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:MRRAuthLoadingIndicatorStyle()] autorelease];
  loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  loadingIndicator.accessibilityIdentifier = @"auth.emailScreen.loadingIndicator";
  loadingIndicator.color = MRRAuthLoadingIndicatorColor();
  loadingIndicator.hidesWhenStopped = YES;
  [loadingContainerView addSubview:loadingIndicator];
  self.loadingIndicator = loadingIndicator;

  UIStackView *footerStackView = [[[UIStackView alloc] init] autorelease];
  footerStackView.translatesAutoresizingMaskIntoConstraints = NO;
  footerStackView.axis = UILayoutConstraintAxisHorizontal;
  footerStackView.alignment = UIStackViewAlignmentCenter;
  footerStackView.spacing = 6.0;
  footerStackView.accessibilityIdentifier = @"auth.emailScreen.footerStack";
  [contentView addSubview:footerStackView];
  self.footerStackView = footerStackView;

  UILabel *footerPromptLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular] color:MRRAuthSecondaryTextColor()];
  footerPromptLabel.accessibilityIdentifier = @"auth.emailScreen.footerPromptLabel";
  [footerStackView addArrangedSubview:footerPromptLabel];
  self.footerPromptLabel = footerPromptLabel;

  UIButton *switchModeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  switchModeButton.translatesAutoresizingMaskIntoConstraints = NO;
  switchModeButton.accessibilityIdentifier = @"auth.emailScreen.switchModeButton";
  switchModeButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  [switchModeButton setTitleColor:MRRAuthAccentColor() forState:UIControlStateNormal];
  [switchModeButton addTarget:self action:@selector(handleSwitchModeTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self configurePressFeedbackForButton:switchModeButton];
  [footerStackView addArrangedSubview:switchModeButton];
  self.switchModeButton = switchModeButton;

  [NSLayoutConstraint activateConstraints:@[
    [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
    [contentView.heightAnchor constraintGreaterThanOrEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor],

    [backButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20.0],
    [backButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [backButton.widthAnchor constraintGreaterThanOrEqualToConstant:44.0],

    [titleLabel.topAnchor constraintEqualToAnchor:backButton.bottomAnchor constant:18.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [helperLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [helperLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [helperLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [signUpFieldsStackView.topAnchor constraintEqualToAnchor:helperLabel.bottomAnchor constant:30.0],
    [signUpFieldsStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [signUpFieldsStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [emailSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [emailSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [firstNameField.heightAnchor constraintEqualToConstant:56.0],
    [lastNameField.heightAnchor constraintEqualToConstant:56.0],
    [emailField.heightAnchor constraintEqualToConstant:56.0],

    [passwordSection.topAnchor constraintEqualToAnchor:emailSection.bottomAnchor constant:22.0],
    [passwordSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [passwordSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [passwordField.heightAnchor constraintEqualToConstant:56.0],

    [modeDetailsStackView.topAnchor constraintEqualToAnchor:passwordSection.bottomAnchor constant:10.0],
    [modeDetailsStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [modeDetailsStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [errorLabel.topAnchor constraintEqualToAnchor:modeDetailsStackView.bottomAnchor constant:12.0],
    [errorLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [errorLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [actionSpacerView.topAnchor constraintEqualToAnchor:errorLabel.bottomAnchor constant:12.0],
    [actionSpacerView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [actionSpacerView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    [actionSpacerView.heightAnchor constraintGreaterThanOrEqualToConstant:0.0],

    [submitButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [submitButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [submitButton.heightAnchor constraintEqualToConstant:56.0],

    [footerStackView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
    [footerStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [footerStackView.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [loadingOverlayView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [loadingOverlayView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [loadingOverlayView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [loadingOverlayView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [loadingContainerView.centerXAnchor constraintEqualToAnchor:loadingOverlayView.contentView.centerXAnchor],
    [loadingContainerView.centerYAnchor constraintEqualToAnchor:loadingOverlayView.contentView.centerYAnchor],
    [loadingContainerView.widthAnchor constraintEqualToConstant:88.0],
    [loadingContainerView.heightAnchor constraintEqualToConstant:88.0],

    [loadingIndicator.centerXAnchor constraintEqualToAnchor:loadingContainerView.centerXAnchor],
    [loadingIndicator.centerYAnchor constraintEqualToAnchor:loadingContainerView.centerYAnchor]
  ]];

  self.emailSectionTopToHelperConstraint = [emailSection.topAnchor constraintEqualToAnchor:helperLabel.bottomAnchor constant:34.0];
  self.emailSectionTopToSignUpFieldsConstraint = [emailSection.topAnchor constraintEqualToAnchor:signUpFieldsStackView.bottomAnchor constant:22.0];
  self.submitButtonTopConstraint = [submitButton.topAnchor constraintEqualToAnchor:actionSpacerView.bottomAnchor constant:16.0];
  self.footerTopConstraint = [footerStackView.topAnchor constraintEqualToAnchor:submitButton.bottomAnchor constant:14.0];
  self.footerBottomConstraint = [footerStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-18.0];
  self.emailSectionTopToHelperConstraint.active = YES;
  self.submitButtonTopConstraint.active = YES;
  self.footerTopConstraint.active = YES;
  self.footerBottomConstraint.active = YES;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = font;
  label.textColor = color;
  return label;
}

- (UIStackView *)verticalSectionWithSpacing:(CGFloat)spacing {
  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.alignment = UIStackViewAlignmentFill;
  stackView.distribution = UIStackViewDistributionFill;
  stackView.spacing = spacing;
  return stackView;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secureEntry:(BOOL)secureEntry {
  UITextField *textField = [[[UITextField alloc] init] autorelease];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.borderStyle = UITextBorderStyleNone;
  textField.secureTextEntry = secureEntry;
  textField.backgroundColor = MRRAuthFieldSurfaceColor();
  textField.textColor = MRRAuthPrimaryTextColor();
  textField.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium];
  textField.layer.cornerRadius = 16.0;
  textField.layer.borderWidth = 1.0;
  textField.layer.borderColor = [MRRAuthFieldBorderColor() CGColor];
  textField.clipsToBounds = YES;

  UIView *paddingView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, 1.0)] autorelease];
  textField.leftView = paddingView;
  textField.leftViewMode = UITextFieldViewModeAlways;

  UIColor *placeholderColor =
      MRRAuthNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.55 alpha:1.0], [UIColor colorWithWhite:0.52 alpha:1.0]);
  textField.attributedPlaceholder = [[[NSAttributedString alloc] initWithString:placeholder
                                                                     attributes:@{NSForegroundColorAttributeName : placeholderColor}] autorelease];
  return textField;
}

- (void)applyModeCopy {
  BOOL isSignUpMode = self.mode == MRREmailAuthenticationModeSignUp;

  self.view.accessibilityIdentifier = isSignUpMode ? @"auth.signUp.view" : @"auth.signIn.view";
  self.titleLabel.text = isSignUpMode ? @"Sign up" : @"Sign in";
  self.signUpFieldsStackView.hidden = !isSignUpMode;
  self.emailSectionTopToHelperConstraint.active = !isSignUpMode;
  self.emailSectionTopToSignUpFieldsConstraint.active = isSignUpMode;

  if (self.isPendingLinkFlow) {
    self.helperLabel.hidden = NO;
    self.helperLabel.text = @"Sign in with your existing email account to finish linking the pending credential.";
  } else if (isSignUpMode) {
    self.helperLabel.hidden = YES;
    self.helperLabel.text = nil;
  } else {
    self.helperLabel.hidden = NO;
    self.helperLabel.text = @"Use the email account you already registered for this portfolio build.";
  }

  [self.submitButton setTitle:isSignUpMode ? @"Continue" : @"Sign In" forState:UIControlStateNormal];
  self.termsLabel.hidden = !isSignUpMode;
  self.forgotPasswordRow.hidden = isSignUpMode;
  self.footerStackView.spacing = isSignUpMode ? 6.0 : 4.0;
  self.submitButtonTopConstraint.constant = isSignUpMode ? 18.0 : 16.0;
  self.footerTopConstraint.constant = isSignUpMode ? 22.0 : 12.0;
  self.footerBottomConstraint.constant = isSignUpMode ? -24.0 : -18.0;

  if (self.isPendingLinkFlow) {
    self.footerPromptLabel.hidden = YES;
    self.switchModeButton.hidden = YES;
  } else {
    self.footerPromptLabel.hidden = NO;
    self.switchModeButton.hidden = NO;
    self.footerPromptLabel.text = isSignUpMode ? @"Already have an account?" : @"Don't have an account?";
    [self.switchModeButton setTitle:isSignUpMode ? @"Sign In" : @"Sign Up" forState:UIControlStateNormal];
  }
}

- (void)registerForKeyboardNotifications {
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(handleKeyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)unregisterForKeyboardNotifications {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  UIViewAnimationCurve animationCurve = (UIViewAnimationCurve)[userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

  [self updateScrollInsetsForKeyboardFrame:keyboardFrame duration:duration animationCurve:animationCurve];
}

- (void)updateScrollInsetsForKeyboardFrame:(CGRect)keyboardFrame
                                  duration:(NSTimeInterval)duration
                            animationCurve:(UIViewAnimationCurve)animationCurve {
  CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
  CGRect intersection = CGRectIntersection(self.view.bounds, keyboardFrameInView);
  CGFloat overlapHeight = CGRectIsNull(intersection) ? 0.0 : CGRectGetHeight(intersection);
  CGFloat safeAreaBottomInset = 0.0;
  if (@available(iOS 11.0, *)) {
    safeAreaBottomInset = self.view.safeAreaInsets.bottom;
  }

  CGFloat keyboardInset = MAX(0.0, overlapHeight - safeAreaBottomInset);
  CGFloat bottomInset = keyboardInset > 0.0 ? keyboardInset + MRRAuthKeyboardFieldGap : 0.0;
  UIEdgeInsets targetInsets = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
  UIViewAnimationOptions animationOptions = ((UIViewAnimationOptions)animationCurve << 16);

  [UIView animateWithDuration:duration
      delay:0.0
      options:animationOptions | UIViewAnimationOptionBeginFromCurrentState
      animations:^{
        self.scrollView.contentInset = targetInsets;
        self.scrollView.scrollIndicatorInsets = targetInsets;
        [self.view layoutIfNeeded];
      }
      completion:^(__unused BOOL finished) {
        if (keyboardInset > 0.0) {
          [self ensureRelevantControlVisibleForKeyboard];
        }
      }];
}

- (void)ensureRelevantControlVisibleForKeyboard {
  if (self.activeTextField == nil) {
    return;
  }

  CGRect fieldRect = [self.scrollView convertRect:self.activeTextField.bounds fromView:self.activeTextField];
  CGFloat visibleTopY = self.scrollView.contentOffset.y + 12.0;
  CGFloat visibleBottomY =
      self.scrollView.contentOffset.y + CGRectGetHeight(self.scrollView.bounds) - self.scrollView.contentInset.bottom - MRRAuthKeyboardFieldGap;
  CGFloat targetOffsetY = self.scrollView.contentOffset.y;

  if (CGRectGetMaxY(fieldRect) > visibleBottomY) {
    targetOffsetY += CGRectGetMaxY(fieldRect) - visibleBottomY;
  } else if (CGRectGetMinY(fieldRect) < visibleTopY) {
    targetOffsetY -= visibleTopY - CGRectGetMinY(fieldRect);
  } else {
    return;
  }

  CGFloat minOffsetY = -self.scrollView.adjustedContentInset.top;
  CGFloat maxOffsetY =
      MAX(minOffsetY, self.scrollView.contentSize.height + self.scrollView.contentInset.bottom - CGRectGetHeight(self.scrollView.bounds));
  targetOffsetY = MIN(MAX(targetOffsetY, minOffsetY), maxOffsetY);

  [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, targetOffsetY) animated:YES];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gestureRecognizer {
  [self.view endEditing:YES];
}

- (void)configurePressFeedbackForButton:(UIButton *)button {
  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
  [button addTarget:self
                action:@selector(handlePressableButtonTouchUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:UIControlEventTouchDragEnter];
}

- (void)handlePressableButtonTouchDown:(UIButton *)button {
  [UIView animateWithDuration:0.12
                   animations:^{
                     button.transform = CGAffineTransformMakeScale(MRRAuthSwitchButtonPressedScale, MRRAuthSwitchButtonPressedScale);
                     button.alpha = MRRAuthSwitchButtonPressedAlpha;
                   }];
}

- (void)handlePressableButtonTouchUp:(UIButton *)button {
  [UIView animateWithDuration:0.18
                        delay:0.0
       usingSpringWithDamping:0.78
        initialSpringVelocity:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
                     button.transform = CGAffineTransformIdentity;
                     button.alpha = 1.0;
                   }
                   completion:nil];
}

- (void)handleBackTapped:(id)sender {
  if (self.navigationController != nil && self.navigationController.viewControllers.count > 1) {
    [self.navigationController popViewControllerAnimated:YES];
    return;
  }

  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleSubmitTapped:(id)sender {
  NSString *email = [self trimmedValueForTextField:self.emailField];
  NSString *password = [self trimmedValueForTextField:self.passwordField];

  if (email.length == 0 || [email containsString:@"@"] == NO) {
    [self showValidationErrorMessage:@"Please enter a valid email address to continue."];
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

- (void)handleForgotPasswordTapped:(id)sender {
  [self pushForgotPasswordViewController];
}

- (void)handleSwitchModeTapped:(id)sender {
  if (self.isPendingLinkFlow) {
    return;
  }

  MRREmailAuthenticationMode targetMode =
      self.mode == MRREmailAuthenticationModeSignUp ? MRREmailAuthenticationModeSignIn : MRREmailAuthenticationModeSignUp;
  [self replaceTopControllerWithMode:targetMode];
}

- (void)setLoading:(BOOL)loading {
  self.backButton.enabled = !loading;
  self.emailField.enabled = !loading;
  self.passwordField.enabled = !loading;
  self.submitButton.enabled = !loading;
  self.switchModeButton.enabled = !loading && !self.isPendingLinkFlow;
  self.forgotPasswordButton.enabled = !loading;

  if (loading) {
    [self.view endEditing:YES];
    self.errorLabel.hidden = YES;
    self.errorLabel.text = nil;
    self.loadingOverlayView.hidden = NO;
    self.loadingOverlayView.alpha = 1.0;
    [self.loadingIndicator startAnimating];
  } else {
    [self.loadingIndicator stopAnimating];
    self.loadingOverlayView.alpha = 0.0;
    self.loadingOverlayView.hidden = YES;
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

- (void)replaceTopControllerWithMode:(MRREmailAuthenticationMode)mode {
  MRREmailAuthenticationViewController *viewController =
      [[[MRREmailAuthenticationViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                                 mode:mode
                                                                       prefilledEmail:[self trimmedValueForTextField:self.emailField]
                                                                      pendingLinkFlow:NO] autorelease];
  viewController.delegate = self.delegate;

  if (self.navigationController == nil) {
    return;
  }

  NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.navigationController.viewControllers];
  if (viewControllers.count > 0) {
    [viewControllers removeLastObject];
  }
  [viewControllers addObject:viewController];
  [self.navigationController setViewControllers:viewControllers animated:YES];
}

- (void)pushForgotPasswordViewController {
  MRRForgotPasswordViewController *viewController =
      [[[MRRForgotPasswordViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                  prefilledEmail:[self trimmedValueForTextField:self.emailField]] autorelease];

  if (self.navigationController != nil) {
    [self.navigationController pushViewController:viewController animated:YES];
    return;
  }

  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:viewController] autorelease];
  navigationController.navigationBarHidden = YES;
  [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)presentPlaceholderAlertWithTitle:(NSString *)title message:(NSString *)message accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = accessibilityIdentifier;
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == self.firstNameField) {
    [self.lastNameField becomeFirstResponder];
    return NO;
  }

  if (textField == self.lastNameField) {
    [self.emailField becomeFirstResponder];
    return NO;
  }

  if (textField == self.emailField) {
    [self.passwordField becomeFirstResponder];
    return NO;
  }

  [self handleSubmitTapped:textField];
  return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  self.activeTextField = textField;
  [self ensureRelevantControlVisibleForKeyboard];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  if (self.activeTextField == textField) {
    self.activeTextField = nil;
  }
}

@end
