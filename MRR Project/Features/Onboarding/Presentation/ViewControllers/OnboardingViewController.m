#import "OnboardingViewController.h"

#include <math.h>

#import <AuthenticationServices/AuthenticationServices.h>

#import "../../../Authentication/MRRAuthenticationController.h"
#import "../../../Authentication/MRRAuthErrorMapper.h"
#import "MRREmailAuthenticationViewController.h"
#import "../../../Authentication/MRRFirebaseAuthenticationController.h"
#import "../../../../Layout/MRRLayoutScaling.h"
#import "../../Data/OnboardingStateController.h"
#import "../Views/OnboardingRecipeCarouselCell.h"
#import "OnboardingRecipeDetailViewController.h"

static NSString *const MRRRecipeCarouselCellReuseIdentifier = @"MRRRecipeCarouselCell";
static NSInteger const MRRCarouselLoopMultiplier = 5;
static NSString *const MRROnboardingAppIconImageName = @"OnboardingAppIcon";
static NSInteger const MRROnboardingAuthButtonIconTag = 101;
static NSInteger const MRROnboardingAuthButtonTitleTag = 102;
static NSInteger const MRROnboardingAuthButtonContentWrapperTag = 103;
static CGFloat const MRRCarouselSingleRowSpacingPadding = 32.0;
static CGFloat const MRROnboardingButtonPressedScale = 0.97;
static CGFloat const MRROnboardingButtonPressedAlpha = 0.88;

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

static UIColor *MRRCardSurfaceColor(void) {
  return MRRNamedColor(@"CardSurfaceColor", [UIColor colorWithWhite:0.99 alpha:1.0], [UIColor colorWithWhite:0.16 alpha:1.0]);
}

static UIColor *MRRPrimaryTextColor(void) {
  return MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRSecondaryTextColor(void) {
  return MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.42 alpha:1.0], [UIColor colorWithWhite:0.63 alpha:1.0]);
}

static UIColor *MRROnboardingLoadingOverlayTintColor(void) { return [UIColor colorWithWhite:0.0 alpha:0.12]; }

static UIColor *MRROnboardingLoadingPanelColor(void) { return [MRRCardSurfaceColor() colorWithAlphaComponent:0.9]; }

@interface OnboardingViewController () <UICollectionViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout,
                                        UIScrollViewDelegate,
                                        OnboardingRecipeDetailViewControllerDelegate,
                                        MRREmailAuthenticationViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *stateController;
@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, copy) NSArray<OnboardingRecipe *> *recipes;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UICollectionView *carouselCollectionView;
@property(nonatomic, retain) UIPageControl *pageControl;
@property(nonatomic, retain) NSTimer *carouselTimer;
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
@property(nonatomic, retain) NSLayoutConstraint *iconWrapperHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerTopConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconContainerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconImageWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint *iconImageHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *carouselHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *emailButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *googleButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *appleButtonHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *dividerHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *benefitTitleHeightConstraint;
@property(nonatomic, retain) NSLayoutConstraint *benefitBodyHeightConstraint;
@property(nonatomic, assign) NSInteger currentRecipeIndex;
@property(nonatomic, assign) NSInteger currentCarouselItemIndex;
@property(nonatomic, assign) BOOL hasAppliedInitialCarouselPosition;
@property(nonatomic, assign) CGSize lastPositionedCarouselBoundsSize;
@property(nonatomic, assign, getter=isDetailPresented) BOOL detailPresented;
@property(nonatomic, assign, getter=isViewVisible) BOOL viewVisible;

- (NSArray<OnboardingRecipe *> *)loadRecipes;
- (void)buildViewHierarchy;
- (UIView *)badgeViewWithText:(NSString *)text
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              labelIdentifier:(NSString *)labelIdentifier;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UIButton *)authButtonWithTitle:(NSString *)title
                         iconText:(nullable NSString *)iconText
                      filledStyle:(BOOL)filledStyle
          accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           action:(SEL)action;
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
- (CGFloat)layoutViewportHeight;
- (CGFloat)layoutViewportWidth;
- (NSAttributedString *)titleAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning;
- (NSAttributedString *)carouselCaptionAttributedTextWithFontSize:(CGFloat)fontSize kerning:(CGFloat)kerning;
- (UICollectionViewFlowLayout *)carouselLayout;
- (void)updateCarouselLayoutIfNeeded;
- (CGSize)carouselItemSizeForAvailableWidth:(CGFloat)availableWidth availableHeight:(CGFloat)availableHeight lineSpacing:(CGFloat)lineSpacing;
- (NSInteger)virtualCarouselItemCount;
- (NSInteger)recipeIndexForCarouselItemIndex:(NSInteger)itemIndex;
- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex;
- (NSInteger)carouselItemIndexForRecipeIndex:(NSInteger)recipeIndex nearCarouselItemIndex:(NSInteger)referenceIndex;
- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex;
- (void)ensureInitialCarouselPositionIfNeeded;
- (void)scrollToCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated;
- (void)scrollToRecipeAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)updatePageControl;
- (void)recenterCarouselIfNeeded;
- (void)presentRecipeDetailForRecipeAtIndex:(NSInteger)index;
- (void)pauseCarouselAutoscroll;
- (void)resumeCarouselAutoscrollIfPossible;
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
  _carouselCollectionView.delegate = nil;
  _carouselCollectionView.dataSource = nil;
  [_dividerHeightConstraint release];
  [_benefitBodyHeightConstraint release];
  [_benefitTitleHeightConstraint release];
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
  [_benefitBodyLabel release];
  [_benefitTitleLabel release];
  [_captionLabel release];
  [_subtitleLabel release];
  [_titleLabel release];
  [_badgeView release];
  [_iconImageView release];
  [_iconContainerView release];
  [_carouselCollectionView release];
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

  UIView *iconWrapperView = [[[UIView alloc] init] autorelease];
  iconWrapperView.translatesAutoresizingMaskIntoConstraints = NO;
  iconWrapperView.accessibilityIdentifier = @"onboarding.logoWrapperView";
  self.iconWrapperHeightConstraint = [iconWrapperView.heightAnchor constraintEqualToConstant:100.0];
  [NSLayoutConstraint activateConstraints:@[ self.iconWrapperHeightConstraint ]];
  [stackView addArrangedSubview:iconWrapperView];

  UIView *iconContainerView = [[[UIView alloc] init] autorelease];
  iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  iconContainerView.backgroundColor = [UIColor clearColor];
  iconContainerView.clipsToBounds = YES;
  iconContainerView.accessibilityIdentifier = @"onboarding.logoContainerView";
  iconContainerView.layer.cornerRadius = 24.0;
  iconContainerView.layer.borderWidth = 1.0;
  iconContainerView.layer.borderColor = [[MRRPrimaryTextColor() colorWithAlphaComponent:0.12] CGColor];
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
  [collectionView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  [collectionView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  collectionView.dataSource = self;
  collectionView.delegate = self;
  collectionView.accessibilityIdentifier = @"onboarding.carouselCollectionView";
  [collectionView registerClass:[OnboardingRecipeCarouselCell class] forCellWithReuseIdentifier:MRRRecipeCarouselCellReuseIdentifier];
  [stackView addArrangedSubview:collectionView];
  self.carouselCollectionView = collectionView;

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

  UIButton *emailButton = [self authButtonWithTitle:@"Sign up with email"
                                           iconText:@"✉"
                                        filledStyle:NO
                            accessibilityIdentifier:@"onboarding.emailButton"
                                             action:@selector(handleEmailSignupTapped:)];
  [stackView addArrangedSubview:emailButton];
  self.emailButton = emailButton;

  UIView *dividerView = [self authDividerView];
  dividerView.accessibilityIdentifier = @"onboarding.authDividerView";
  [stackView addArrangedSubview:dividerView];

  UIButton *googleButton = [self authButtonWithTitle:@"Continue with Google"
                                            iconText:@"G"
                                         filledStyle:NO
                             accessibilityIdentifier:@"onboarding.googleButton"
                                              action:@selector(handleGoogleSignupTapped:)];
  [stackView addArrangedSubview:googleButton];
  self.googleButton = googleButton;

  UIButton *appleButton = [self authButtonWithTitle:@"Continue with Apple"
                                           iconText:@""
                                        filledStyle:YES
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
  loadingContainerView.backgroundColor = MRROnboardingLoadingPanelColor();
  loadingContainerView.layer.cornerRadius = 22.0;
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
  signinLabel.backgroundColor = [UIColor clearColor];
  signinLabel.contentEdgeInsets = UIEdgeInsetsZero;
  signinLabel.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  signinLabel.titleLabel.textAlignment = NSTextAlignmentCenter;
  [signinLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [signinLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [signinLabel setTitle:@"Sign in" forState:UIControlStateNormal];
  [signinLabel setTitle:@"Sign in" forState:UIControlStateHighlighted];
  [signinLabel setTitleColor:MRRPrimaryTextColor() forState:UIControlStateNormal];
  [signinLabel setTitleColor:[MRRPrimaryTextColor() colorWithAlphaComponent:0.76] forState:UIControlStateHighlighted];
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

  self.stackTopConstraint = [stackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16.0];
  self.stackBottomConstraint = [stackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16.0];
  self.stackLeadingConstraint = [stackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:22.0];
  self.stackTrailingConstraint = [stackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-22.0];
  self.carouselHeightConstraint = [collectionView.heightAnchor constraintEqualToConstant:160.0];
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
  pillView.backgroundColor = [MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]) colorWithAlphaComponent:0.14];
  pillView.layer.cornerRadius = 16.0;
  pillView.layer.borderWidth = 1.0;
  pillView.layer.borderColor = [[MRRPrimaryTextColor() colorWithAlphaComponent:0.08] CGColor];
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
                         iconText:(NSString *)iconText
                      filledStyle:(BOOL)filledStyle
          accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           action:(SEL)action {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.accessibilityIdentifier = accessibilityIdentifier;
  button.layer.cornerRadius = 18.0;
  button.layer.borderWidth = filledStyle ? 0.0 : 1.0;
  button.layer.borderColor = [[MRRPrimaryTextColor() colorWithAlphaComponent:0.12] CGColor];
  button.layer.shadowColor = [UIColor blackColor].CGColor;
  button.layer.shadowOpacity = filledStyle ? 0.18f : 0.12f;
  button.layer.shadowRadius = filledStyle ? 18.0f : 12.0f;
  button.layer.shadowOffset = CGSizeMake(0.0, filledStyle ? 10.0 : 8.0);
  button.backgroundColor = filledStyle ? MRRPrimaryTextColor() : MRRCardSurfaceColor();
  [self configurePressFeedbackForButton:button];
  [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

  UIView *contentWrapper = [[[UIView alloc] init] autorelease];
  contentWrapper.translatesAutoresizingMaskIntoConstraints = NO;
  contentWrapper.userInteractionEnabled = NO;
  contentWrapper.tag = MRROnboardingAuthButtonContentWrapperTag;
  contentWrapper.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".contentWrapper"];
  [button addSubview:contentWrapper];

  UILabel *iconLabel = [[[UILabel alloc] init] autorelease];
  iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
  iconLabel.tag = MRROnboardingAuthButtonIconTag;
  iconLabel.text = iconText;
  iconLabel.textAlignment = NSTextAlignmentCenter;
  iconLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
  iconLabel.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".iconLabel"];
  iconLabel.textColor = filledStyle ? MRRBackgroundSurfaceColor() : MRRPrimaryTextColor();
  [contentWrapper addSubview:iconLabel];

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.tag = MRROnboardingAuthButtonTitleTag;
  titleLabel.text = title;
  titleLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
  titleLabel.accessibilityIdentifier = [accessibilityIdentifier stringByAppendingString:@".titleLabel"];
  titleLabel.textColor = filledStyle ? MRRBackgroundSurfaceColor() : MRRPrimaryTextColor();
  titleLabel.adjustsFontSizeToFitWidth = YES;
  titleLabel.minimumScaleFactor = 0.82;
  [contentWrapper addSubview:titleLabel];

  [NSLayoutConstraint activateConstraints:@[
    [contentWrapper.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
    [contentWrapper.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],

    [iconLabel.leadingAnchor constraintEqualToAnchor:contentWrapper.leadingAnchor],
    [iconLabel.centerYAnchor constraintEqualToAnchor:contentWrapper.centerYAnchor],
    [iconLabel.widthAnchor constraintGreaterThanOrEqualToConstant:24.0],

    [titleLabel.leadingAnchor constraintEqualToAnchor:iconLabel.trailingAnchor constant:12.0],
    [titleLabel.topAnchor constraintEqualToAnchor:contentWrapper.topAnchor],
    [titleLabel.trailingAnchor constraintEqualToAnchor:contentWrapper.trailingAnchor],
    [titleLabel.bottomAnchor constraintEqualToAnchor:contentWrapper.bottomAnchor]
  ]];

  return button;
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
  [UIView
      animateWithDuration:0.12
                    delay:0.0
                  options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
               animations:^{
                 sender.transform = CGAffineTransformMakeScale(MRROnboardingButtonPressedScale, MRROnboardingButtonPressedScale);
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
  navigationController.navigationBarHidden = YES;
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
  CGFloat benefitTitleHeight = 0.0;
  CGFloat benefitBodyHeight = 0.0;
  CGFloat carouselHeight = 0.0;
  CGFloat buttonHeight = 0.0;
  CGFloat dividerHeight = 0.0;
  CGFloat signinFontSize = 0.0;
  CGFloat authDividerFontSize = 0.0;
  CGFloat buttonCornerRadius = 0.0;
  CGFloat buttonIconFontSize = 0.0;
  CGFloat buttonTitleFontSize = 0.0;
  CGFloat desiredLineSpacing = 0.0;

  horizontalInset = MRRLayoutScaledValue(22.0, viewportSize, MRRLayoutScaleAxisWidth);
  contentWidth = MAX(viewportWidth - (horizontalInset * 2.0), 0.0);
  stackSpacing = MRRLayoutScaledValue(9.0, viewportSize, MRRLayoutScaleAxisHeight);
  topInset = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisHeight);
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
  benefitTitleFontSize = MRRLayoutScaledValue(23.5, viewportSize, MRRLayoutScaleAxisWidth);
  benefitBodyFontSize = MRRLayoutScaledValue(14.5, viewportSize, MRRLayoutScaleAxisWidth);
  benefitTitleHeight = MRRLayoutScaledValue(42.0, viewportSize, MRRLayoutScaleAxisHeight);
  benefitBodyHeight = MRRLayoutScaledValue(27.0, viewportSize, MRRLayoutScaleAxisHeight);
  carouselHeight = MRRLayoutScaledValue(192.0, viewportSize, MRRLayoutScaleAxisHeight);
  buttonHeight = MRRLayoutScaledValue(48.0, viewportSize, MRRLayoutScaleAxisHeight);
  dividerHeight = MRRLayoutScaledValue(14.0, viewportSize, MRRLayoutScaleAxisHeight);
  signinFontSize = MRRLayoutScaledValue(14.5, viewportSize, MRRLayoutScaleAxisWidth);
  authDividerFontSize = MRRLayoutScaledValue(13.5, viewportSize, MRRLayoutScaleAxisWidth);
  buttonCornerRadius = MRRLayoutScaledValue(16.5, viewportSize, MRRLayoutScaleAxisHeight);
  buttonIconFontSize = MRRLayoutScaledValue(17.0, viewportSize, MRRLayoutScaleAxisHeight);
  buttonTitleFontSize = MRRLayoutScaledValue(15.5, viewportSize, MRRLayoutScaleAxisWidth);
  desiredLineSpacing = MRRLayoutScaledValue(12.0, viewportSize, MRRLayoutScaleAxisWidth);

  self.contentStackView.spacing = stackSpacing;
  self.stackTopConstraint.constant = topInset;
  self.stackBottomConstraint.constant = -bottomInset;
  self.stackLeadingConstraint.constant = horizontalInset;
  self.stackTrailingConstraint.constant = -horizontalInset;
  self.spacerHeightConstraint.constant = spacerHeight;
  self.iconWrapperHeightConstraint.constant = MRRLayoutRoundedMetric(iconContainerSize + iconTopInset + iconBottomInset);
  self.iconContainerTopConstraint.constant = iconTopInset;
  self.iconContainerWidthConstraint.constant = iconContainerSize;
  self.iconContainerHeightConstraint.constant = iconContainerSize;
  self.iconImageWidthConstraint.constant = iconImageSize;
  self.iconImageHeightConstraint.constant = iconImageSize;
  self.iconContainerView.layer.cornerRadius = MRRLayoutRoundedMetric(iconContainerSize * 0.28);
  self.titleLabel.attributedText = [self titleAttributedTextWithFontSize:titleFontSize kerning:titleKerning];
  self.subtitleLabel.font = [UIFont systemFontOfSize:subtitleFontSize weight:UIFontWeightMedium];
  self.captionLabel.attributedText = [self carouselCaptionAttributedTextWithFontSize:captionFontSize kerning:captionKerning];
  self.spacerView.hidden = NO;
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
  self.signinLabel.titleLabel.font = [UIFont boldSystemFontOfSize:signinFontSize];
  self.authDividerLabel.font = [UIFont systemFontOfSize:authDividerFontSize weight:UIFontWeightMedium];

  NSArray<UIButton *> *authButtons = @[ self.emailButton, self.googleButton, self.appleButton ];
  for (UIButton *button in authButtons) {
    button.layer.cornerRadius = buttonCornerRadius;

    UILabel *iconLabel = (UILabel *)[button viewWithTag:MRROnboardingAuthButtonIconTag];
    UILabel *titleLabel = (UILabel *)[button viewWithTag:MRROnboardingAuthButtonTitleTag];
    iconLabel.font = [UIFont systemFontOfSize:buttonIconFontSize weight:UIFontWeightSemibold];
    titleLabel.font = [UIFont systemFontOfSize:buttonTitleFontSize weight:UIFontWeightSemibold];
  }

  UICollectionViewFlowLayout *layout = [self carouselLayout];
  if (fabs(layout.minimumLineSpacing - desiredLineSpacing) >= 0.5) {
    layout.minimumLineSpacing = desiredLineSpacing;
    [layout invalidateLayout];
  }

  CGSize initialCarouselItemSize = [self carouselItemSizeForAvailableWidth:contentWidth
                                                           availableHeight:carouselHeight
                                                               lineSpacing:desiredLineSpacing];
  CGFloat desiredInteritemSpacing = MAX(carouselHeight + MRRCarouselSingleRowSpacingPadding, 1000.0);
  if (initialCarouselItemSize.width > 0.0 && initialCarouselItemSize.height > 0.0 &&
      (fabs(layout.itemSize.width - initialCarouselItemSize.width) >= 0.5 || fabs(layout.itemSize.height - initialCarouselItemSize.height) >= 0.5 ||
       fabs(layout.minimumInteritemSpacing - desiredInteritemSpacing) >= 0.5)) {
    layout.itemSize = initialCarouselItemSize;
    layout.minimumInteritemSpacing = desiredInteritemSpacing;
    [layout invalidateLayout];
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
  return (UICollectionViewFlowLayout *)self.carouselCollectionView.collectionViewLayout;
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
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (totalItemCount == 0) {
    return 0;
  }

  [self.carouselCollectionView layoutIfNeeded];
  CGFloat visibleMidX = offsetX + (CGRectGetWidth(self.carouselCollectionView.bounds) / 2.0);
  NSInteger nearestIndex = 0;
  CGFloat nearestDistance = CGFLOAT_MAX;

  for (NSInteger itemIndex = 0; itemIndex < totalItemCount; itemIndex++) {
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
    UICollectionViewLayoutAttributes *attributes = [self.carouselCollectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
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
  if (itemIndex < 0 || itemIndex >= [self virtualCarouselItemCount]) {
    return 0.0;
  }

  [self.carouselCollectionView layoutIfNeeded];
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
  UICollectionViewLayoutAttributes *attributes = [self.carouselCollectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
  if (attributes == nil) {
    return 0.0;
  }

  CGFloat centeredOffsetX = attributes.center.x - (CGRectGetWidth(self.carouselCollectionView.bounds) / 2.0);
  return MAX(centeredOffsetX, 0.0);
}

- (void)updateCarouselLayoutIfNeeded {
  UICollectionViewFlowLayout *layout = [self carouselLayout];
  CGFloat availableWidth = CGRectGetWidth(self.carouselCollectionView.bounds);
  CGFloat availableHeight = CGRectGetHeight(self.carouselCollectionView.bounds);
  if (availableWidth <= 0.0 || availableHeight <= 0.0) {
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
  [self.carouselCollectionView layoutIfNeeded];
  [self scrollToRecipeAtIndex:self.currentRecipeIndex animated:NO];
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
  desiredWidth = MRRLayoutScaledValue(176.0, carouselViewportSize, MRRLayoutScaleAxisWidth);
  desiredWidth = MIN(desiredWidth, MAX((availableWidth - lineSpacing) / 2.0, 0.0));
  desiredHeight = MRRLayoutScaledValue(196.0, carouselViewportSize, MRRLayoutScaleAxisHeight);
  desiredHeight = MIN(desiredHeight, MAX(availableHeight - 8.0, 0.0));

  return CGSizeMake(desiredWidth, desiredHeight);
}

- (void)ensureInitialCarouselPositionIfNeeded {
  if (self.recipes.count == 0 || self.carouselCollectionView == nil) {
    return;
  }

  CGSize carouselBoundsSize = self.carouselCollectionView.bounds.size;
  if (carouselBoundsSize.width <= 0.0 || carouselBoundsSize.height <= 0.0) {
    return;
  }

  BOOL boundsChangedSinceLastPositioning = fabs(self.lastPositionedCarouselBoundsSize.width - carouselBoundsSize.width) >= 0.5 ||
                                           fabs(self.lastPositionedCarouselBoundsSize.height - carouselBoundsSize.height) >= 0.5;
  if (self.hasAppliedInitialCarouselPosition && !boundsChangedSinceLastPositioning) {
    return;
  }

  NSInteger initialItemIndex = self.currentCarouselItemIndex;
  if (initialItemIndex < 0 || initialItemIndex >= [self virtualCarouselItemCount]) {
    initialItemIndex = [self middleCarouselItemIndexForRecipeIndex:self.currentRecipeIndex];
    if (initialItemIndex == NSNotFound) {
      return;
    }
  }

  [self scrollToCarouselItemAtIndex:initialItemIndex animated:NO];
  self.hasAppliedInitialCarouselPosition = YES;
  self.lastPositionedCarouselBoundsSize = carouselBoundsSize;
  [self resumeCarouselAutoscrollIfPossible];
}

- (void)scrollToCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated {
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (itemIndex < 0 || itemIndex >= totalItemCount) {
    return;
  }

  [self.carouselCollectionView
      setContentOffset:CGPointMake([self contentOffsetXForCarouselItemIndex:itemIndex], self.carouselCollectionView.contentOffset.y)
              animated:animated];
  self.currentCarouselItemIndex = itemIndex;
  self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:itemIndex];
  [self updatePageControl];
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
  NSInteger recipeCount = (NSInteger)self.recipes.count;
  if (recipeCount == 0) {
    return;
  }

  NSInteger currentLoopIndex = self.currentCarouselItemIndex / recipeCount;
  NSInteger middleLoopIndex = MRRCarouselLoopMultiplier / 2;
  if (currentLoopIndex == middleLoopIndex) {
    return;
  }

  NSInteger recenteredItemIndex = [self middleCarouselItemIndexForRecipeIndex:self.currentRecipeIndex];
  if (recenteredItemIndex == NSNotFound) {
    return;
  }

  self.currentCarouselItemIndex = recenteredItemIndex;
  [self.carouselCollectionView
      setContentOffset:CGPointMake([self contentOffsetXForCarouselItemIndex:recenteredItemIndex], self.carouselCollectionView.contentOffset.y)
              animated:NO];
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
  [self presentViewController:detailViewController animated:[self shouldAnimateModalTransitions] completion:nil];
}

- (void)pauseCarouselAutoscroll {
  [self.carouselTimer invalidate];
  self.carouselTimer = nil;
}

- (void)resumeCarouselAutoscrollIfPossible {
  if (!self.isViewVisible || !self.hasAppliedInitialCarouselPosition || self.isDetailPresented || self.carouselTimer != nil ||
      self.recipes.count < 2 || self.carouselCollectionView.dragging || self.carouselCollectionView.decelerating) {
    return;
  }

  self.carouselTimer = [NSTimer scheduledTimerWithTimeInterval:3.6 target:self selector:@selector(handleCarouselTimer:) userInfo:nil repeats:YES];
}

- (void)handleCarouselTimer:(NSTimer *)timer {
  if (self.recipes.count < 2 || self.isDetailPresented) {
    return;
  }

  [self recenterCarouselIfNeeded];
  NSInteger nextItemIndex = self.currentCarouselItemIndex + 1;
  if (nextItemIndex >= [self virtualCarouselItemCount]) {
    nextItemIndex = [self middleCarouselItemIndexForRecipeIndex:0];
  }

  [self scrollToCarouselItemAtIndex:nextItemIndex animated:YES];
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

  [cell configureWithRecipe:self.recipes[recipeIndex]];
  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  [self presentRecipeDetailForRecipeAtIndex:[self recipeIndexForCarouselItemIndex:indexPath.item]];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  [self pauseCarouselAutoscroll];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  NSInteger targetItemIndex = [self nearestCarouselItemIndexForOffsetX:targetContentOffset->x];
  targetContentOffset->x = [self contentOffsetXForCarouselItemIndex:targetItemIndex];
  self.currentCarouselItemIndex = targetItemIndex;
  self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:targetItemIndex];
  [self updatePageControl];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  if (!decelerate) {
    self.currentCarouselItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x];
    self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:self.currentCarouselItemIndex];
    [self updatePageControl];
    [self recenterCarouselIfNeeded];
    [self resumeCarouselAutoscrollIfPossible];
  }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  self.currentCarouselItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x];
  self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:self.currentCarouselItemIndex];
  [self updatePageControl];
  [self recenterCarouselIfNeeded];
  [self resumeCarouselAutoscrollIfPossible];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  self.currentCarouselItemIndex = [self nearestCarouselItemIndexForOffsetX:scrollView.contentOffset.x];
  self.currentRecipeIndex = [self recipeIndexForCarouselItemIndex:self.currentCarouselItemIndex];
  [self updatePageControl];
  [self recenterCarouselIfNeeded];
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

@end
