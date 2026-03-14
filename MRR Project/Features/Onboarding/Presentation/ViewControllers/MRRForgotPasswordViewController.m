#import "MRRForgotPasswordViewController.h"

#import "../../../Authentication/MRRAuthErrorMapper.h"

static UIColor *MRRResetDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRResetNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRResetDynamicFallbackColor(lightColor, darkColor);
}

static UIActivityIndicatorViewStyle MRRResetLoadingIndicatorStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIActivityIndicatorViewStyleMedium;
  }

  return UIActivityIndicatorViewStyleGray;
}

static UIBlurEffectStyle MRRResetLoadingOverlayBlurStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIBlurEffectStyleSystemChromeMaterial;
  }

  return UIBlurEffectStyleLight;
}

static UIColor *MRRResetBackgroundColor(void) {
  return MRRResetNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.08 alpha:1.0]);
}

static UIColor *MRRResetPrimaryTextColor(void) {
  return MRRResetNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.14 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRResetSecondaryTextColor(void) {
  return MRRResetNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.44 alpha:1.0], [UIColor colorWithWhite:0.68 alpha:1.0]);
}

static UIColor *MRRResetFieldSurfaceColor(void) {
  return MRRResetNamedColor(@"CardSurfaceColor", [UIColor whiteColor], [UIColor colorWithWhite:0.14 alpha:1.0]);
}

static UIColor *MRRResetFieldBorderColor(void) {
  return MRRResetNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.15 alpha:0.12], [UIColor colorWithWhite:1.0 alpha:0.12]);
}

static UIColor *MRRResetAccentColor(void) {
  return MRRResetNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRResetLoadingOverlayTintColor(void) { return [UIColor colorWithWhite:0.0 alpha:0.12]; }

static UIColor *MRRResetLoadingPanelColor(void) {
  return MRRResetNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:1.0 alpha:0.88], [UIColor colorWithWhite:0.16 alpha:0.9]);
}

static UIColor *MRRResetLoadingIndicatorColor(void) { return MRRResetPrimaryTextColor(); }

static CGFloat const MRRResetKeyboardFieldGap = 18.0;

@interface MRRForgotPasswordViewController () <UITextFieldDelegate>

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, copy, nullable) NSString *prefilledEmail;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIButton *backButton;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *helperLabel;
@property(nonatomic, retain) UILabel *emailLabel;
@property(nonatomic, retain) UITextField *emailField;
@property(nonatomic, retain) UILabel *errorLabel;
@property(nonatomic, retain) UIView *actionSpacerView;
@property(nonatomic, retain) UIButton *submitButton;
@property(nonatomic, retain) UIVisualEffectView *loadingOverlayView;
@property(nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, assign) UITextField *activeTextField;
@property(nonatomic, retain) NSLayoutConstraint *submitButtonTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *contentBottomConstraint;

- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder;
- (void)registerForKeyboardNotifications;
- (void)unregisterForKeyboardNotifications;
- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification;
- (void)updateScrollInsetsForKeyboardFrame:(CGRect)keyboardFrame
                                  duration:(NSTimeInterval)duration
                            animationCurve:(UIViewAnimationCurve)animationCurve;
- (void)ensureRelevantControlVisibleForKeyboard;
- (void)handleBackgroundTap:(UITapGestureRecognizer *)gestureRecognizer;
- (void)handleBackTapped:(id)sender;
- (void)handleSubmitTapped:(id)sender;
- (void)setLoading:(BOOL)loading;
- (void)showError:(NSError *)error;
- (void)showValidationErrorMessage:(NSString *)message;
- (NSString *)trimmedEmailValue;
- (void)presentSuccessAlert;
- (void)handleSuccessAlertAcknowledged;

@end

@implementation MRRForgotPasswordViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController prefilledEmail:(NSString *)prefilledEmail {
  NSParameterAssert(authenticationController != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _authenticationController = [authenticationController retain];
    _prefilledEmail = [prefilledEmail copy];
  }

  return self;
}

- (void)dealloc {
  [self unregisterForKeyboardNotifications];
  [_contentBottomConstraint release];
  [_submitButtonTopConstraint release];
  [_loadingOverlayView release];
  [_loadingIndicator release];
  [_submitButton release];
  [_actionSpacerView release];
  [_errorLabel release];
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

  self.view.accessibilityIdentifier = @"auth.resetPassword.view";
  self.view.backgroundColor = MRRResetBackgroundColor();
  [self buildViewHierarchy];
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

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  scrollView.accessibilityIdentifier = @"auth.resetPassword.scrollView";
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  contentView.accessibilityIdentifier = @"auth.resetPassword.contentView";
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleBackgroundTap:)] autorelease];
  tapGestureRecognizer.cancelsTouchesInView = NO;
  [scrollView addGestureRecognizer:tapGestureRecognizer];

  UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
  backButton.translatesAutoresizingMaskIntoConstraints = NO;
  backButton.accessibilityIdentifier = @"auth.resetPassword.backButton";
  backButton.accessibilityLabel = @"Back";
  backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  backButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
  [backButton setTitle:@"←" forState:UIControlStateNormal];
  [backButton setTitleColor:MRRResetPrimaryTextColor() forState:UIControlStateNormal];
  [backButton addTarget:self action:@selector(handleBackTapped:) forControlEvents:UIControlEventTouchUpInside];
  [contentView addSubview:backButton];
  self.backButton = backButton;

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:38.0 weight:UIFontWeightBold] color:MRRResetPrimaryTextColor()];
  titleLabel.accessibilityIdentifier = @"auth.resetPassword.titleLabel";
  titleLabel.numberOfLines = 0;
  titleLabel.text = @"Reset password";
  [contentView addSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *helperLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular] color:MRRResetSecondaryTextColor()];
  helperLabel.accessibilityIdentifier = @"auth.resetPassword.helperLabel";
  helperLabel.numberOfLines = 0;
  helperLabel.text = @"Enter the email address tied to your account and we will send a reset link if the account exists.";
  [contentView addSubview:helperLabel];
  self.helperLabel = helperLabel;

  UILabel *emailLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold] color:MRRResetPrimaryTextColor()];
  emailLabel.accessibilityIdentifier = @"auth.resetPassword.emailLabel";
  emailLabel.text = @"Email";
  [contentView addSubview:emailLabel];
  self.emailLabel = emailLabel;

  UITextField *emailField = [self textFieldWithPlaceholder:@"you@example.com"];
  emailField.accessibilityIdentifier = @"auth.resetPassword.emailField";
  emailField.keyboardType = UIKeyboardTypeEmailAddress;
  emailField.textContentType = UITextContentTypeEmailAddress;
  emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  emailField.autocorrectionType = UITextAutocorrectionTypeNo;
  emailField.returnKeyType = UIReturnKeySend;
  emailField.delegate = self;
  emailField.text = self.prefilledEmail;
  [contentView addSubview:emailField];
  self.emailField = emailField;

  UILabel *errorLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                      color:[UIColor colorWithRed:0.76 green:0.18 blue:0.21 alpha:1.0]];
  errorLabel.accessibilityIdentifier = @"auth.resetPassword.errorLabel";
  errorLabel.numberOfLines = 0;
  errorLabel.hidden = YES;
  [contentView addSubview:errorLabel];
  self.errorLabel = errorLabel;

  UIView *actionSpacerView = [[[UIView alloc] init] autorelease];
  actionSpacerView.translatesAutoresizingMaskIntoConstraints = NO;
  actionSpacerView.accessibilityIdentifier = @"auth.resetPassword.actionSpacer";
  [contentView addSubview:actionSpacerView];
  self.actionSpacerView = actionSpacerView;

  UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
  submitButton.translatesAutoresizingMaskIntoConstraints = NO;
  submitButton.accessibilityIdentifier = @"auth.resetPassword.submitButton";
  submitButton.backgroundColor = MRRResetAccentColor();
  submitButton.layer.cornerRadius = 18.0;
  submitButton.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
  [submitButton setTitle:@"Send Reset Email" forState:UIControlStateNormal];
  [submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [submitButton addTarget:self action:@selector(handleSubmitTapped:) forControlEvents:UIControlEventTouchUpInside];
  [contentView addSubview:submitButton];
  self.submitButton = submitButton;

  UIVisualEffectView *loadingOverlayView =
      [[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:MRRResetLoadingOverlayBlurStyle()]] autorelease];
  loadingOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingOverlayView.accessibilityIdentifier = @"auth.resetPassword.loadingOverlay";
  loadingOverlayView.hidden = YES;
  loadingOverlayView.alpha = 0.0;
  loadingOverlayView.contentView.backgroundColor = MRRResetLoadingOverlayTintColor();
  [self.view addSubview:loadingOverlayView];
  self.loadingOverlayView = loadingOverlayView;

  UIView *loadingContainerView = [[[UIView alloc] init] autorelease];
  loadingContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingContainerView.accessibilityIdentifier = @"auth.resetPassword.loadingContainer";
  loadingContainerView.backgroundColor = MRRResetLoadingPanelColor();
  loadingContainerView.layer.cornerRadius = 22.0;
  loadingContainerView.clipsToBounds = YES;
  [loadingOverlayView.contentView addSubview:loadingContainerView];

  UIActivityIndicatorView *loadingIndicator =
      [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:MRRResetLoadingIndicatorStyle()] autorelease];
  loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  loadingIndicator.accessibilityIdentifier = @"auth.resetPassword.loadingIndicator";
  loadingIndicator.color = MRRResetLoadingIndicatorColor();
  loadingIndicator.hidesWhenStopped = YES;
  [loadingContainerView addSubview:loadingIndicator];
  self.loadingIndicator = loadingIndicator;

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

    [emailLabel.topAnchor constraintEqualToAnchor:helperLabel.bottomAnchor constant:30.0],
    [emailLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [emailLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [emailField.topAnchor constraintEqualToAnchor:emailLabel.bottomAnchor constant:8.0],
    [emailField.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [emailField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [emailField.heightAnchor constraintEqualToConstant:56.0],

    [errorLabel.topAnchor constraintEqualToAnchor:emailField.bottomAnchor constant:12.0],
    [errorLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [errorLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],

    [actionSpacerView.topAnchor constraintEqualToAnchor:errorLabel.bottomAnchor constant:12.0],
    [actionSpacerView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [actionSpacerView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    [actionSpacerView.heightAnchor constraintGreaterThanOrEqualToConstant:0.0],

    [submitButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [submitButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [submitButton.heightAnchor constraintEqualToConstant:56.0],

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

  self.submitButtonTopConstraint = [submitButton.topAnchor constraintEqualToAnchor:actionSpacerView.bottomAnchor constant:16.0];
  self.contentBottomConstraint = [submitButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0];
  self.submitButtonTopConstraint.active = YES;
  self.contentBottomConstraint.active = YES;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = font;
  label.textColor = color;
  return label;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder {
  UITextField *textField = [[[UITextField alloc] init] autorelease];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.borderStyle = UITextBorderStyleNone;
  textField.backgroundColor = MRRResetFieldSurfaceColor();
  textField.textColor = MRRResetPrimaryTextColor();
  textField.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium];
  textField.layer.cornerRadius = 16.0;
  textField.layer.borderWidth = 1.0;
  textField.layer.borderColor = [MRRResetFieldBorderColor() CGColor];
  textField.clipsToBounds = YES;

  UIView *paddingView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, 1.0)] autorelease];
  textField.leftView = paddingView;
  textField.leftViewMode = UITextFieldViewModeAlways;

  UIColor *placeholderColor =
      MRRResetNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.55 alpha:1.0], [UIColor colorWithWhite:0.52 alpha:1.0]);
  textField.attributedPlaceholder = [[[NSAttributedString alloc] initWithString:placeholder
                                                                     attributes:@{NSForegroundColorAttributeName : placeholderColor}] autorelease];
  return textField;
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
  CGFloat bottomInset = keyboardInset > 0.0 ? keyboardInset + MRRResetKeyboardFieldGap : 0.0;
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
      self.scrollView.contentOffset.y + CGRectGetHeight(self.scrollView.bounds) - self.scrollView.contentInset.bottom - MRRResetKeyboardFieldGap;
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

- (void)handleBackTapped:(id)sender {
  if (self.navigationController != nil && self.navigationController.viewControllers.count > 1) {
    [self.navigationController popViewControllerAnimated:YES];
    return;
  }

  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleSubmitTapped:(id)sender {
  NSString *email = [self trimmedEmailValue];
  if (email.length == 0 || [email containsString:@"@"] == NO) {
    [self showValidationErrorMessage:@"Please enter a valid email address to continue."];
    return;
  }

  [self setLoading:YES];
  [self.authenticationController sendPasswordResetForEmail:email
                                                completion:^(NSError *_Nullable error) {
                                                  [self setLoading:NO];
                                                  if (error != nil) {
                                                    [self showError:error];
                                                    return;
                                                  }

                                                  [self presentSuccessAlert];
                                                }];
}

- (void)setLoading:(BOOL)loading {
  self.backButton.enabled = !loading;
  self.emailField.enabled = !loading;
  self.submitButton.enabled = !loading;

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

- (NSString *)trimmedEmailValue {
  return [self.emailField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)presentSuccessAlert {
  UIAlertController *alertController = [UIAlertController
      alertControllerWithTitle:@"Reset Email Sent"
                       message:@"If an account matches this email, we sent a password reset link. Check your inbox and spam folder."
                preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"auth.resetPassword.successAlert";
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *action) {
                                                      [self handleSuccessAlertAcknowledged];
                                                    }]];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)handleSuccessAlertAcknowledged {
  if (self.navigationController != nil) {
    [self.navigationController popToRootViewControllerAnimated:YES];
    return;
  }

  [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == self.emailField) {
    [self handleSubmitTapped:textField];
  }

  return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  self.activeTextField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  if (self.activeTextField == textField) {
    self.activeTextField = nil;
  }
}

@end
