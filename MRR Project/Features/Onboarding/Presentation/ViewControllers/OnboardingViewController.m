#import "OnboardingViewController.h"

#include <math.h>

#import <AuthenticationServices/AuthenticationServices.h>

#import "../../../Authentication/MRRAuthenticationController.h"
#import "../../../Authentication/MRRAuthErrorMapper.h"
#import "MRREmailAuthenticationViewController.h"
#import "../../../Authentication/MRRFirebaseAuthenticationController.h"
#import "../../../../Layout/MRRLiquidGlassStyling.h"
#import "../../../../Layout/MRRLayoutScaling.h"
#import "../../Data/OnboardingStateController.h"
#import "../Views/OnboardingRecipeCarouselCell.h"
#import "OnboardingRecipeDetailViewController.h"

static NSString *const MRRRecipeCarouselCellReuseIdentifier = @"MRRRecipeCarouselCell";
static NSInteger const MRRCarouselLoopMultiplier = 5;
static NSString *const MRROnboardingAppIconImageName = @"OnboardingAppIcon";
static CGFloat const MRRCarouselSingleRowSpacingPadding = 32.0;
static CGFloat const MRROnboardingButtonPressedScale = 0.97;
static CGFloat const MRROnboardingButtonPressedAlpha = 0.88;

typedef NS_ENUM(NSInteger, MRROnboardingAuthButtonIconStyle) {
  MRROnboardingAuthButtonIconStyleEmail = 0,
  MRROnboardingAuthButtonIconStyleGoogle = 1,
  MRROnboardingAuthButtonIconStyleApple = 2,
};

static UIColor *MRRDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
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

static UIColor *MRRNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRDynamicFallbackColor(lightColor, darkColor);
}

static UIActivityIndicatorViewStyle MRROnboardingLoadingIndicatorStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIActivityIndicatorViewStyleMedium;
  }

  return UIActivityIndicatorViewStyleGray;
}

static UIBlurEffectStyle MRROnboardingLoadingOverlayBlurStyle(void) {
  if (@available(iOS 13.0, *)) {
    return UIBlurEffectStyleSystemChromeMaterial;
  }

  return UIBlurEffectStyleLight;
}

static UIColor *MRRBackgroundSurfaceColor(void) {
  return MRRNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0], [UIColor colorWithWhite:0.10 alpha:1.0]);
}

static UIColor *MRRPrimaryTextColor(void) {
  return MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRSecondaryTextColor(void) {
  return MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0], [UIColor colorWithWhite:0.63 alpha:1.0]);
}

static UIColor *MRROnboardingLoadingOverlayTintColor(void) { return [UIColor colorWithWhite:0.0 alpha:0.12]; }

@interface OnboardingViewController () <UICollectionViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout,
                                        UIAdaptivePresentationControllerDelegate,
                                        UIScrollViewDelegate,
                                        OnboardingRecipeDetailViewControllerDelegate,
                                        MRREmailAuthenticationViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *stateController;
@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, copy) NSArray<OnboardingRecipe *> *recipes;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UIView *heroCarouselContainerView;
@property(nonatomic, retain) UIStackView *heroCarouselRowsStackView;
@property(nonatomic, retain) UIView *iconWrapperView;
@property(nonatomic, retain) UICollectionView *carouselCollectionView;
@property(nonatomic, retain) UICollectionView *secondaryCarouselCollectionView;
@property(nonatomic, retain) UIPageControl *pageControl;
@property(nonatomic, retain) CADisplayLink *carouselDisplayLink;
@property(nonatomic, retain) UIView *iconContainerView;
@property(nonatomic, retain) UIImageView *iconImageView;
@property(nonatomic, retain) UIView *badgeView;
@property(nonatomic, retain) UILabel *titleLabel;
@property(nonatomic, retain) UILabel *subtitleLabel;
@property(nonatomic, retain) UILabel *captionLabel;
@property(nonatomic, retain) UILabel *benefitTitleLabel;
@property(nonatomic, retain) UILabel *benefitBodyLabel;
@property(nonatomic, retain) UILabel *signinPromptLabel;
@property(nonatomic, retain) UIButton *signinLabel;
@property(nonatomic, retain) UILabel *authDividerLabel;
@property(nonatomic, retain) UIView *spacerView;
@property(nonatomic, retain) UIView *heroSectionSpacerView;
@property(nonatomic, retain) UIView *bodyActionSpacerView;
@property(nonatomic, retain) UIButton *emailButton;
@property(nonatomic, retain) UIButton *googleButton;
@property(nonatomic, retain) UIButton *appleButton;
@property(nonatomic, retain) UIVisualEffectView *loadingOverlayView;
@property(nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, retain) NSLayoutConstraint *stackLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *stackTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *stackTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *stackBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *spacerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *heroSectionSpacerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *bodyActionSpacerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconWrapperHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconImageWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconImageHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *carouselHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *primaryCarouselLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *primaryCarouselTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *secondaryCarouselLeadingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *secondaryCarouselTrailingConstraint;
@property(nonatomic, retain) NSLayoutConstraint *emailButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *googleButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *appleButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *dividerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *benefitTitleHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *benefitBodyHeightConstraint;
@property(nonatomic, assign) NSInteger currentRecipeIndex;
@property(nonatomic, assign) NSInteger currentCarouselItemIndex;
@property(nonatomic, assign) NSInteger secondaryCurrentCarouselItemIndex;
@property(nonatomic, assign) CFTimeInterval lastCarouselDisplayTimestamp;
@property(nonatomic, assign) BOOL hasAppliedInitialCarouselPosition;
@property(nonatomic, assign) CGSize lastPositionedCarouselBoundsSize;
@property(nonatomic, assign) CGSize lastPositionedSecondaryCarouselBoundsSize;
@property(nonatomic, assign, getter=isDetailPresented) BOOL detailPresented;
@property(nonatomic, assign, getter=isViewVisible) BOOL viewVisible;

- (NSArray<OnboardingRecipe *> *)loadRecipes;
- (void)buildViewHierarchy;
- (UICollectionView *)buildCarouselCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (NSArray<UICollectionView *> *)allCarouselCollectionViews;
- (UIView *)badgeViewWithText:(NSString *)text
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              labelIdentifier:(NSString *)labelIdentifier;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UIButton *)authButtonWithTitle:(NSString *)title
                        iconStyle:(MRROnboardingAuthButtonIconStyle)iconStyle
          accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           action:(SEL)action;
- (void)applyAuthButtonIconStyle:(MRROnboardingAuthButtonIconStyle)iconStyle toButton:(UIButton *)button;
- (UIImage *)authButtonIconForStyle:(MRROnboardingAuthButtonIconStyle)iconStyle;
- (UIImage *)symbolButtonIconNamed:(NSString *)systemName pointSize:(CGFloat)pointSize tintColor:(nullable UIColor *)tintColor;
- (UIImage *)monogramButtonIconWithText:(NSString *)text
                        backgroundColor:(UIColor *)backgroundColor
                        foregroundColor:(UIColor *)foregroundColor
                               diameter:(CGFloat)diameter;
- (UIView *)authDividerView;
- (void)handleEmailSignupTapped:(id)sender;
- (void)handleGoogleSignupTapped:(id)sender;
- (void)handleAppleContinueTapped:(id)sender;
- (void)handleSigninTapped:(id)sender;
- (void)pushEmailAuthenticationViewControllerWithMode:(MRREmailAuthenticationMode)mode
                                       prefilledEmail:(nullable NSString *)prefilledEmail
                                      pendingLinkFlow:(BOOL)pendingLinkFlow;
- (void)presentAuthenticationAlertForError:(NSError *)error;
- (void)presentAuthenticationAlertWithTitle:(NSString *)title message:(NSString *)message accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (void)presentAppleSignInStubAlert;
- (void)notifyDelegateOfAuthentication;
- (void)setAuthButtonsEnabled:(BOOL)enabled;
- (void)beginLoadingForGoogleSignIn;
- (void)endLoadingForGoogleSignIn;
- (void)configurePressFeedbackForButton:(UIButton *)button;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;
- (void)updateLayoutMetricsIfNeeded;
- (void)updateScrollBehaviorIfNeeded;
- (BOOL)isCarouselCollectionView:(UICollectionView *)collectionView;
- (BOOL)isPrimaryCarouselCollectionView:(UICollectionView *)collectionView;
- (NSInteger)currentCarouselItemIndexForCollectionView:(UICollectionView *)collectionView;
- (void)setCurrentCarouselItemIndex:(NSInteger)itemIndex forCollectionView:(UICollectionView *)collectionView;
- (NSInteger)defaultRecipeIndexForCollectionView:(UICollectionView *)collectionView;
- (CGSize)lastPositionedCarouselBoundsSizeForCollectionView:(UICollectionView *)collectionView;
- (void)setLastPositionedCarouselBoundsSize:(CGSize)size forCollectionView:(UICollectionView *)collectionView;
- (void)synchronizeCarouselStateForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)carouselPhaseOffsetForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)visibleCarouselViewportWidthForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)visibleCarouselViewportMidXForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)middleLoopStartOffsetForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)middleLoopEndOffsetForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)loopSpanWidthForCollectionView:(UICollectionView *)collectionView;
- (void)recenterContinuousCarouselOffsetIfNeededForCollectionView:(UICollectionView *)collectionView;
- (CGFloat)carouselAutoscrollPointsPerSecondForCollectionView:(UICollectionView *)collectionView;
- (void)advanceCarouselCollectionView:(UICollectionView *)collectionView
                            direction:(CGFloat)direction
                            deltaTime:(CFTimeInterval)deltaTime;
- (CGFloat)layoutViewportHeight;
- (CGFloat)layoutViewportWidth;
- (NSAttributedString *)titleAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning;
- (NSAttributedString *)carouselCaptionAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning;
- (UICollectionViewFlowLayout *)carouselLayout;
- (UICollectionViewFlowLayout *)carouselLayoutForCollectionView:(UICollectionView *)collectionView;
- (void)updateCarouselLayoutIfNeeded;
- (void)updateCarouselLayoutIfNeededForCollectionView:(UICollectionView *)collectionView;
- (CGSize)carouselItemSizeForAvailableWidth:(CGFloat)availableWidth availableHeight:(CGFloat)availableHeight lineSpacing:(CGFloat)lineSpacing;
- (NSInteger)virtualCarouselItemCount;
- (NSInteger)recipeIndexForCarouselItemIndex:(NSInteger)itemIndex;
- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex;
- (NSInteger)carouselItemIndexForRecipeIndex:(NSInteger)recipeIndex nearCarouselItemIndex:(NSInteger)referenceIndex;
- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX;
- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX inCollectionView:(UICollectionView *)collectionView;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex inCollectionView:(UICollectionView *)collectionView;
- (void)ensureInitialCarouselPositionIfNeeded;
- (void)scrollCollectionView:(UICollectionView *)collectionView toCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated;
- (void)scrollToCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated;
- (void)scrollToRecipeAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)updatePageControl;
- (void)recenterCarouselIfNeeded;
- (void)recenterCarouselIfNeededForCollectionView:(UICollectionView *)collectionView;
- (void)presentRecipeDetailForRecipeAtIndex:(NSInteger)index;
- (void)pauseCarouselAutoscroll;
- (void)resumeCarouselAutoscrollIfPossible;
- (void)handleCarouselDisplayLink:(CADisplayLink *)displayLink;
- (void)handleCarouselTimer:(NSTimer *)timer;
- (BOOL)shouldAnimateModalTransitions;

@end

@implementation OnboardingViewController

- (instancetype)init {
  OnboardingStateController *stateController =
      [[[OnboardingStateController alloc] initWithUserDefaults:[NSUserDefaults standardUserDefaults]] autorelease];
  id<MRRAuthenticationController> authenticationController = [[[MRRFirebaseAuthenticationController alloc] init] autorelease];
  return [self initWithStateController:stateController authenticationController:authenticationController];
}

- (instancetype)initWithStateController:(OnboardingStateController *)stateController {
  id<MRRAuthenticationController> authenticationController = [[[MRRFirebaseAuthenticationController alloc] init] autorelease];
  return [self initWithStateController:stateController authenticationController:authenticationController];
}

- (instancetype)initWithStateController:(OnboardingStateController *)stateController
               authenticationController:(id<MRRAuthenticationController>)authenticationController {
  NSParameterAssert(stateController != nil);
  NSParameterAssert(authenticationController != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _stateController = [stateController retain];
    _authenticationController = [authenticationController retain];
    _recipes = [[self loadRecipes] copy];
    _currentRecipeIndex = 0;
    if (_recipes.count > 0) {
      _currentCarouselItemIndex = (MRRCarouselLoopMultiplier / 2) * _recipes.count;
      NSInteger secondaryRecipeIndex = _recipes.count > 1 ? (_recipes.count / 2) : 0;
      _secondaryCurrentCarouselItemIndex = ((MRRCarouselLoopMultiplier / 2) * _recipes.count) + secondaryRecipeIndex;
    }
  }

  return self;
}

- (void)dealloc {
  [self pauseCarouselAutoscroll];
  [_loadingIndicator release];
  [_loadingOverlayView release];
  [_scrollView release];
  [_contentStackView release];
  [_heroCarouselContainerView release];
  [_heroCarouselRowsStackView release];
  [_iconWrapperView release];
  _carouselCollectionView.delegate = nil;
  _carouselCollectionView.dataSource = nil;
  _secondaryCarouselCollectionView.delegate = nil;
  _secondaryCarouselCollectionView.dataSource = nil;
  [_dividerHeightConstraint release];
  [_benefitBodyHeightConstraint release];
  [_benefitTitleHeightConstraint release];
  [_bodyActionSpacerHeightConstraint release];
  [_heroSectionSpacerHeightConstraint release];
  [_primaryCarouselTrailingConstraint release];
  [_primaryCarouselLeadingConstraint release];
  [_secondaryCarouselTrailingConstraint release];
  [_secondaryCarouselLeadingConstraint release];
  [_appleButtonHeightConstraint release];
  [_googleButtonHeightConstraint release];
  [_emailButtonHeightConstraint release];
  [_carouselHeightConstraint release];
  [_spacerHeightConstraint release];
  [_iconImageHeightConstraint release];
  [_iconImageWidthConstraint release];
  [_iconContainerHeightConstraint release];
  [_iconContainerWidthConstraint release];
  [_iconContainerTopConstraint release];
  [_iconWrapperHeightConstraint release];
  [_stackTrailingConstraint release];
  [_stackLeadingConstraint release];
  [_stackBottomConstraint release];
  [_stackTopConstraint release];
  [_appleButton release];
  [_googleButton release];
  [_emailButton release];
  [_spacerView release];
  [_authDividerLabel release];
  [_signinLabel release];
  [_signinPromptLabel release];
  [_bodyActionSpacerView release];
  [_heroSectionSpacerView release];
  [_benefitBodyLabel release];
  [_benefitTitleLabel release];
  [_captionLabel release];
  [_subtitleLabel release];
  [_titleLabel release];
  [_badgeView release];
  [_iconImageView release];
  [_iconContainerView release];
  [_carouselCollectionView release];
  [_secondaryCarouselCollectionView release];
  [_pageControl release];
  [_recipes release];
  [_authenticationController release];
  [_stateController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Onboarding";
  self.view.backgroundColor = MRRBackgroundSurfaceColor();
  self.view.tintColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                      [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  self.view.accessibilityIdentifier = @"onboarding.view";

  [self buildViewHierarchy];
  [self updateLayoutMetricsIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  self.viewVisible = YES;
  [self resumeCarouselAutoscrollIfPossible];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  self.viewVisible = NO;
  [self pauseCarouselAutoscroll];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateLayoutMetricsIfNeeded];
  [self.view layoutIfNeeded];
  [self updateCarouselLayoutIfNeeded];
  [self ensureInitialCarouselPositionIfNeeded];
  [self updateScrollBehaviorIfNeeded];
}

#pragma mark - View Setup

- (NSArray<OnboardingRecipe *> *)loadRecipes {
  return [self.stateController onboardingRecipes];
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.backgroundColor = [UIColor clearColor];
  scrollView.accessibilityIdentifier = @"onboarding.scrollView";
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  contentView.backgroundColor = [UIColor clearColor];
  contentView.accessibilityIdentifier = @"onboarding.contentView";
  [scrollView addSubview:contentView];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 18.0;
  stackView.accessibilityIdentifier = @"onboarding.contentStackView";
  [contentView addSubview:stackView];
  self.contentStackView = stackView;

  UIView *heroCarouselContainerView = [[[UIView alloc] init] autorelease];
  heroCarouselContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  heroCarouselContainerView.backgroundColor = [UIColor clearColor];
  heroCarouselContainerView.clipsToBounds = NO;
  heroCarouselContainerView.accessibilityIdentifier = @"onboarding.heroCarouselContainerView";
  [stackView addArrangedSubview:heroCarouselContainerView];
  self.heroCarouselContainerView = heroCarouselContainerView;

  UIStackView *carouselRowsStackView = [[[UIStackView alloc] init] autorelease];
  carouselRowsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  carouselRowsStackView.axis = UILayoutConstraintAxisVertical;
  carouselRowsStackView.spacing = 10.0;
  carouselRowsStackView.distribution = UIStackViewDistributionFillEqually;
  carouselRowsStackView.alignment = UIStackViewAlignmentFill;
  carouselRowsStackView.accessibilityIdentifier = @"onboarding.heroCarouselRowsStackView";
  [heroCarouselContainerView addSubview:carouselRowsStackView];
  self.heroCarouselRowsStackView = carouselRowsStackView;

  UIView *primaryCarouselRowView = [[[UIView alloc] init] autorelease];
  primaryCarouselRowView.translatesAutoresizingMaskIntoConstraints = NO;
  primaryCarouselRowView.backgroundColor = [UIColor clearColor];
  primaryCarouselRowView.clipsToBounds = NO;
  primaryCarouselRowView.accessibilityIdentifier = @"onboarding.heroCarouselPrimaryRowView";
  [carouselRowsStackView addArrangedSubview:primaryCarouselRowView];

  UICollectionView *collectionView = [self buildCarouselCollectionViewWithAccessibilityIdentifier:@"onboarding.carouselCollectionView"];
  [primaryCarouselRowView addSubview:collectionView];
  self.carouselCollectionView = collectionView;
  self.primaryCarouselLeadingConstraint = [collectionView.leadingAnchor constraintEqualToAnchor:primaryCarouselRowView.leadingAnchor];
  self.primaryCarouselTrailingConstraint = [collectionView.trailingAnchor constraintEqualToAnchor:primaryCarouselRowView.trailingAnchor];
  [NSLayoutConstraint activateConstraints:@[
    [collectionView.topAnchor constraintEqualToAnchor:primaryCarouselRowView.topAnchor],
    self.primaryCarouselLeadingConstraint,
    self.primaryCarouselTrailingConstraint,
    [collectionView.bottomAnchor constraintEqualToAnchor:primaryCarouselRowView.bottomAnchor]
  ]];

  UIView *secondaryCarouselRowView = [[[UIView alloc] init] autorelease];
  secondaryCarouselRowView.translatesAutoresizingMaskIntoConstraints = NO;
  secondaryCarouselRowView.backgroundColor = [UIColor clearColor];
  secondaryCarouselRowView.clipsToBounds = NO;
  secondaryCarouselRowView.accessibilityIdentifier = @"onboarding.heroCarouselSecondaryRowView";
  [carouselRowsStackView addArrangedSubview:secondaryCarouselRowView];

  UICollectionView *secondaryCollectionView = [self buildCarouselCollectionViewWithAccessibilityIdentifier:@"onboarding.carouselCollectionView.secondary"];
  [secondaryCarouselRowView addSubview:secondaryCollectionView];
  self.secondaryCarouselCollectionView = secondaryCollectionView;
  self.secondaryCarouselLeadingConstraint = [secondaryCollectionView.leadingAnchor constraintEqualToAnchor:secondaryCarouselRowView.leadingAnchor];
  self.secondaryCarouselTrailingConstraint = [secondaryCollectionView.trailingAnchor constraintEqualToAnchor:secondaryCarouselRowView.trailingAnchor];
  [NSLayoutConstraint activateConstraints:@[
    [secondaryCollectionView.topAnchor constraintEqualToAnchor:secondaryCarouselRowView.topAnchor],
    self.secondaryCarouselLeadingConstraint,
    self.secondaryCarouselTrailingConstraint,
    [secondaryCollectionView.bottomAnchor constraintEqualToAnchor:secondaryCarouselRowView.bottomAnchor]
  ]];

  [NSLayoutConstraint activateConstraints:@[
    [carouselRowsStackView.topAnchor constraintEqualToAnchor:heroCarouselContainerView.topAnchor],
    [carouselRowsStackView.leadingAnchor constraintEqualToAnchor:heroCarouselContainerView.leadingAnchor],
    [carouselRowsStackView.trailingAnchor constraintEqualToAnchor:heroCarouselContainerView.trailingAnchor],
    [carouselRowsStackView.bottomAnchor constraintEqualToAnchor:heroCarouselContainerView.bottomAnchor]
  ]];

  UIView *iconWrapperView = [[[UIView alloc] init] autorelease];
  iconWrapperView.translatesAutoresizingMaskIntoConstraints = NO;
  iconWrapperView.accessibilityIdentifier = @"onboarding.logoWrapperView";
  self.iconWrapperHeightConstraint = [iconWrapperView.heightAnchor constraintEqualToConstant:100.0];
  [NSLayoutConstraint activateConstraints:@[ self.iconWrapperHeightConstraint ]];
  [stackView addArrangedSubview:iconWrapperView];
  self.iconWrapperView = iconWrapperView;

  UIView *iconContainerView = [[[UIView alloc] init] autorelease];
  iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  iconContainerView.accessibilityIdentifier = @"onboarding.logoContainerView";
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:iconContainerView];
  iconContainerView.clipsToBounds = YES;
  [iconWrapperView addSubview:iconContainerView];
  self.iconContainerView = iconContainerView;

  UIImageView *iconImageView = [[[UIImageView alloc] init] autorelease];
  iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
  iconImageView.contentMode = UIViewContentModeScaleAspectFill;
  iconImageView.clipsToBounds = YES;
  iconImageView.accessibilityIdentifier = @"onboarding.logoImageView";
  NSBundle *resourceBundle = [NSBundle bundleForClass:[OnboardingViewController class]];
  if (@available(iOS 8.0, *)) {
    iconImageView.image = [UIImage imageNamed:MRROnboardingAppIconImageName inBundle:resourceBundle compatibleWithTraitCollection:nil];
  } else {
    iconImageView.image = [UIImage imageNamed:MRROnboardingAppIconImageName];
  }
  [iconContainerView addSubview:iconImageView];
  self.iconImageView = iconImageView;

  self.iconContainerTopConstraint = [iconContainerView.topAnchor constraintEqualToAnchor:iconWrapperView.topAnchor constant:8.0];
  self.iconContainerWidthConstraint = [iconContainerView.widthAnchor constraintEqualToConstant:72.0];
  self.iconContainerHeightConstraint = [iconContainerView.heightAnchor constraintEqualToConstant:72.0];
  self.iconImageWidthConstraint = [iconImageView.widthAnchor constraintEqualToConstant:40.0];
  self.iconImageHeightConstraint = [iconImageView.heightAnchor constraintEqualToConstant:40.0];
  [NSLayoutConstraint activateConstraints:@[
    [iconContainerView.centerXAnchor constraintEqualToAnchor:iconWrapperView.centerXAnchor], self.iconContainerTopConstraint,
    self.iconContainerWidthConstraint, self.iconContainerHeightConstraint,

    [iconImageView.centerXAnchor constraintEqualToAnchor:iconContainerView.centerXAnchor],
    [iconImageView.centerYAnchor constraintEqualToAnchor:iconContainerView.centerYAnchor], self.iconImageWidthConstraint,
    self.iconImageHeightConstraint
  ]];

  UILabel *titleLabel = [self labelWithText:@"Culina" font:[UIFont boldSystemFontOfSize:54.0] color:MRRPrimaryTextColor()];
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.accessibilityIdentifier = @"onboarding.titleLabel";
  titleLabel.attributedText = [self titleAttributedTextWithFontSize:44.0 kerning:1.0];
  [stackView addArrangedSubview:titleLabel];
  self.titleLabel = titleLabel;

  UILabel *subtitleLabel = [self labelWithText:@"Discover. Cook. Savor."
                                          font:[UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium]
                                         color:MRRSecondaryTextColor()];
  subtitleLabel.textAlignment = NSTextAlignmentCenter;
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.accessibilityIdentifier = @"onboarding.subtitleLabel";
  [stackView addArrangedSubview:subtitleLabel];
  self.subtitleLabel = subtitleLabel;

  UIView *spacerView = [[[UIView alloc] init] autorelease];
  spacerView.translatesAutoresizingMaskIntoConstraints = NO;
  spacerView.accessibilityIdentifier = @"onboarding.spacerView";
  [spacerView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  [spacerView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  self.spacerHeightConstraint = [spacerView.heightAnchor constraintEqualToConstant:12.0];
  [NSLayoutConstraint activateConstraints:@[ self.spacerHeightConstraint ]];
  [stackView addArrangedSubview:spacerView];
  self.spacerView = spacerView;

  UILabel *captionLabel = [self labelWithText:@"SWIPE TO EXPLORE RECIPES"
                                         font:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                        color:MRRSecondaryTextColor()];
  captionLabel.textAlignment = NSTextAlignmentCenter;
  captionLabel.accessibilityIdentifier = @"onboarding.carouselCaptionLabel";
  captionLabel.attributedText = [self carouselCaptionAttributedTextWithFontSize:13.0 kerning:2.6];
  [stackView addArrangedSubview:captionLabel];
  self.captionLabel = captionLabel;

  UILabel *helperLabel = [self
      labelWithText:@"Auto-scroll keeps moving until you interact. Tap a card to inspect ingredients, steps, and the Start Cooking finish action."
               font:[UIFont systemFontOfSize:15.0]
              color:MRRSecondaryTextColor()];
  helperLabel.numberOfLines = 0;
  helperLabel.hidden = YES;
  helperLabel.accessibilityIdentifier = @"onboarding.carouselHelperLabel";
  [stackView addArrangedSubview:helperLabel];

  UIPageControl *pageControl = [[[UIPageControl alloc] init] autorelease];
  pageControl.translatesAutoresizingMaskIntoConstraints = NO;
  pageControl.numberOfPages = self.recipes.count;
  pageControl.currentPage = 0;
  pageControl.hidesForSinglePage = YES;
  pageControl.hidden = YES;
  pageControl.accessibilityIdentifier = @"onboarding.pageControl";
  pageControl.currentPageIndicatorTintColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  pageControl.pageIndicatorTintColor = [MRRSecondaryTextColor() colorWithAlphaComponent:0.24];
  [stackView addArrangedSubview:pageControl];
  self.pageControl = pageControl;

  UIView *heroSectionSpacerView = [[[UIView alloc] init] autorelease];
  heroSectionSpacerView.translatesAutoresizingMaskIntoConstraints = NO;
  heroSectionSpacerView.backgroundColor = [UIColor clearColor];
  heroSectionSpacerView.accessibilityIdentifier = @"onboarding.heroSectionSpacerView";
  [heroSectionSpacerView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  [heroSectionSpacerView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  self.heroSectionSpacerHeightConstraint = [heroSectionSpacerView.heightAnchor constraintEqualToConstant:16.0];
  [NSLayoutConstraint activateConstraints:@[ self.heroSectionSpacerHeightConstraint ]];
  [stackView addArrangedSubview:heroSectionSpacerView];
  self.heroSectionSpacerView = heroSectionSpacerView;

  UILabel *benefitTitleLabel = [self labelWithText:@"All recipes at your fingertips"
                                              font:[UIFont boldSystemFontOfSize:28.0]
                                             color:MRRPrimaryTextColor()];
  benefitTitleLabel.textAlignment = NSTextAlignmentCenter;
  benefitTitleLabel.numberOfLines = 2;
  [benefitTitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  [benefitTitleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  benefitTitleLabel.accessibilityIdentifier = @"onboarding.benefitTitleLabel";
  self.benefitTitleHeightConstraint = [benefitTitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:44.0];
  [self.benefitTitleHeightConstraint setActive:YES];
  [stackView addArrangedSubview:benefitTitleLabel];
  self.benefitTitleLabel = benefitTitleLabel;

  UILabel *benefitBodyLabel = [self labelWithText:@"Clear steps, simple ingredients, guaranteed delicious results."
                                             font:[UIFont systemFontOfSize:16.0]
                                            color:MRRSecondaryTextColor()];
  benefitBodyLabel.textAlignment = NSTextAlignmentCenter;
  benefitBodyLabel.numberOfLines = 0;
  [benefitBodyLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  [benefitBodyLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  benefitBodyLabel.accessibilityIdentifier = @"onboarding.benefitBodyLabel";
  self.benefitBodyHeightConstraint = [benefitBodyLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0];
  [self.benefitBodyHeightConstraint setActive:YES];
  [stackView addArrangedSubview:benefitBodyLabel];
  self.benefitBodyLabel = benefitBodyLabel;

  UIView *bodyActionSpacerView = [[[UIView alloc] init] autorelease];
  bodyActionSpacerView.translatesAutoresizingMaskIntoConstraints = NO;
  bodyActionSpacerView.backgroundColor = [UIColor clearColor];
  bodyActionSpacerView.accessibilityIdentifier = @"onboarding.bodyActionSpacerView";
  [bodyActionSpacerView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  [bodyActionSpacerView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  self.bodyActionSpacerHeightConstraint = [bodyActionSpacerView.heightAnchor constraintEqualToConstant:18.0];
  [NSLayoutConstraint activateConstraints:@[ self.bodyActionSpacerHeightConstraint ]];
  [stackView addArrangedSubview:bodyActionSpacerView];
  self.bodyActionSpacerView = bodyActionSpacerView;

  UIButton *emailButton = [self authButtonWithTitle:@"Sign up with email"
                                          iconStyle:MRROnboardingAuthButtonIconStyleEmail
                            accessibilityIdentifier:@"onboarding.emailButton"
                                             action:@selector(handleEmailSignupTapped:)];
  [stackView addArrangedSubview:emailButton];
  self.emailButton = emailButton;

  UIView *dividerView = [self authDividerView];
  dividerView.accessibilityIdentifier = @"onboarding.authDividerView";
  [stackView addArrangedSubview:dividerView];

  UIButton *googleButton = [self authButtonWithTitle:@"Continue with Google"
                                           iconStyle:MRROnboardingAuthButtonIconStyleGoogle
                             accessibilityIdentifier:@"onboarding.googleButton"
                                              action:@selector(handleGoogleSignupTapped:)];
  [stackView addArrangedSubview:googleButton];
  self.googleButton = googleButton;

  UIButton *appleButton = [self authButtonWithTitle:@"Continue with Apple"
                                          iconStyle:MRROnboardingAuthButtonIconStyleApple
                            accessibilityIdentifier:@"onboarding.appleButton"
                                             action:@selector(handleAppleContinueTapped:)];
  [stackView addArrangedSubview:appleButton];
  self.appleButton = appleButton;

  UIVisualEffectView *loadingOverlayView =
      [[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:MRROnboardingLoadingOverlayBlurStyle()]] autorelease];
  loadingOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingOverlayView.accessibilityIdentifier = @"onboarding.loadingOverlay";
  loadingOverlayView.hidden = YES;
  loadingOverlayView.alpha = 0.0;
  loadingOverlayView.contentView.backgroundColor = MRROnboardingLoadingOverlayTintColor();
  [self.view addSubview:loadingOverlayView];
  self.loadingOverlayView = loadingOverlayView;

  UIView *loadingContainerView = [[[UIView alloc] init] autorelease];
  loadingContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  loadingContainerView.accessibilityIdentifier = @"onboarding.loadingContainer";
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleOverlay toView:loadingContainerView];
  loadingContainerView.clipsToBounds = YES;
  [loadingOverlayView.contentView addSubview:loadingContainerView];

  UIActivityIndicatorView *loadingIndicator =
      [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:MRROnboardingLoadingIndicatorStyle()] autorelease];
  loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  loadingIndicator.accessibilityIdentifier = @"onboarding.loadingIndicator";
  loadingIndicator.color = MRRPrimaryTextColor();
  loadingIndicator.hidesWhenStopped = YES;
  [loadingContainerView addSubview:loadingIndicator];
  self.loadingIndicator = loadingIndicator;

  UIView *signinContainerView = [[[UIView alloc] init] autorelease];
  signinContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  signinContainerView.backgroundColor = [UIColor clearColor];
  signinContainerView.accessibilityIdentifier = @"onboarding.signinContainerView";
  [stackView addArrangedSubview:signinContainerView];

  UIStackView *signinRowView = [[[UIStackView alloc] init] autorelease];
  signinRowView.translatesAutoresizingMaskIntoConstraints = NO;
  signinRowView.axis = UILayoutConstraintAxisHorizontal;
  signinRowView.alignment = UIStackViewAlignmentCenter;
  signinRowView.spacing = 4.0;
  signinRowView.accessibilityIdentifier = @"onboarding.signinRowView";
  [signinContainerView addSubview:signinRowView];

  UILabel *signinPromptLabel = [self labelWithText:@"Already have an account?"
                                              font:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                             color:MRRSecondaryTextColor()];
  signinPromptLabel.translatesAutoresizingMaskIntoConstraints = NO;
  signinPromptLabel.accessibilityIdentifier = @"onboarding.signinPromptLabel";
  [signinRowView addArrangedSubview:signinPromptLabel];
  self.signinPromptLabel = signinPromptLabel;

  UIButton *signinLabel = [UIButton buttonWithType:UIButtonTypeSystem];
  signinLabel.translatesAutoresizingMaskIntoConstraints = NO;
  signinLabel.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  signinLabel.titleLabel.textAlignment = NSTextAlignmentCenter;
  [signinLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [signinLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [signinLabel setTitle:@"Sign in" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleInline toButton:signinLabel];
  signinLabel.accessibilityIdentifier = @"onboarding.signinLabel";
  [self configurePressFeedbackForButton:signinLabel];
  [signinLabel addTarget:self action:@selector(handleSigninTapped:) forControlEvents:UIControlEventTouchUpInside];
  [signinRowView addArrangedSubview:signinLabel];
  [NSLayoutConstraint activateConstraints:@[
    [signinRowView.topAnchor constraintEqualToAnchor:signinContainerView.topAnchor],
    [signinRowView.bottomAnchor constraintEqualToAnchor:signinContainerView.bottomAnchor],
    [signinRowView.centerXAnchor constraintEqualToAnchor:signinContainerView.centerXAnchor],
    [signinRowView.leadingAnchor constraintGreaterThanOrEqualToAnchor:signinContainerView.leadingAnchor],
    [signinRowView.trailingAnchor constraintLessThanOrEqualToAnchor:signinContainerView.trailingAnchor]
  ]];
  self.signinLabel = signinLabel;

  UILabel *footerLabel = [self labelWithText:@"Onboarding completes only after you tap Start Cooking inside a recipe detail card."
                                        font:[UIFont systemFontOfSize:15.0]
                                       color:MRRSecondaryTextColor()];
  footerLabel.numberOfLines = 0;
  footerLabel.hidden = YES;
  footerLabel.accessibilityIdentifier = @"onboarding.footerLabel";
  [stackView addArrangedSubview:footerLabel];

  self.iconWrapperView.hidden = YES;
  self.titleLabel.hidden = YES;
  self.subtitleLabel.hidden = YES;
  self.spacerView.hidden = YES;
  self.captionLabel.hidden = YES;

  self.stackTopConstraint = [stackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16.0];
  self.stackBottomConstraint = [stackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16.0];
  self.stackLeadingConstraint = [stackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:22.0];
  self.stackTrailingConstraint = [stackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-22.0];
  self.carouselHeightConstraint = [heroCarouselContainerView.heightAnchor constraintEqualToConstant:160.0];
  self.emailButtonHeightConstraint = [emailButton.heightAnchor constraintEqualToConstant:46.0];
  self.googleButtonHeightConstraint = [googleButton.heightAnchor constraintEqualToConstant:46.0];
  self.appleButtonHeightConstraint = [appleButton.heightAnchor constraintEqualToConstant:46.0];
  self.dividerHeightConstraint = [dividerView.heightAnchor constraintEqualToConstant:14.0];
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

    self.stackTopConstraint,
    self.stackLeadingConstraint,
    self.stackTrailingConstraint,
    self.stackBottomConstraint,

    self.carouselHeightConstraint,
    self.emailButtonHeightConstraint,
    self.googleButtonHeightConstraint,
    self.appleButtonHeightConstraint,
    self.dividerHeightConstraint,

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
}

- (UICollectionView *)buildCarouselCollectionViewWithAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.minimumLineSpacing = 18.0;
  layout.minimumInteritemSpacing = 1000.0;
  layout.estimatedItemSize = CGSizeZero;
  layout.sectionInset = UIEdgeInsetsZero;

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.showsHorizontalScrollIndicator = NO;
  collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
  collectionView.clipsToBounds = NO;
  collectionView.delaysContentTouches = NO;
  [collectionView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  [collectionView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  collectionView.dataSource = self;
  collectionView.delegate = self;
  collectionView.accessibilityIdentifier = accessibilityIdentifier;
  [collectionView registerClass:[OnboardingRecipeCarouselCell class] forCellWithReuseIdentifier:MRRRecipeCarouselCellReuseIdentifier];
  return collectionView;
}

- (NSArray<UICollectionView *> *)allCarouselCollectionViews {
  NSMutableArray<UICollectionView *> *collectionViews = [NSMutableArray arrayWithCapacity:2];
  if (self.carouselCollectionView != nil) {
    [collectionViews addObject:self.carouselCollectionView];
  }
  if (self.secondaryCarouselCollectionView != nil) {
    [collectionViews addObject:self.secondaryCarouselCollectionView];
  }
  return collectionViews;
}

- (UIView *)badgeViewWithText:(NSString *)text
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              labelIdentifier:(NSString *)labelIdentifier {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.accessibilityIdentifier = accessibilityIdentifier;
  containerView.backgroundColor = [UIColor clearColor];

  UIView *pillView = [[[UIView alloc] init] autorelease];
  pillView.translatesAutoresizingMaskIntoConstraints = NO;
  pillView.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".pillView"];
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleBadge toView:pillView];
  [containerView addSubview:pillView];

  UILabel *label = [self labelWithText:text
                                  font:[UIFont boldSystemFontOfSize:12.0]
                                 color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                     [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.accessibilityIdentifier = labelIdentifier;
  [pillView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [pillView.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
    [pillView.topAnchor constraintEqualToAnchor:containerView.topAnchor], [pillView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
    [pillView.leadingAnchor constraintGreaterThanOrEqualToAnchor:containerView.leadingAnchor],
    [pillView.trailingAnchor constraintLessThanOrEqualToAnchor:containerView.trailingAnchor],

    [label.topAnchor constraintEqualToAnchor:pillView.topAnchor constant:10.0],
    [label.leadingAnchor constraintEqualToAnchor:pillView.leadingAnchor constant:14.0],
    [label.trailingAnchor constraintEqualToAnchor:pillView.trailingAnchor constant:-14.0],
    [label.bottomAnchor constraintEqualToAnchor:pillView.bottomAnchor constant:-10.0]
  ]];

  return containerView;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.text = text;
  label.font = font;
  label.textColor = color;
  label.numberOfLines = 1;
  return label;
}

- (UIButton *)authButtonWithTitle:(NSString *)title
                        iconStyle:(MRROnboardingAuthButtonIconStyle)iconStyle
          accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           action:(SEL)action {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.accessibilityIdentifier = accessibilityIdentifier;
  [button setTitle:title forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleSecondary toButton:button];
  [self applyAuthButtonIconStyle:iconStyle toButton:button];
  [self configurePressFeedbackForButton:button];
  [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

  return button;
}

- (void)applyAuthButtonIconStyle:(MRROnboardingAuthButtonIconStyle)iconStyle toButton:(UIButton *)button {
  UIImage *iconImage = [self authButtonIconForStyle:iconStyle];
  if (iconImage == nil) {
    return;
  }

  button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *configuration = button.configuration;
    if (configuration == nil) {
      return;
    }

    configuration.image = iconImage;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 10.0;
    configuration.baseForegroundColor = MRRPrimaryTextColor();
    button.configuration = configuration;
    return;
  }

  button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
  [button setImage:iconImage forState:UIControlStateNormal];
  [button setImage:iconImage forState:UIControlStateHighlighted];
  if (iconStyle != MRROnboardingAuthButtonIconStyleGoogle) {
    button.tintColor = MRRPrimaryTextColor();
  }
  button.imageView.contentMode = UIViewContentModeScaleAspectFit;
  button.imageEdgeInsets = UIEdgeInsetsMake(0.0, -6.0, 0.0, 6.0);
  button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0);
}

- (UIImage *)authButtonIconForStyle:(MRROnboardingAuthButtonIconStyle)iconStyle {
  CGFloat symbolPointSize = 18.0;
  CGFloat fallbackDiameter = 18.0;

  switch (iconStyle) {
  case MRROnboardingAuthButtonIconStyleEmail:
    if (@available(iOS 13.0, *)) {
      return [self symbolButtonIconNamed:@"envelope.fill" pointSize:symbolPointSize tintColor:nil];
    }
    return [self monogramButtonIconWithText:@"@"
                            backgroundColor:[MRRPrimaryTextColor() colorWithAlphaComponent:0.10]
                            foregroundColor:MRRPrimaryTextColor()
                                   diameter:fallbackDiameter];
  case MRROnboardingAuthButtonIconStyleGoogle:
    if (@available(iOS 13.0, *)) {
      return [self symbolButtonIconNamed:@"g.circle.fill"
                               pointSize:symbolPointSize
                               tintColor:[UIColor colorWithRed:0.26 green:0.52 blue:0.96 alpha:1.0]];
    }
    return [self monogramButtonIconWithText:@"G"
                            backgroundColor:[UIColor colorWithRed:0.26 green:0.52 blue:0.96 alpha:1.0]
                            foregroundColor:[UIColor whiteColor]
                                   diameter:fallbackDiameter];
  case MRROnboardingAuthButtonIconStyleApple:
    if (@available(iOS 13.0, *)) {
      return [self symbolButtonIconNamed:@"apple.logo" pointSize:symbolPointSize tintColor:nil];
    }
    return [self monogramButtonIconWithText:@"A"
                            backgroundColor:[MRRPrimaryTextColor() colorWithAlphaComponent:0.12]
                            foregroundColor:MRRPrimaryTextColor()
                                   diameter:fallbackDiameter];
  }

  return nil;
}

- (UIImage *)symbolButtonIconNamed:(NSString *)systemName pointSize:(CGFloat)pointSize tintColor:(UIColor *)tintColor {
  if (@available(iOS 13.0, *)) {
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightSemibold];
    UIImage *symbolImage = [UIImage systemImageNamed:systemName withConfiguration:symbolConfiguration];
    if (tintColor != nil) {
      return [symbolImage imageWithTintColor:tintColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return [symbolImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  }

  return nil;
}

- (UIImage *)monogramButtonIconWithText:(NSString *)text
                        backgroundColor:(UIColor *)backgroundColor
                        foregroundColor:(UIColor *)foregroundColor
                               diameter:(CGFloat)diameter {
  CGSize imageSize = CGSizeMake(diameter, diameter);
  UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGRect imageRect = CGRectMake(0.0, 0.0, diameter, diameter);

  if (context != NULL) {
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillEllipseInRect(context, imageRect);
  }

  UIFont *font = [UIFont systemFontOfSize:diameter * 0.72 weight:UIFontWeightBold];
  CGSize textSize = [text sizeWithAttributes:@{
    NSFontAttributeName : font
  }];
  CGRect textRect = CGRectMake((diameter - textSize.width) / 2.0, (diameter - textSize.height) / 2.0, textSize.width, textSize.height);
  [text drawInRect:textRect
    withAttributes:@{
      NSFontAttributeName : font,
      NSForegroundColorAttributeName : foregroundColor
    }];

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (void)configurePressFeedbackForButton:(UIButton *)button {
  button.adjustsImageWhenHighlighted = NO;

  UIControlEvents touchDownEvents = UIControlEventTouchDown | UIControlEventTouchDragEnter;
  UIControlEvents touchUpEvents =
      UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit;

  [button addTarget:self action:@selector(handlePressableButtonTouchDown:) forControlEvents:touchDownEvents];
  [button addTarget:self action:@selector(handlePressableButtonTouchUp:) forControlEvents:touchUpEvents];
}

- (void)handlePressableButtonTouchDown:(UIButton *)sender {
  CGAffineTransform targetTransform = UIAccessibilityIsReduceMotionEnabled()
                                          ? CGAffineTransformIdentity
                                          : CGAffineTransformMakeScale(MRROnboardingButtonPressedScale, MRROnboardingButtonPressedScale);
  [UIView
      animateWithDuration:0.12
                    delay:0.0
                  options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
               animations:^{
                 sender.transform = targetTransform;
                 sender.alpha = MRROnboardingButtonPressedAlpha;
               }
               completion:nil];
}

- (void)handlePressableButtonTouchUp:(UIButton *)sender {
  [UIView
      animateWithDuration:0.16
                    delay:0.0
                  options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
               animations:^{
                 sender.transform = CGAffineTransformIdentity;
                 sender.alpha = 1.0;
               }
               completion:nil];
}

- (UIView *)authDividerView {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.accessibilityIdentifier = @"onboarding.authDividerView";

  UIView *leftLine = [[[UIView alloc] init] autorelease];
  leftLine.translatesAutoresizingMaskIntoConstraints = NO;
  leftLine.accessibilityIdentifier = @"onboarding.authDividerView.leftLine";
  leftLine.backgroundColor = [MRRSecondaryTextColor() colorWithAlphaComponent:0.24];
  [containerView addSubview:leftLine];

  UIView *rightLine = [[[UIView alloc] init] autorelease];
  rightLine.translatesAutoresizingMaskIntoConstraints = NO;
  rightLine.accessibilityIdentifier = @"onboarding.authDividerView.rightLine";
  rightLine.backgroundColor = [MRRSecondaryTextColor() colorWithAlphaComponent:0.24];
  [containerView addSubview:rightLine];

  UILabel *orLabel = [[[UILabel alloc] init] autorelease];
  orLabel.translatesAutoresizingMaskIntoConstraints = NO;
  orLabel.accessibilityIdentifier = @"onboarding.authDividerView.label";
  orLabel.text = @"or";
  orLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
  orLabel.textColor = MRRSecondaryTextColor();
  [containerView addSubview:orLabel];
  self.authDividerLabel = orLabel;

  [NSLayoutConstraint activateConstraints:@[
    [orLabel.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
    [orLabel.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],

    [leftLine.centerYAnchor constraintEqualToAnchor:orLabel.centerYAnchor],
    [leftLine.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [leftLine.trailingAnchor constraintEqualToAnchor:orLabel.leadingAnchor constant:-18.0], [leftLine.heightAnchor constraintEqualToConstant:1.0],

    [rightLine.centerYAnchor constraintEqualToAnchor:orLabel.centerYAnchor],
    [rightLine.leadingAnchor constraintEqualToAnchor:orLabel.trailingAnchor constant:18.0],
    [rightLine.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor], [rightLine.heightAnchor constraintEqualToConstant:1.0]
  ]];

  return containerView;
}

- (void)handleEmailSignupTapped:(id)sender {
  [self pushEmailAuthenticationViewControllerWithMode:MRREmailAuthenticationModeSignUp prefilledEmail:nil pendingLinkFlow:NO];
}

- (void)handleGoogleSignupTapped:(id)sender {
  [self beginLoadingForGoogleSignIn];

  [self.authenticationController
      signInWithGoogleFromPresentingViewController:self
                                        completion:^(__unused MRRAuthSession *_Nullable session, NSError *_Nullable error) {
                                          [self endLoadingForGoogleSignIn];

                                          if (error == nil) {
                                            [self notifyDelegateOfAuthentication];
                                            return;
                                          }

                                          if ([error.domain isEqualToString:MRRAuthenticationErrorDomain] &&
                                              error.code == MRRAuthenticationErrorCodeCancelled) {
                                            return;
                                          }

                                          if ([error.domain isEqualToString:MRRAuthenticationErrorDomain] &&
                                              error.code == MRRAuthenticationErrorCodeRequiresAccountLinking) {
                                            NSString *prefilledEmail = [self.authenticationController pendingLinkEmail];
                                            if (prefilledEmail.length == 0) {
                                              prefilledEmail = error.userInfo[MRRAuthPendingLinkEmailUserInfoKey];
                                            }

                                            [self pushEmailAuthenticationViewControllerWithMode:MRREmailAuthenticationModeSignIn
                                                                                 prefilledEmail:prefilledEmail
                                                                                pendingLinkFlow:YES];
                                            return;
                                          }

                                          [self presentAuthenticationAlertForError:error];
                                        }];
}

- (void)handleAppleContinueTapped:(id)sender {
  [self presentAppleSignInStubAlert];
}

- (void)handleSigninTapped:(id)sender {
  [self pushEmailAuthenticationViewControllerWithMode:MRREmailAuthenticationModeSignIn prefilledEmail:nil pendingLinkFlow:NO];
}

- (void)pushEmailAuthenticationViewControllerWithMode:(MRREmailAuthenticationMode)mode
                                       prefilledEmail:(NSString *)prefilledEmail
                                      pendingLinkFlow:(BOOL)pendingLinkFlow {
  MRREmailAuthenticationViewController *viewController =
      [[[MRREmailAuthenticationViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                                 mode:mode
                                                                       prefilledEmail:prefilledEmail
                                                                      pendingLinkFlow:pendingLinkFlow] autorelease];
  viewController.delegate = self;

  if (self.navigationController != nil) {
    [self.navigationController pushViewController:viewController animated:[self shouldAnimateModalTransitions]];
    return;
  }

  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:viewController] autorelease];
  navigationController.navigationBarHidden = NO;
  [self presentViewController:navigationController animated:[self shouldAnimateModalTransitions] completion:nil];
}

- (void)presentAuthenticationAlertForError:(NSError *)error {
  NSString *message = [MRRAuthErrorMapper messageForError:error];
  if (message.length == 0) {
    return;
  }

  [self presentAuthenticationAlertWithTitle:[MRRAuthErrorMapper titleForError:error]
                                    message:message
                    accessibilityIdentifier:@"onboarding.authErrorAlert"];
}

- (void)presentAuthenticationAlertWithTitle:(NSString *)title
                                    message:(NSString *)message
                    accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = accessibilityIdentifier;
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alertController animated:[self shouldAnimateModalTransitions] completion:nil];
}

- (void)presentAppleSignInStubAlert {
  BOOL appleAPIAvailable = NSClassFromString(@"ASAuthorizationAppleIDProvider") != nil;
  NSString *message = appleAPIAvailable
                          ? @"Struktur Sign in with Apple sudah disiapkan, tetapi aktivasi live masih membutuhkan Apple Developer Program dan "
                            @"konfigurasi capability resmi."
                          : @"AuthenticationServices belum tersedia di environment ini, jadi Sign in with Apple tetap ditahan sebagai stub.";

  [self presentAuthenticationAlertWithTitle:@"Apple Sign-In Planned" message:message accessibilityIdentifier:@"onboarding.appleStubAlert"];
}

- (void)notifyDelegateOfAuthentication {
  [self.delegate onboardingViewControllerDidAuthenticate:self];
}

- (void)setAuthButtonsEnabled:(BOOL)enabled {
  self.emailButton.enabled = enabled;
  self.googleButton.enabled = enabled;
  self.appleButton.enabled = enabled;
  self.signinLabel.enabled = enabled;
}

- (void)beginLoadingForGoogleSignIn {
  [self endLoadingForGoogleSignIn];
  [self setAuthButtonsEnabled:NO];
  self.loadingOverlayView.hidden = NO;
  self.loadingOverlayView.alpha = 1.0;
  [self.loadingIndicator startAnimating];
}

- (void)endLoadingForGoogleSignIn {
  [self setAuthButtonsEnabled:YES];
  [self.loadingIndicator stopAnimating];
  self.loadingOverlayView.alpha = 0.0;
  self.loadingOverlayView.hidden = YES;
}

#pragma mark - MRREmailAuthenticationViewControllerDelegate

- (void)emailAuthenticationViewControllerDidAuthenticate:(MRREmailAuthenticationViewController *)viewController {
  [self notifyDelegateOfAuthentication];
}

- (void)updateLayoutMetricsIfNeeded {
  if (self.scrollView == nil || self.contentStackView == nil) {
    return;
  }

  CGFloat viewportWidth = [self layoutViewportWidth];
  CGFloat viewportHeight = [self layoutViewportHeight];
  if (viewportWidth <= 0.0 || viewportHeight <= 0.0) {
    return;
  }

  CGSize viewportSize = CGSizeMake(viewportWidth, viewportHeight);
  CGFloat horizontalInset = 0.0;
  CGFloat contentWidth = 0.0;
  CGFloat stackSpacing = 0.0;
  CGFloat topInset = 0.0;
  CGFloat bottomInset = 0.0;
  CGFloat spacerHeight = 0.0;
  CGFloat iconContainerSize = 0.0;
  CGFloat iconTopInset = 0.0;
  CGFloat iconBottomInset = 0.0;
  CGFloat iconImageSize = 0.0;
  CGFloat titleFontSize = 0.0;
  CGFloat titleKerning = 0.0;
  CGFloat subtitleFontSize = 0.0;
  CGFloat captionFontSize = 0.0;
  CGFloat captionKerning = 0.0;
  CGFloat benefitTitleFontSize = 0.0;
  CGFloat benefitBodyFontSize = 0.0;
  CGFloat heroSectionGap = 0.0;
  CGFloat bodyActionGap = 0.0;
  CGFloat carouselRowGap = 0.0;
  CGFloat benefitTitleHeight = 0.0;
  CGFloat benefitBodyHeight = 0.0;
  CGFloat carouselHeight = 0.0;
  CGFloat buttonHeight = 0.0;
  CGFloat dividerHeight = 0.0;
  CGFloat signinFontSize = 0.0;
  CGFloat authDividerFontSize = 0.0;
  CGFloat buttonCornerRadius = 0.0;
  CGFloat buttonTitleFontSize = 0.0;
  CGFloat desiredLineSpacing = 0.0;

  horizontalInset = MRRLayoutScaledValue(22.0, viewportSize, MRRLayoutScaleAxisWidth);
  contentWidth = MAX(viewportWidth - (horizontalInset * 2.0), 0.0);
  stackSpacing = MRRLayoutScaledValue(9.0, viewportSize, MRRLayoutScaleAxisHeight);
  topInset = MRRLayoutScaledValue(10.0, viewportSize, MRRLayoutScaleAxisHeight);
  bottomInset = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisHeight);
  spacerHeight = MRRLayoutScaledValue(7.0, viewportSize, MRRLayoutScaleAxisHeight);
  iconContainerSize = MRRLayoutScaledValue(68.0, viewportSize, MRRLayoutScaleAxisMinDimension);
  iconTopInset = MRRLayoutScaledValue(6.0, viewportSize, MRRLayoutScaleAxisHeight);
  iconBottomInset = MRRLayoutScaledValue(13.0, viewportSize, MRRLayoutScaleAxisHeight);
  iconImageSize = MRRLayoutRoundedMetric(iconContainerSize);
  titleFontSize = MRRLayoutScaledValue(42.0, viewportSize, MRRLayoutScaleAxisWidth);
  titleKerning = MRRLayoutScaledValue(0.8, viewportSize, MRRLayoutScaleAxisWidth);
  subtitleFontSize = MRRLayoutScaledValue(16.0, viewportSize, MRRLayoutScaleAxisWidth);
  captionFontSize = MRRLayoutScaledValue(12.5, viewportSize, MRRLayoutScaleAxisWidth);
  captionKerning = MRRLayoutScaledValue(2.4, viewportSize, MRRLayoutScaleAxisWidth);
  benefitTitleFontSize = MRRLayoutScaledValue(28.0, viewportSize, MRRLayoutScaleAxisWidth);
  benefitBodyFontSize = MRRLayoutScaledValue(15.5, viewportSize, MRRLayoutScaleAxisWidth);
  heroSectionGap = MRRLayoutScaledValue(14.0, viewportSize, MRRLayoutScaleAxisHeight);
  bodyActionGap = MRRLayoutScaledValue(16.0, viewportSize, MRRLayoutScaleAxisHeight);
  carouselRowGap = MRRLayoutScaledValue(8.0, viewportSize, MRRLayoutScaleAxisHeight);
  benefitTitleHeight = MRRLayoutScaledValue(64.0, viewportSize, MRRLayoutScaleAxisHeight);
  benefitBodyHeight = MRRLayoutScaledValue(40.0, viewportSize, MRRLayoutScaleAxisHeight);
  carouselHeight = MRRLayoutScaledValue(344.0, viewportSize, MRRLayoutScaleAxisHeight);
  buttonHeight = MRRLayoutScaledValue(48.0, viewportSize, MRRLayoutScaleAxisHeight);
  dividerHeight = MRRLayoutScaledValue(14.0, viewportSize, MRRLayoutScaleAxisHeight);
  signinFontSize = MRRLayoutScaledValue(14.5, viewportSize, MRRLayoutScaleAxisWidth);
  authDividerFontSize = MRRLayoutScaledValue(13.5, viewportSize, MRRLayoutScaleAxisWidth);
  buttonCornerRadius = MRRLayoutScaledValue(16.5, viewportSize, MRRLayoutScaleAxisHeight);
  buttonTitleFontSize = MRRLayoutScaledValue(15.5, viewportSize, MRRLayoutScaleAxisWidth);
  desiredLineSpacing = MRRLayoutScaledValue(8.0, viewportSize, MRRLayoutScaleAxisWidth);

  self.contentStackView.spacing = stackSpacing;
  self.stackTopConstraint.constant = topInset;
  self.stackBottomConstraint.constant = -bottomInset;
  self.stackLeadingConstraint.constant = horizontalInset;
  self.stackTrailingConstraint.constant = -horizontalInset;
  self.spacerHeightConstraint.constant = spacerHeight;
  self.heroCarouselRowsStackView.spacing = MRRLayoutRoundedMetric(carouselRowGap);
  self.iconWrapperHeightConstraint.constant = MRRLayoutRoundedMetric(iconContainerSize + iconTopInset + iconBottomInset);
  self.heroSectionSpacerHeightConstraint.constant = heroSectionGap;
  self.bodyActionSpacerHeightConstraint.constant = bodyActionGap;
  self.iconContainerTopConstraint.constant = iconTopInset;
  self.iconContainerWidthConstraint.constant = iconContainerSize;
  self.iconContainerHeightConstraint.constant = iconContainerSize;
  self.iconImageWidthConstraint.constant = iconImageSize;
  self.iconImageHeightConstraint.constant = iconImageSize;
  self.iconContainerView.layer.cornerRadius = MRRLayoutRoundedMetric(iconContainerSize * 0.28);
  self.titleLabel.attributedText = [self titleAttributedTextWithFontSize:titleFontSize kerning:titleKerning];
  self.subtitleLabel.font = [UIFont systemFontOfSize:subtitleFontSize weight:UIFontWeightMedium];
  self.captionLabel.attributedText = [self carouselCaptionAttributedTextWithFontSize:captionFontSize kerning:captionKerning];
  self.iconWrapperView.hidden = YES;
  self.titleLabel.hidden = YES;
  self.subtitleLabel.hidden = YES;
  self.captionLabel.hidden = YES;
  self.spacerView.hidden = YES;
  self.benefitTitleLabel.hidden = NO;
  self.benefitBodyLabel.hidden = NO;
  self.benefitTitleLabel.font = [UIFont boldSystemFontOfSize:benefitTitleFontSize];
  self.benefitBodyLabel.font = [UIFont systemFontOfSize:benefitBodyFontSize];
  self.benefitTitleHeightConstraint.constant = benefitTitleHeight;
  self.benefitBodyHeightConstraint.constant = benefitBodyHeight;
  self.carouselHeightConstraint.constant = carouselHeight;
  self.emailButtonHeightConstraint.constant = buttonHeight;
  self.googleButtonHeightConstraint.constant = buttonHeight;
  self.appleButtonHeightConstraint.constant = buttonHeight;
  self.dividerHeightConstraint.constant = dividerHeight;
  self.signinPromptLabel.font = [UIFont systemFontOfSize:signinFontSize weight:UIFontWeightMedium];
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *signinConfiguration = self.signinLabel.configuration;
    if (signinConfiguration != nil) {
      signinConfiguration.attributedTitle =
          [[[NSAttributedString alloc] initWithString:@"Sign in"
                                           attributes:@{
                                             NSFontAttributeName : [UIFont boldSystemFontOfSize:signinFontSize],
                                             NSForegroundColorAttributeName : self.view.tintColor
                                           }] autorelease];
      self.signinLabel.configuration = signinConfiguration;
    }
  } else {
    self.signinLabel.titleLabel.font = [UIFont boldSystemFontOfSize:signinFontSize];
  }
  self.authDividerLabel.font = [UIFont systemFontOfSize:authDividerFontSize weight:UIFontWeightMedium];

  NSArray<UIButton *> *authButtons = @[ self.emailButton, self.googleButton, self.appleButton ];
  UIFont *buttonTitleFont = [UIFont systemFontOfSize:buttonTitleFontSize weight:UIFontWeightSemibold];
  for (UIButton *button in authButtons) {
    if (@available(iOS 15.0, *)) {
      UIButtonConfiguration *configuration = button.configuration;
      if (configuration != nil) {
        NSString *currentTitle = configuration.title ?: @"";
        configuration.attributedTitle = [[[NSAttributedString alloc] initWithString:currentTitle
                                                                         attributes:@{
                                                                           NSFontAttributeName : buttonTitleFont,
                                                                           NSForegroundColorAttributeName : MRRPrimaryTextColor()
                                                                         }] autorelease];
        button.configuration = configuration;
      }
    } else {
      button.layer.cornerRadius = buttonCornerRadius;
      button.titleLabel.font = buttonTitleFont;
    }
  }

  CGSize primaryCarouselItemSize = [self carouselItemSizeForAvailableWidth:contentWidth
                                                           availableHeight:MAX((carouselHeight - self.heroCarouselRowsStackView.spacing) / 2.0, 0.0)
                                                               lineSpacing:desiredLineSpacing];
  CGFloat carouselEdgeBleed = MRRLayoutRoundedMetric((primaryCarouselItemSize.width + desiredLineSpacing) * 0.6);
  self.primaryCarouselLeadingConstraint.constant = -carouselEdgeBleed;
  self.primaryCarouselTrailingConstraint.constant = carouselEdgeBleed;
  self.secondaryCarouselLeadingConstraint.constant = -carouselEdgeBleed;
  self.secondaryCarouselTrailingConstraint.constant = carouselEdgeBleed;
  self.carouselCollectionView.transform = CGAffineTransformIdentity;
  self.secondaryCarouselCollectionView.transform = CGAffineTransformIdentity;

  for (UICollectionView *collectionView in [self allCarouselCollectionViews]) {
    UICollectionViewFlowLayout *layout = [self carouselLayoutForCollectionView:collectionView];
    if (layout == nil) {
      continue;
    }

    if (fabs(layout.minimumLineSpacing - desiredLineSpacing) >= 0.5) {
      layout.minimumLineSpacing = desiredLineSpacing;
      [layout invalidateLayout];
    }

    CGSize initialCarouselItemSize = [self carouselItemSizeForAvailableWidth:contentWidth
                                                             availableHeight:MAX((carouselHeight - self.heroCarouselRowsStackView.spacing) / 2.0, 0.0)
                                                                 lineSpacing:desiredLineSpacing];
    CGFloat desiredInteritemSpacing = MAX((carouselHeight / 2.0) + MRRCarouselSingleRowSpacingPadding, 1000.0);
    if (initialCarouselItemSize.width > 0.0 && initialCarouselItemSize.height > 0.0 &&
        (fabs(layout.itemSize.width - initialCarouselItemSize.width) >= 0.5 ||
         fabs(layout.itemSize.height - initialCarouselItemSize.height) >= 0.5 ||
         fabs(layout.minimumInteritemSpacing - desiredInteritemSpacing) >= 0.5)) {
      layout.itemSize = initialCarouselItemSize;
      layout.minimumInteritemSpacing = desiredInteritemSpacing;
      [layout invalidateLayout];
    }
  }
}

- (void)updateScrollBehaviorIfNeeded {
  if (self.scrollView == nil || self.contentStackView == nil) {
    return;
  }

  CGFloat contentHeight = CGRectGetMaxY(self.contentStackView.frame) - self.stackBottomConstraint.constant;
  CGFloat viewportHeight = CGRectGetHeight(self.scrollView.bounds);
  BOOL allowsVerticalScrolling = contentHeight > (viewportHeight + 2.0);

  self.scrollView.alwaysBounceVertical = allowsVerticalScrolling;
  self.scrollView.scrollEnabled = allowsVerticalScrolling;
}

- (BOOL)isCarouselCollectionView:(UICollectionView *)collectionView {
  return collectionView != nil &&
         (collectionView == self.carouselCollectionView || collectionView == self.secondaryCarouselCollectionView);
}

- (BOOL)isPrimaryCarouselCollectionView:(UICollectionView *)collectionView {
  return collectionView != nil && collectionView == self.carouselCollectionView;
}

- (NSInteger)currentCarouselItemIndexForCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    return self.currentCarouselItemIndex;
  }

  return self.secondaryCurrentCarouselItemIndex;
}

- (void)setCurrentCarouselItemIndex:(NSInteger)itemIndex forCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    self.currentCarouselItemIndex = itemIndex;
    self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:itemIndex];
    return;
  }

  self.secondaryCurrentCarouselItemIndex = itemIndex;
}

- (NSInteger)defaultRecipeIndexForCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    return 0;
  }

  if (self.recipes.count < 2) {
    return 0;
  }

  return (NSInteger)(self.recipes.count / 2);
}

- (CGSize)lastPositionedCarouselBoundsSizeForCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    return self.lastPositionedCarouselBoundsSize;
  }

  return self.lastPositionedSecondaryCarouselBoundsSize;
}

- (void)setLastPositionedCarouselBoundsSize:(CGSize)size forCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    self.lastPositionedCarouselBoundsSize = size;
    return;
  }

  self.lastPositionedSecondaryCarouselBoundsSize = size;
}

- (void)synchronizeCarouselStateForCollectionView:(UICollectionView *)collectionView {
  if (![self isCarouselCollectionView:collectionView]) {
    return;
  }

  NSInteger nearestItemIndex = [self nearestCarouselItemIndexForOffsetX:collectionView.contentOffset.x inCollectionView:collectionView];
  [self setCurrentCarouselItemIndex:nearestItemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
}

- (CGFloat)carouselPhaseOffsetForCollectionView:(UICollectionView *)collectionView {
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    return 0.0;
  }

  UICollectionViewFlowLayout *layout = [self carouselLayoutForCollectionView:collectionView];
  if (layout == nil) {
    return 0.0;
  }

  return (layout.itemSize.width + layout.minimumLineSpacing) * 0.5;
}

- (CGFloat)visibleCarouselViewportWidthForCollectionView:(UICollectionView *)collectionView {
  if (collectionView == nil) {
    return 0.0;
  }

  CGRect collectionFrameInView = [collectionView convertRect:collectionView.bounds toView:self.view];
  CGRect viewportFrameInView = [self.scrollView convertRect:self.scrollView.bounds toView:self.view];
  CGRect visibleFrameInView = CGRectIntersection(collectionFrameInView, viewportFrameInView);
  if (CGRectIsNull(visibleFrameInView) || CGRectGetWidth(visibleFrameInView) <= 0.0) {
    return CGRectGetWidth(collectionView.bounds);
  }

  return CGRectGetWidth(visibleFrameInView);
}

- (CGFloat)visibleCarouselViewportMidXForCollectionView:(UICollectionView *)collectionView {
  if (collectionView == nil) {
    return 0.0;
  }

  CGRect collectionFrameInView = [collectionView convertRect:collectionView.bounds toView:self.view];
  CGRect viewportFrameInView = [self.scrollView convertRect:self.scrollView.bounds toView:self.view];
  CGRect visibleFrameInView = CGRectIntersection(collectionFrameInView, viewportFrameInView);
  if (CGRectIsNull(visibleFrameInView) || CGRectGetWidth(visibleFrameInView) <= 0.0) {
    return CGRectGetWidth(collectionView.bounds) / 2.0;
  }

  return CGRectGetMidX(visibleFrameInView) - CGRectGetMinX(collectionFrameInView);
}

- (CGFloat)loopSpanWidthForCollectionView:(UICollectionView *)collectionView {
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  if (recipeCount <= 0 || collectionView == nil) {
    return 0.0;
  }

  NSInteger firstMiddleIndex = [self middleCarouselItemIndexForRecipeIndex:0];
  NSInteger nextLoopIndex = firstMiddleIndex + recipeCount;
  if (firstMiddleIndex == NSNotFound || nextLoopIndex >= [self virtualCarouselItemCount]) {
    return 0.0;
  }

  CGFloat firstOffset = [self contentOffsetXForCarouselItemIndex:firstMiddleIndex inCollectionView:collectionView];
  CGFloat nextOffset = [self contentOffsetXForCarouselItemIndex:nextLoopIndex inCollectionView:collectionView];
  return MAX(nextOffset - firstOffset, 0.0);
}

- (CGFloat)middleLoopStartOffsetForCollectionView:(UICollectionView *)collectionView {
  NSInteger firstMiddleIndex = [self middleCarouselItemIndexForRecipeIndex:0];
  if (firstMiddleIndex == NSNotFound) {
    return 0.0;
  }

  return [self contentOffsetXForCarouselItemIndex:firstMiddleIndex inCollectionView:collectionView];
}

- (CGFloat)middleLoopEndOffsetForCollectionView:(UICollectionView *)collectionView {
  CGFloat middleLoopStartOffset = [self middleLoopStartOffsetForCollectionView:collectionView];
  CGFloat loopSpanWidth = [self loopSpanWidthForCollectionView:collectionView];
  if (loopSpanWidth <= 0.0) {
    return middleLoopStartOffset;
  }

  return middleLoopStartOffset + loopSpanWidth;
}

- (void)recenterContinuousCarouselOffsetIfNeededForCollectionView:(UICollectionView *)collectionView {
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  if (recipeCount == 0 || collectionView == nil) {
    return;
  }

  NSInteger nearestItemIndex = [self nearestCarouselItemIndexForOffsetX:collectionView.contentOffset.x inCollectionView:collectionView];
  NSInteger currentLoopIndex = nearestItemIndex / recipeCount;
  NSInteger middleLoopIndex = MRRCarouselLoopMultiplier / 2;
  NSInteger loopDelta = currentLoopIndex - middleLoopIndex;
  if (loopDelta == 0) {
    [self setCurrentCarouselItemIndex:nearestItemIndex forCollectionView:collectionView];
    if ([self isPrimaryCarouselCollectionView:collectionView]) {
      [self updatePageControl];
    }
    return;
  }

  CGFloat loopSpanWidth = [self loopSpanWidthForCollectionView:collectionView];
  if (loopSpanWidth <= 0.0) {
    return;
  }

  CGPoint adjustedOffset = collectionView.contentOffset;
  adjustedOffset.x -= (CGFloat)loopDelta * loopSpanWidth;
  [collectionView setContentOffset:adjustedOffset animated:NO];

  NSInteger recenteredItemIndex = nearestItemIndex - (loopDelta * recipeCount);
  [self setCurrentCarouselItemIndex:recenteredItemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
}

- (CGFloat)carouselAutoscrollPointsPerSecondForCollectionView:(UICollectionView *)collectionView {
  CGFloat width = [self layoutViewportWidth];
  if (width <= 0.0) {
    width = [self visibleCarouselViewportWidthForCollectionView:collectionView];
  }

  return MAX(width * 0.11, 18.0);
}

- (void)advanceCarouselCollectionView:(UICollectionView *)collectionView
                            direction:(CGFloat)direction
                            deltaTime:(CFTimeInterval)deltaTime {
  if (![self isCarouselCollectionView:collectionView] || deltaTime <= 0.0) {
    return;
  }

  CGFloat horizontalStep = [self carouselAutoscrollPointsPerSecondForCollectionView:collectionView] * deltaTime * direction;
  CGPoint nextOffset = collectionView.contentOffset;
  nextOffset.x += horizontalStep;

  CGFloat middleLoopStartOffset = [self middleLoopStartOffsetForCollectionView:collectionView];
  CGFloat middleLoopEndOffset = [self middleLoopEndOffsetForCollectionView:collectionView];
  CGFloat loopSpanWidth = middleLoopEndOffset - middleLoopStartOffset;

  if (loopSpanWidth > 0.0 && middleLoopEndOffset > middleLoopStartOffset) {
    while (nextOffset.x < middleLoopStartOffset) {
      nextOffset.x += loopSpanWidth;
    }

    while (nextOffset.x >= middleLoopEndOffset) {
      nextOffset.x -= loopSpanWidth;
    }
  }

  CGFloat maximumOffsetX = MAX(collectionView.contentSize.width - CGRectGetWidth(collectionView.bounds), 0.0);
  nextOffset.x = MIN(MAX(nextOffset.x, 0.0), maximumOffsetX);
  [collectionView setContentOffset:nextOffset animated:NO];
  [self synchronizeCarouselStateForCollectionView:collectionView];
}

- (CGFloat)layoutViewportHeight {
  CGFloat viewportHeight = CGRectGetHeight(self.scrollView.bounds);
  if (viewportHeight <= 0.0) {
    viewportHeight = CGRectGetHeight(self.view.safeAreaLayoutGuide.layoutFrame);
  }
  if (viewportHeight <= 0.0) {
    viewportHeight = CGRectGetHeight(self.view.bounds);
  }
  return viewportHeight;
}

- (CGFloat)layoutViewportWidth {
  CGFloat viewportWidth = CGRectGetWidth(self.scrollView.bounds);
  if (viewportWidth <= 0.0) {
    viewportWidth = CGRectGetWidth(self.view.safeAreaLayoutGuide.layoutFrame);
  }
  if (viewportWidth <= 0.0) {
    viewportWidth = CGRectGetWidth(self.view.bounds);
  }
  return viewportWidth;
}

- (NSAttributedString *)titleAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning {
  return [[[NSAttributedString alloc] initWithString:@"Culina"
                                          attributes:@{
                                            NSKernAttributeName : @(kerning),
                                            NSForegroundColorAttributeName : MRRPrimaryTextColor(),
                                            NSFontAttributeName : [UIFont boldSystemFontOfSize:fontSize]
                                          }] autorelease];
}

- (NSAttributedString *)carouselCaptionAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning {
  return [[[NSAttributedString alloc] initWithString:@"SWIPE TO EXPLORE RECIPES"
                                          attributes:@{
                                            NSKernAttributeName : @(kerning),
                                            NSForegroundColorAttributeName : MRRSecondaryTextColor(),
                                            NSFontAttributeName : [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium]
                                          }] autorelease];
}

#pragma mark - Carousel

- (UICollectionViewFlowLayout *)carouselLayout {
  return [self carouselLayoutForCollectionView:self.carouselCollectionView];
}

- (UICollectionViewFlowLayout *)carouselLayoutForCollectionView:(UICollectionView *)collectionView {
  if (collectionView == nil || ![collectionView.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
    return nil;
  }

  return (UICollectionViewFlowLayout *)collectionView.collectionViewLayout;
}

- (NSInteger)virtualCarouselItemCount {
  if (self.recipes.count == 0) {
    return 0;
  }

  return self.recipes.count * MRRCarouselLoopMultiplier;
}

- (NSInteger)recipeIndexForCarouselItemIndex:(NSInteger)itemIndex {
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  if (recipeCount == 0) {
    return NSNotFound;
  }

  NSInteger normalizedIndex = itemIndex % recipeCount;
  if (normalizedIndex < 0) {
    normalizedIndex += recipeCount;
  }

  return normalizedIndex;
}

- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex {
  if (recipeIndex < 0 || recipeIndex >= (NSInteger)self.recipes.count) {
    return NSNotFound;
  }

  return ((MRRCarouselLoopMultiplier / 2) * self.recipes.count) + recipeIndex;
}

- (NSInteger)carouselItemIndexForRecipeIndex:(NSInteger)recipeIndex nearCarouselItemIndex:(NSInteger)referenceIndex {
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (recipeIndex < 0 || recipeIndex >= recipeCount || totalItemCount == 0) {
    return NSNotFound;
  }

  NSInteger clampedReferenceIndex = MIN(MAX(referenceIndex, 0), totalItemCount - 1);
  NSInteger baseLoopIndex = clampedReferenceIndex / recipeCount;
  NSInteger bestItemIndex = NSNotFound;
  NSInteger bestDistance = NSIntegerMax;

  for (NSInteger loopOffset = -1; loopOffset <= 1; loopOffset++) {
    NSInteger candidateLoopIndex = baseLoopIndex + loopOffset;
    if (candidateLoopIndex < 0 || candidateLoopIndex >= MRRCarouselLoopMultiplier) {
      continue;
    }

    NSInteger candidateItemIndex = (candidateLoopIndex * recipeCount) + recipeIndex;
    NSInteger distance = ABS(candidateItemIndex - clampedReferenceIndex);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestItemIndex = candidateItemIndex;
    }
  }

  if (bestItemIndex == NSNotFound) {
    return [self middleCarouselItemIndexForRecipeIndex:recipeIndex];
  }

  return bestItemIndex;
}

- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX {
  return [self nearestCarouselItemIndexForOffsetX:offsetX inCollectionView:self.carouselCollectionView];
}

- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX inCollectionView:(UICollectionView *)collectionView {
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (totalItemCount == 0 || collectionView == nil) {
    return 0;
  }

  [collectionView layoutIfNeeded];
  CGFloat visibleMidX = offsetX + [self visibleCarouselViewportMidXForCollectionView:collectionView] -
                        [self carouselPhaseOffsetForCollectionView:collectionView];
  NSInteger nearestIndex = 0;
  CGFloat nearestDistance = CGFLOAT_MAX;

  for (NSInteger itemIndex = 0; itemIndex < totalItemCount; itemIndex++) {
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
    UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (attributes == nil) {
      continue;
    }

    CGFloat distance = fabs(attributes.center.x - visibleMidX);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = itemIndex;
    }
  }

  return nearestIndex;
}

- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex {
  return [self contentOffsetXForCarouselItemIndex:itemIndex inCollectionView:self.carouselCollectionView];
}

- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex inCollectionView:(UICollectionView *)collectionView {
  if (itemIndex < 0 || itemIndex >= [self virtualCarouselItemCount]) {
    return 0.0;
  }

  if (collectionView == nil) {
    return 0.0;
  }

  [collectionView layoutIfNeeded];
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
  UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
  if (attributes == nil) {
    return 0.0;
  }

  CGFloat centeredOffsetX = attributes.center.x - [self visibleCarouselViewportMidXForCollectionView:collectionView] +
                            [self carouselPhaseOffsetForCollectionView:collectionView];
  return MAX(centeredOffsetX, 0.0);
}

- (void)updateCarouselLayoutIfNeeded {
  for (UICollectionView *collectionView in [self allCarouselCollectionViews]) {
    [self updateCarouselLayoutIfNeededForCollectionView:collectionView];
  }
}

- (void)updateCarouselLayoutIfNeededForCollectionView:(UICollectionView *)collectionView {
  UICollectionViewFlowLayout *layout = [self carouselLayoutForCollectionView:collectionView];
  CGFloat availableWidth = CGRectGetWidth(self.heroCarouselContainerView.bounds);
  if (availableWidth <= 0.0 && collectionView.superview != nil) {
    availableWidth = CGRectGetWidth(collectionView.superview.bounds);
  }
  CGFloat availableHeight = CGRectGetHeight(collectionView.superview.bounds);
  if (availableHeight <= 0.0) {
    availableHeight = CGRectGetHeight(collectionView.bounds);
  }
  if (layout == nil || availableWidth <= 0.0 || availableHeight <= 0.0) {
    return;
  }

  CGSize desiredItemSize = [self carouselItemSizeForAvailableWidth:availableWidth
                                                   availableHeight:availableHeight
                                                       lineSpacing:layout.minimumLineSpacing];
  CGFloat desiredWidth = desiredItemSize.width;
  CGFloat desiredHeight = desiredItemSize.height;
  CGFloat desiredInteritemSpacing = MAX(availableHeight + MRRCarouselSingleRowSpacingPadding, 1000.0);

  if (fabs(layout.itemSize.width - desiredWidth) < 0.5 && fabs(layout.itemSize.height - desiredHeight) < 0.5 &&
      fabs(layout.minimumInteritemSpacing - desiredInteritemSpacing) < 0.5) {
    return;
  }

  layout.itemSize = CGSizeMake(desiredWidth, desiredHeight);
  layout.minimumInteritemSpacing = desiredInteritemSpacing;
  [layout invalidateLayout];
  [collectionView layoutIfNeeded];

  NSInteger currentItemIndex = [self currentCarouselItemIndexForCollectionView:collectionView];
  if (currentItemIndex < 0 || currentItemIndex >= [self virtualCarouselItemCount]) {
    currentItemIndex = [self middleCarouselItemIndexForRecipeIndex:[self defaultRecipeIndexForCollectionView:collectionView]];
  }
  [self scrollCollectionView:collectionView toCarouselItemAtIndex:currentItemIndex animated:NO];
}

- (CGSize)carouselItemSizeForAvailableWidth:(CGFloat)availableWidth availableHeight:(CGFloat)availableHeight lineSpacing:(CGFloat)lineSpacing {
  if (availableWidth <= 0.0 || availableHeight <= 0.0) {
    return CGSizeZero;
  }

  CGFloat desiredWidth = 0.0;
  CGFloat desiredHeight = 0.0;

  CGFloat layoutViewportHeight = [self layoutViewportHeight];
  if (layoutViewportHeight <= 0.0) {
    layoutViewportHeight = availableHeight;
  }

  CGSize carouselViewportSize = CGSizeMake(availableWidth, layoutViewportHeight);
  desiredHeight = MRRLayoutScaledValue(300, carouselViewportSize, MRRLayoutScaleAxisHeight);
  desiredHeight = MIN(desiredHeight, MAX(availableHeight - 6.0, 0.0));
  CGFloat baseWidth = MRRLayoutScaledValue(96.0, carouselViewportSize, MRRLayoutScaleAxisWidth);
  CGFloat visibleColumnCount = 3.2;
  CGFloat visibleSpacingSlotCount = MAX(visibleColumnCount - 1.0, 0.0);
  CGFloat targetWidth = MAX((availableWidth - (lineSpacing * visibleSpacingSlotCount)) / visibleColumnCount, 0.0);
  desiredWidth = MAX(baseWidth, desiredHeight * 0.60);
  desiredWidth = MAX(desiredWidth, targetWidth);

  return CGSizeMake(desiredWidth, desiredHeight);
}

- (void)ensureInitialCarouselPositionIfNeeded {
  NSArray<UICollectionView *> *collectionViews = [self allCarouselCollectionViews];
  if (self.recipes.count == 0 || collectionViews.count == 0) {
    return;
  }

  BOOL shouldApplyInitialPosition = !self.hasAppliedInitialCarouselPosition;
  for (UICollectionView *collectionView in collectionViews) {
    CGSize carouselBoundsSize = collectionView.bounds.size;
    if (carouselBoundsSize.width <= 0.0 || carouselBoundsSize.height <= 0.0) {
      return;
    }

    CGSize lastBoundsSize = [self lastPositionedCarouselBoundsSizeForCollectionView:collectionView];
    BOOL boundsChangedSinceLastPositioning = fabs(lastBoundsSize.width - carouselBoundsSize.width) >= 0.5 ||
                                             fabs(lastBoundsSize.height - carouselBoundsSize.height) >= 0.5;
    shouldApplyInitialPosition = shouldApplyInitialPosition || boundsChangedSinceLastPositioning;
  }

  if (!shouldApplyInitialPosition) {
    return;
  }

  for (UICollectionView *collectionView in collectionViews) {
    NSInteger initialItemIndex = [self currentCarouselItemIndexForCollectionView:collectionView];
    if (initialItemIndex < 0 || initialItemIndex >= [self virtualCarouselItemCount]) {
      initialItemIndex = [self middleCarouselItemIndexForRecipeIndex:[self defaultRecipeIndexForCollectionView:collectionView]];
      if (initialItemIndex == NSNotFound) {
        continue;
      }
    }

    [self scrollCollectionView:collectionView toCarouselItemAtIndex:initialItemIndex animated:NO];
    [self setLastPositionedCarouselBoundsSize:collectionView.bounds.size forCollectionView:collectionView];
  }

  self.hasAppliedInitialCarouselPosition = YES;
  [self resumeCarouselAutoscrollIfPossible];
}

- (void)scrollCollectionView:(UICollectionView *)collectionView toCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated {
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (collectionView == nil || itemIndex < 0 || itemIndex >= totalItemCount) {
    return;
  }

  [collectionView setContentOffset:CGPointMake([self contentOffsetXForCarouselItemIndex:itemIndex inCollectionView:collectionView],
                                               collectionView.contentOffset.y)
                           animated:animated];
  [self setCurrentCarouselItemIndex:itemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
}

- (void)scrollToCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated {
  [self scrollCollectionView:self.carouselCollectionView toCarouselItemAtIndex:itemIndex animated:animated];
}

- (void)scrollToRecipeAtIndex:(NSInteger)index animated:(BOOL)animated {
  if (index < 0 || index >= (NSInteger)self.recipes.count) {
    return;
  }

  NSInteger targetItemIndex = [self carouselItemIndexForRecipeIndex:index nearCarouselItemIndex:self.currentCarouselItemIndex];
  if (targetItemIndex == NSNotFound) {
    targetItemIndex = [self middleCarouselItemIndexForRecipeIndex:index];
  }

  [self scrollToCarouselItemAtIndex:targetItemIndex animated:animated];
}

- (void)updatePageControl {
  self.pageControl.currentPage = self.currentRecipeIndex;
}

- (void)recenterCarouselIfNeeded {
  [self recenterCarouselIfNeededForCollectionView:self.carouselCollectionView];
}

- (void)recenterCarouselIfNeededForCollectionView:(UICollectionView *)collectionView {
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  if (recipeCount == 0 || collectionView == nil) {
    return;
  }

  NSInteger currentItemIndex = [self currentCarouselItemIndexForCollectionView:collectionView];
  NSInteger currentLoopIndex = currentItemIndex / recipeCount;
  NSInteger middleLoopIndex = MRRCarouselLoopMultiplier / 2;
  if (currentLoopIndex == middleLoopIndex) {
    return;
  }

  NSInteger recipeIndex = [self recipeIndexForCarouselItemIndex:currentItemIndex];
  NSInteger recenteredItemIndex = [self middleCarouselItemIndexForRecipeIndex:recipeIndex];
  if (recenteredItemIndex == NSNotFound) {
    return;
  }

  [self setCurrentCarouselItemIndex:recenteredItemIndex forCollectionView:collectionView];
  [collectionView
      setContentOffset:CGPointMake([self contentOffsetXForCarouselItemIndex:recenteredItemIndex inCollectionView:collectionView],
                                   collectionView.contentOffset.y)
              animated:NO];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
}

- (void)presentRecipeDetailForRecipeAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)self.recipes.count) {
    return;
  }

  [self scrollToRecipeAtIndex:index animated:NO];
  self.detailPresented = YES;
  [self pauseCarouselAutoscroll];

  OnboardingRecipeDetailViewController *detailViewController =
      [[[OnboardingRecipeDetailViewController alloc] initWithRecipe:self.recipes[index]] autorelease];
  detailViewController.delegate = self;

  if (@available(iOS 15.0, *)) {
    UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:detailViewController] autorelease];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    navigationController.presentationController.delegate = self;
    if (navigationController.sheetPresentationController != nil) {
      navigationController.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:navigationController animated:[self shouldAnimateModalTransitions] completion:nil];
    return;
  }

  [self presentViewController:detailViewController animated:[self shouldAnimateModalTransitions] completion:nil];
}

- (void)pauseCarouselAutoscroll {
  [self.carouselDisplayLink invalidate];
  self.carouselDisplayLink = nil;
  self.lastCarouselDisplayTimestamp = 0.0;
}

- (void)resumeCarouselAutoscrollIfPossible {
  if (NSClassFromString(@"XCTestCase") != nil) {
    return;
  }

  if (!self.isViewVisible || !self.hasAppliedInitialCarouselPosition || self.carouselDisplayLink != nil || self.recipes.count < 2) {
    return;
  }

  CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleCarouselDisplayLink:)];
  if (@available(iOS 15.0, *)) {
    displayLink.preferredFrameRateRange = CAFrameRateRangeMake(50.0, 120.0, 60.0);
  } else {
    displayLink.preferredFramesPerSecond = 60;
  }
  [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  self.carouselDisplayLink = displayLink;
  self.lastCarouselDisplayTimestamp = 0.0;
}

- (void)handleCarouselDisplayLink:(CADisplayLink *)displayLink {
  if (self.recipes.count < 2) {
    self.lastCarouselDisplayTimestamp = displayLink.timestamp;
    return;
  }

  if (self.lastCarouselDisplayTimestamp <= 0.0) {
    self.lastCarouselDisplayTimestamp = displayLink.timestamp;
    return;
  }

  CFTimeInterval deltaTime = MIN(displayLink.timestamp - self.lastCarouselDisplayTimestamp, 1.0 / 24.0);
  self.lastCarouselDisplayTimestamp = displayLink.timestamp;
  [self advanceCarouselCollectionView:self.carouselCollectionView direction:1.0 deltaTime:deltaTime];
  [self advanceCarouselCollectionView:self.secondaryCarouselCollectionView direction:-1.0 deltaTime:deltaTime];
}

- (void)handleCarouselTimer:(NSTimer *)timer {
  if (self.recipes.count < 2 || self.isDetailPresented) {
    return;
  }

  CFTimeInterval syntheticFrameDuration = 1.0 / 60.0;
  [self advanceCarouselCollectionView:self.carouselCollectionView direction:1.0 deltaTime:syntheticFrameDuration];
  [self advanceCarouselCollectionView:self.secondaryCarouselCollectionView direction:-1.0 deltaTime:syntheticFrameDuration];
}

- (BOOL)shouldAnimateModalTransitions {
  return NSClassFromString(@"XCTestCase") == nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return [self virtualCarouselItemCount];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  OnboardingRecipeCarouselCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:MRRRecipeCarouselCellReuseIdentifier
                                                                                 forIndexPath:indexPath];
  NSInteger recipeIndex = [self recipeIndexForCarouselItemIndex:indexPath.item];
  if (recipeIndex == NSNotFound) {
    return cell;
  }

  cell.showsTextOverlay = NO;
  [cell configureWithRecipe:self.recipes[recipeIndex]];
  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  [self presentRecipeDetailForRecipeAtIndex:[self recipeIndexForCarouselItemIndex:indexPath.item]];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  if (![self isCarouselCollectionView:(UICollectionView *)scrollView]) {
    return;
  }

  [self pauseCarouselAutoscroll];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
  UICollectionView *collectionView = (UICollectionView *)scrollView;
  if (![self isCarouselCollectionView:collectionView]) {
    return;
  }

  NSInteger targetItemIndex = [self nearestCarouselItemIndexForOffsetX:targetContentOffset->x inCollectionView:collectionView];
  targetContentOffset->x = [self contentOffsetXForCarouselItemIndex:targetItemIndex inCollectionView:collectionView];
  [self setCurrentCarouselItemIndex:targetItemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
  UICollectionView *collectionView = (UICollectionView *)scrollView;
  if (![self isCarouselCollectionView:collectionView]) {
    return;
  }

  if (!decelerate) {
    NSInteger nearestItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x inCollectionView:collectionView];
    [self setCurrentCarouselItemIndex:nearestItemIndex forCollectionView:collectionView];
    if ([self isPrimaryCarouselCollectionView:collectionView]) {
      [self updatePageControl];
    }
    [self recenterContinuousCarouselOffsetIfNeededForCollectionView:collectionView];
    [self resumeCarouselAutoscrollIfPossible];
  }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  UICollectionView *collectionView = (UICollectionView *)scrollView;
  if (![self isCarouselCollectionView:collectionView]) {
    return;
  }

  NSInteger nearestItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x inCollectionView:collectionView];
  [self setCurrentCarouselItemIndex:nearestItemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
  [self recenterContinuousCarouselOffsetIfNeededForCollectionView:collectionView];
  [self resumeCarouselAutoscrollIfPossible];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
  UICollectionView *collectionView = (UICollectionView *)scrollView;
  if (![self isCarouselCollectionView:collectionView]) {
    return;
  }

  NSInteger nearestItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x inCollectionView:collectionView];
  [self setCurrentCarouselItemIndex:nearestItemIndex forCollectionView:collectionView];
  if ([self isPrimaryCarouselCollectionView:collectionView]) {
    [self updatePageControl];
  }
  [self recenterContinuousCarouselOffsetIfNeededForCollectionView:collectionView];
}

#pragma mark - OnboardingRecipeDetailViewControllerDelegate

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController {
  self.detailPresented = NO;
  [self dismissViewControllerAnimated:[self shouldAnimateModalTransitions]
                           completion:^{
                             self.viewVisible = YES;
                             [self resumeCarouselAutoscrollIfPossible];
                           }];
}

- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController {
  self.detailPresented = NO;
  [self.stateController markOnboardingCompleted];
  [self dismissViewControllerAnimated:[self shouldAnimateModalTransitions]
                           completion:^{
                             self.viewVisible = YES;
                             [self resumeCarouselAutoscrollIfPossible];
                           }];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
  if (!self.isDetailPresented) {
    return;
  }

  self.detailPresented = NO;
  self.viewVisible = YES;
  [self resumeCarouselAutoscrollIfPossible];
}

@end
