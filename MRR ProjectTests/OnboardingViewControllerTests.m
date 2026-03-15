#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface OnboardingViewController (Testing) <UICollectionViewDelegate>

@property(nonatomic, readonly) UICollectionView *carouselCollectionView;
@property(nonatomic, readonly) UIStackView *contentStackView;
@property(nonatomic, readonly) UIScrollView *scrollView;
@property(nonatomic, assign) NSInteger currentRecipeIndex;
@property(nonatomic, assign) NSInteger currentCarouselItemIndex;

- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex;
- (void)recenterCarouselIfNeeded;
- (void)handleCarouselTimer:(NSTimer *)timer;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
- (void)scrollToRecipeAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;

@end

@interface OnboardingRecipeDetailViewController (Testing)

- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;

@end

@interface OnboardingViewControllerTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) OnboardingStateController *stateController;
@property(nonatomic, strong) OnboardingViewController *viewController;
@property(nonatomic, strong) UIWindow *window;

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (UIView *)findViewWithAccessibilitySuffix:(NSString *)suffix inView:(UIView *)view;
- (void)layoutOnboardingForWindowSize:(CGSize)size;
- (CGRect)frameForAccessibilityIdentifier:(NSString *)identifier;
- (CGFloat)fontSizeForAccessibilityIdentifier:(NSString *)identifier;
- (NSDictionary<NSString *, NSNumber *> *)currentAdaptiveOnboardingMetrics;
- (NSDictionary<NSString *, NSNumber *> *)currentRecipeDetailMetrics;
- (CGFloat)visibleCarouselLabelFontSizeWithSuffix:(NSString *)suffix;
- (void)assertPrimaryOnboardingContentFitsCurrentViewport;
- (NSDictionary<NSString *, NSNumber *> *)adaptiveMetricsForWindowSize:(CGSize)size;
- (NSDictionary<NSString *, NSNumber *> *)recipeDetailMetricsForWindowSize:(CGSize)size;
- (void)spinMainRunLoop;

@end

@implementation OnboardingViewControllerTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"OnboardingViewControllerTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  self.viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.viewController;
  [self.window makeKeyAndVisible];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.window.hidden = YES;
  self.window = nil;
  self.viewController = nil;
  self.stateController = nil;
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testCarouselProvidesLoopingCopiesOfAllRecipeItems {
  NSInteger expectedCount = [self.stateController onboardingRecipes].count;
  NSInteger actualCount = [self.viewController.carouselCollectionView numberOfItemsInSection:0];

  XCTAssertGreaterThan(actualCount, expectedCount);
  XCTAssertEqual(actualCount % expectedCount, 0);
}

- (void)testSelectingRecipePresentsDetailModal {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil(self.viewController.presentedViewController);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"onboarding.recipeDetail.view");
}

- (void)testSelectingLoopedRecipeCopyPresentsDetailModal {
  NSInteger recipeCount = [self.stateController onboardingRecipes].count;
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:recipeCount inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil(self.viewController.presentedViewController);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"onboarding.recipeDetail.view");
}

- (void)testCarouselUsesCenteredOffsetModelForPaging {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.viewController.carouselCollectionView.collectionViewLayout;
  NSInteger targetIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:1];
  UICollectionViewLayoutAttributes *attributes = [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0]];
  XCTAssertNotNil(attributes);
  CGFloat expectedOffset = MAX(attributes.center.x - (CGRectGetWidth(self.viewController.carouselCollectionView.bounds) / 2.0), 0.0);

  XCTAssertEqualWithAccuracy([self.viewController contentOffsetXForCarouselItemIndex:targetIndex], expectedOffset, 0.5);
}

- (void)testInitialLayoutCentersCarouselOnMiddleLoopCopy {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger expectedItemIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:0];
  CGFloat expectedOffset = [self.viewController contentOffsetXForCarouselItemIndex:expectedItemIndex];

  XCTAssertEqual(self.viewController.currentCarouselItemIndex, expectedItemIndex);
  XCTAssertGreaterThan(expectedOffset, 0.0);
  XCTAssertEqualWithAccuracy(self.viewController.carouselCollectionView.contentOffset.x, expectedOffset, 0.5);
}

- (void)testRecenterMovesBoundaryCopyBackToMiddleLoopForSameRecipe {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeCount = [self.stateController onboardingRecipes].count;
  NSInteger loopCount = [self.viewController.carouselCollectionView numberOfItemsInSection:0] / recipeCount;
  NSInteger recipeIndex = recipeCount - 1;
  NSInteger boundaryIndex = ((loopCount - 1) * recipeCount) + recipeIndex;
  NSInteger middleIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];

  self.viewController.currentRecipeIndex = recipeIndex;
  self.viewController.currentCarouselItemIndex = boundaryIndex;
  [self.viewController.carouselCollectionView
      setContentOffset:CGPointMake([self.viewController contentOffsetXForCarouselItemIndex:boundaryIndex], 0.0)
              animated:NO];

  [self.viewController recenterCarouselIfNeeded];

  XCTAssertEqual(self.viewController.currentRecipeIndex, recipeIndex);
  XCTAssertEqual(self.viewController.currentCarouselItemIndex, middleIndex);
  XCTAssertEqualWithAccuracy(self.viewController.carouselCollectionView.contentOffset.x,
                             [self.viewController contentOffsetXForCarouselItemIndex:middleIndex], 0.5);
}

- (void)testAutoscrollAdvancesFromBoundaryCopyWithoutResettingToFirstColumn {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeCount = [self.stateController onboardingRecipes].count;
  NSInteger loopCount = [self.viewController.carouselCollectionView numberOfItemsInSection:0] / recipeCount;
  NSInteger lastRecipeIndex = recipeCount - 1;
  NSInteger boundaryIndex = ((loopCount - 1) * recipeCount) + lastRecipeIndex;
  NSInteger expectedNextIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:lastRecipeIndex] + 1;

  self.viewController.currentRecipeIndex = lastRecipeIndex;
  self.viewController.currentCarouselItemIndex = boundaryIndex;
  [self.viewController handleCarouselTimer:nil];
  [self spinMainRunLoop];

  XCTAssertEqual(self.viewController.currentCarouselItemIndex, expectedNextIndex);
  XCTAssertEqual(self.viewController.currentRecipeIndex, 0);
}

- (void)testDragSnappingUsesSameCenteredOffsetAsCarouselHelper {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger targetIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:2];
  CGPoint targetOffset = CGPointMake([self.viewController contentOffsetXForCarouselItemIndex:targetIndex] + 9.0, 0.0);

  [self.viewController scrollViewWillEndDragging:self.viewController.carouselCollectionView
                                    withVelocity:CGPointZero
                             targetContentOffset:&targetOffset];

  XCTAssertEqualWithAccuracy(targetOffset.x, [self.viewController contentOffsetXForCarouselItemIndex:targetIndex], 0.5);
  XCTAssertEqual(self.viewController.currentCarouselItemIndex, targetIndex);
  XCTAssertEqual(self.viewController.currentRecipeIndex, 2);
}

- (void)testOnboardingExposesCoreAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.logoImageView", @"onboarding.titleLabel", @"onboarding.subtitleLabel", @"onboarding.carouselCaptionLabel",
    @"onboarding.carouselHelperLabel", @"onboarding.carouselCollectionView", @"onboarding.pageControl", @"onboarding.footerLabel",
    @"onboarding.benefitTitleLabel", @"onboarding.benefitBodyLabel", @"onboarding.signinPromptLabel", @"onboarding.signinLabel",
    @"onboarding.loadingOverlay", @"onboarding.loadingContainer", @"onboarding.loadingIndicator"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }

  OnboardingRecipe *firstRecipe = [self.stateController onboardingRecipes].firstObject;
  NSString *carouselTitleIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.titleLabel", firstRecipe.assetName];
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:carouselTitleIdentifier inView:self.viewController.view]);
}

- (void)testOnboardingExposesDebugAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.scrollView",
    @"onboarding.contentView",
    @"onboarding.contentStackView",
    @"onboarding.logoWrapperView",
    @"onboarding.logoContainerView",
    @"onboarding.spacerView",
    @"onboarding.signinContainerView",
    @"onboarding.signinRowView",
    @"onboarding.emailButton.contentWrapper",
    @"onboarding.emailButton.iconLabel",
    @"onboarding.emailButton.titleLabel",
    @"onboarding.googleButton.contentWrapper",
    @"onboarding.googleButton.iconLabel",
    @"onboarding.googleButton.titleLabel",
    @"onboarding.appleButton.contentWrapper",
    @"onboarding.appleButton.iconLabel",
    @"onboarding.appleButton.titleLabel",
    @"onboarding.authDividerView",
    @"onboarding.authDividerView.leftLine",
    @"onboarding.authDividerView.rightLine",
    @"onboarding.authDividerView.label",
    @"onboarding.loadingOverlay",
    @"onboarding.loadingContainer",
    @"onboarding.loadingIndicator"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }

  OnboardingRecipe *firstRecipe = [self.stateController onboardingRecipes].firstObject;
  NSArray<NSString *> *carouselIdentifiers = @[
    [NSString stringWithFormat:@"onboarding.carouselCell.%@", firstRecipe.assetName],
    [NSString stringWithFormat:@"onboarding.carouselCell.%@.contentView", firstRecipe.assetName],
    [NSString stringWithFormat:@"onboarding.carouselCell.%@.cardView", firstRecipe.assetName],
    [NSString stringWithFormat:@"onboarding.carouselCell.%@.imageView", firstRecipe.assetName],
    [NSString stringWithFormat:@"onboarding.carouselCell.%@.textBackdropView", firstRecipe.assetName]
  ];

  for (NSString *identifier in carouselIdentifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }
}

- (void)testGoogleButtonUsesContinueCopy {
  UILabel *googleTitleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton.titleLabel"
                                                                            inView:self.viewController.view];

  XCTAssertNotNil(googleTitleLabel);
  XCTAssertEqualObjects(googleTitleLabel.text, @"Continue with Google");
}

- (void)testCarouselBackdropExpandsToContainWrappedBeefBourguignonText {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  NSArray<OnboardingRecipe *> *recipes = [self.stateController onboardingRecipes];
  NSUInteger beefRecipeIndex = [recipes indexOfObjectPassingTest:^BOOL(OnboardingRecipe *recipe, NSUInteger idx, BOOL *stop) {
    return [recipe.assetName isEqualToString:@"beef-bourguignon"];
  }];
  XCTAssertNotEqual(beefRecipeIndex, NSNotFound);

  [self.viewController scrollToRecipeAtIndex:(NSInteger)beefRecipeIndex animated:NO];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];

  NSString *identifierPrefix = [NSString stringWithFormat:@"onboarding.carouselCell.%@", recipes[beefRecipeIndex].assetName];
  UIView *backdropView = [self findViewWithAccessibilityIdentifier:[identifierPrefix stringByAppendingString:@".textBackdropView"]
                                                            inView:self.viewController.view];
  UILabel *titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:[identifierPrefix stringByAppendingString:@".titleLabel"]
                                                                      inView:self.viewController.view];
  UILabel *metadataLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:[identifierPrefix stringByAppendingString:@".metadataLabel"]
                                                                         inView:self.viewController.view];

  XCTAssertNotNil(backdropView);
  XCTAssertNotNil(titleLabel);
  XCTAssertNotNil(metadataLabel);

  CGRect backdropFrame = [backdropView convertRect:backdropView.bounds toView:self.viewController.view];
  CGRect titleFrame = [titleLabel convertRect:titleLabel.bounds toView:self.viewController.view];
  CGRect metadataFrame = [metadataLabel convertRect:metadataLabel.bounds toView:self.viewController.view];

  XCTAssertLessThanOrEqual(CGRectGetMinY(backdropFrame), CGRectGetMinY(titleFrame) + 0.5);
  XCTAssertGreaterThanOrEqual(CGRectGetMaxY(backdropFrame), CGRectGetMaxY(metadataFrame) - 0.5);
}

- (void)testCarouselCardsShareSameBackdropColor {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  NSArray<OnboardingRecipe *> *recipes = [self.stateController onboardingRecipes];
  OnboardingRecipe *defaultRecipe = recipes.firstObject;
  NSUInteger beefRecipeIndex = [recipes indexOfObjectPassingTest:^BOOL(OnboardingRecipe *recipe, NSUInteger idx, BOOL *stop) {
    return [recipe.assetName isEqualToString:@"beef-bourguignon"];
  }];
  XCTAssertNotNil(defaultRecipe);
  XCTAssertNotEqual(beefRecipeIndex, NSNotFound);

  NSString *defaultIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.textBackdropView", defaultRecipe.assetName];
  UIView *defaultBackdropView = [self findViewWithAccessibilityIdentifier:defaultIdentifier inView:self.viewController.view];
  XCTAssertNotNil(defaultBackdropView);

  UIColor *defaultColor = defaultBackdropView.backgroundColor;
  if (@available(iOS 13.0, *)) {
    defaultColor = [defaultColor resolvedColorWithTraitCollection:defaultBackdropView.traitCollection];
  }

  [self.viewController scrollToRecipeAtIndex:(NSInteger)beefRecipeIndex animated:NO];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];

  NSString *beefIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.textBackdropView", recipes[beefRecipeIndex].assetName];
  UIView *beefBackdropView = [self findViewWithAccessibilityIdentifier:beefIdentifier inView:self.viewController.view];
  XCTAssertNotNil(beefBackdropView);

  UIColor *beefColor = beefBackdropView.backgroundColor;
  if (@available(iOS 13.0, *)) {
    beefColor = [beefColor resolvedColorWithTraitCollection:beefBackdropView.traitCollection];
  }

  CGFloat defaultRed = 0.0;
  CGFloat defaultGreen = 0.0;
  CGFloat defaultBlue = 0.0;
  CGFloat defaultAlpha = 0.0;
  CGFloat beefRed = 0.0;
  CGFloat beefGreen = 0.0;
  CGFloat beefBlue = 0.0;
  CGFloat beefAlpha = 0.0;

  XCTAssertTrue([defaultColor getRed:&defaultRed green:&defaultGreen blue:&defaultBlue alpha:&defaultAlpha]);
  XCTAssertTrue([beefColor getRed:&beefRed green:&beefGreen blue:&beefBlue alpha:&beefAlpha]);

  CGFloat defaultBrightness = (0.2126 * defaultRed) + (0.7152 * defaultGreen) + (0.0722 * defaultBlue);
  CGFloat beefBrightness = (0.2126 * beefRed) + (0.7152 * beefGreen) + (0.0722 * beefBlue);

  XCTAssertEqualWithAccuracy(beefBrightness, defaultBrightness, 0.001);
  XCTAssertEqualWithAccuracy(beefAlpha, defaultAlpha, 0.001);
}

- (void)testCarouselBackdropUsesFadeMaskToSoftenTopEdge {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  OnboardingRecipe *firstRecipe = [self.stateController onboardingRecipes].firstObject;
  NSString *backdropIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.textBackdropView", firstRecipe.assetName];
  UIView *backdropView = [self findViewWithAccessibilityIdentifier:backdropIdentifier inView:self.viewController.view];

  XCTAssertNotNil(backdropView);
  XCTAssertTrue([backdropView.layer.mask isKindOfClass:[CAGradientLayer class]]);

  CAGradientLayer *maskLayer = (CAGradientLayer *)backdropView.layer.mask;
  XCTAssertEqual(maskLayer.colors.count, (NSUInteger)4);
  XCTAssertEqual(maskLayer.locations.count, (NSUInteger)4);
  XCTAssertEqualWithAccuracy(maskLayer.startPoint.y, 0.0, 0.001);
  XCTAssertEqualWithAccuracy(maskLayer.endPoint.y, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(maskLayer.locations[0].doubleValue, 0.0, 0.001);
  XCTAssertEqualWithAccuracy(maskLayer.locations[1].doubleValue, 0.16, 0.001);
}

- (void)testOnboardingLogoViewLoadsBrandAsset {
  UIImageView *logoImageView = (UIImageView *)[self findViewWithAccessibilityIdentifier:@"onboarding.logoImageView" inView:self.viewController.view];

  XCTAssertNotNil(logoImageView);
  XCTAssertNotNil(logoImageView.image);
}

- (void)testAuthButtonShowsPressedFeedbackAndResets {
  UIButton *emailButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.emailButton" inView:self.viewController.view];
  XCTAssertNotNil(emailButton);

  BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
  [UIView setAnimationsEnabled:NO];

  [self.viewController handlePressableButtonTouchDown:emailButton];
  XCTAssertEqualWithAccuracy(emailButton.transform.a, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(emailButton.transform.d, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(emailButton.alpha, 0.88, 0.001);

  [self.viewController handlePressableButtonTouchUp:emailButton];
  XCTAssertEqualWithAccuracy(emailButton.transform.a, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(emailButton.transform.d, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(emailButton.alpha, 1.0, 0.001);

  [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)testSigninButtonShowsPressedFeedbackAndResets {
  UIButton *signinButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.signinLabel" inView:self.viewController.view];
  XCTAssertNotNil(signinButton);

  BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
  [UIView setAnimationsEnabled:NO];

  [self.viewController handlePressableButtonTouchDown:signinButton];
  XCTAssertEqualWithAccuracy(signinButton.transform.a, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(signinButton.transform.d, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(signinButton.alpha, 0.88, 0.001);

  [self.viewController handlePressableButtonTouchUp:signinButton];
  XCTAssertEqualWithAccuracy(signinButton.transform.a, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(signinButton.transform.d, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(signinButton.alpha, 1.0, 0.001);

  [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)testSigninButtonUsesIntrinsicWidthInsteadOfFullRowWidth {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  CGRect promptFrame = [self frameForAccessibilityIdentifier:@"onboarding.signinPromptLabel"];
  CGRect signinFrame = [self frameForAccessibilityIdentifier:@"onboarding.signinLabel"];

  XCTAssertLessThan(CGRectGetWidth(signinFrame), CGRectGetWidth(promptFrame));
  XCTAssertGreaterThanOrEqual(CGRectGetMinX(signinFrame), CGRectGetMaxX(promptFrame));
}

- (void)testAuthButtonsAppearWithinInitialViewport {
  NSArray<NSString *> *buttonIdentifiers = @[ @"onboarding.emailButton", @"onboarding.googleButton", @"onboarding.appleButton" ];
  CGFloat viewportBottom = CGRectGetHeight(self.viewController.view.bounds) + 1.0;

  for (NSString *identifier in buttonIdentifiers) {
    UIView *button = [self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view];
    XCTAssertNotNil(button, @"Missing %@", identifier);

    CGRect buttonFrame = [button convertRect:button.bounds toView:self.viewController.view];
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(buttonFrame), 0.0, @"%@ should start on screen", identifier);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(buttonFrame), viewportBottom, @"%@ should be visible without scrolling", identifier);
  }
}

- (void)testOnboardingFitsWithinInitialViewportWithoutVerticalScroll {
  [self assertPrimaryOnboardingContentFitsCurrentViewport];
  XCTAssertFalse(self.viewController.scrollView.scrollEnabled);
  XCTAssertFalse(self.viewController.scrollView.alwaysBounceVertical);
}

- (void)testRecipeDetailExposesCoreAccessibilityIdentifiers {
  [self presentFirstRecipe];

  NSArray<NSString *> *identifiers = @[
    @"onboarding.recipeDetail.heroImageView", @"onboarding.recipeDetail.closeButton", @"onboarding.recipeDetail.subtitleLabel",
    @"onboarding.recipeDetail.titleLabel", @"onboarding.recipeDetail.durationChip", @"onboarding.recipeDetail.calorieChip",
    @"onboarding.recipeDetail.servingsChip", @"onboarding.recipeDetail.summaryLabel", @"onboarding.recipeDetail.ingredientsTitleLabel",
    @"onboarding.recipeDetail.ingredientChip.1", @"onboarding.recipeDetail.instructionsTitleLabel",
    @"onboarding.recipeDetail.instructionRow.1.indexLabel", @"onboarding.recipeDetail.instructionRow.1.titleLabel",
    @"onboarding.recipeDetail.instructionRow.1.bodyLabel", @"onboarding.recipeDetail.startCookingButton"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.presentedViewController.view], @"Missing %@",
                    identifier);
  }
}

- (void)testStartCookingMarksOnboardingCompletedAndDismissesDetail {
  [self presentFirstRecipe];

  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton"
                                                                         inView:self.viewController.presentedViewController.view];
  XCTAssertNotNil(startButton);

  [startButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey]);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testClosingDetailDoesNotMarkOnboardingCompleted {
  [self presentFirstRecipe];

  UIButton *closeButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton"
                                                                         inView:self.viewController.presentedViewController.view];
  XCTAssertNotNil(closeButton);

  [closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse([self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey]);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testRecipeDetailStartButtonShowsPressedFeedbackAndResets {
  [self presentFirstRecipe];

  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton"
                                                                         inView:self.viewController.presentedViewController.view];
  XCTAssertNotNil(startButton);

  BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
  [UIView setAnimationsEnabled:NO];

  OnboardingRecipeDetailViewController *detailViewController = (OnboardingRecipeDetailViewController *)self.viewController.presentedViewController;
  [detailViewController handlePressableButtonTouchDown:startButton];
  XCTAssertEqualWithAccuracy(startButton.transform.a, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(startButton.transform.d, 0.97, 0.001);
  XCTAssertEqualWithAccuracy(startButton.alpha, 0.88, 0.001);

  [detailViewController handlePressableButtonTouchUp:startButton];
  XCTAssertEqualWithAccuracy(startButton.transform.a, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(startButton.transform.d, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(startButton.alpha, 1.0, 0.001);

  [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)presentFirstRecipe {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];
}

- (void)testIPhone11ViewportFitsWithoutVerticalScroll {
  [self layoutOnboardingForWindowSize:CGSizeMake(414.0, 896.0)];

  [self assertPrimaryOnboardingContentFitsCurrentViewport];
}

- (void)testAdaptiveMetricsStayWithinReadableRangesAcrossDifferentIPhoneSizes {
  NSDictionary<NSString *, NSNumber *> *compactMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(320.0, 568.0)];
  NSDictionary<NSString *, NSNumber *> *baseMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(390.0, 844.0)];
  NSDictionary<NSString *, NSNumber *> *expandedMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(430.0, 932.0)];

  XCTAssertLessThan(compactMetrics[@"titleFontSize"].doubleValue, baseMetrics[@"titleFontSize"].doubleValue);
  XCTAssertLessThan(compactMetrics[@"buttonHeight"].doubleValue, baseMetrics[@"buttonHeight"].doubleValue);
  XCTAssertLessThan(compactMetrics[@"carouselItemWidth"].doubleValue, baseMetrics[@"carouselItemWidth"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"titleFontSize"].doubleValue, baseMetrics[@"titleFontSize"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"buttonHeight"].doubleValue, baseMetrics[@"buttonHeight"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"carouselItemWidth"].doubleValue, baseMetrics[@"carouselItemWidth"].doubleValue);
  XCTAssertGreaterThan(compactMetrics[@"carouselCellTitleFontSize"].doubleValue, 0.0);
  XCTAssertGreaterThan(compactMetrics[@"carouselCellMetadataFontSize"].doubleValue, 0.0);
}

- (void)testOnboardingFitsAcrossCommonIPhoneViewportSizes {
  NSArray<NSValue *> *viewportSizes = @[
    [NSValue valueWithCGSize:CGSizeMake(320.0, 568.0)], [NSValue valueWithCGSize:CGSizeMake(375.0, 667.0)],
    [NSValue valueWithCGSize:CGSizeMake(375.0, 812.0)], [NSValue valueWithCGSize:CGSizeMake(390.0, 844.0)],
    [NSValue valueWithCGSize:CGSizeMake(393.0, 852.0)], [NSValue valueWithCGSize:CGSizeMake(414.0, 896.0)],
    [NSValue valueWithCGSize:CGSizeMake(430.0, 932.0)]
  ];

  for (NSValue *viewportSizeValue in viewportSizes) {
    CGSize viewportSize = viewportSizeValue.CGSizeValue;
    [self layoutOnboardingForWindowSize:viewportSize];
    [self assertPrimaryOnboardingContentFitsCurrentViewport];
  }
}

- (void)testCarouselSizingIsWidthDrivenAndBoundedAcrossCommonIPhoneViewportSizes {
  NSArray<NSValue *> *viewportSizes = @[
    [NSValue valueWithCGSize:CGSizeMake(320.0, 568.0)], [NSValue valueWithCGSize:CGSizeMake(375.0, 812.0)],
    [NSValue valueWithCGSize:CGSizeMake(390.0, 844.0)], [NSValue valueWithCGSize:CGSizeMake(393.0, 852.0)],
    [NSValue valueWithCGSize:CGSizeMake(414.0, 896.0)], [NSValue valueWithCGSize:CGSizeMake(430.0, 932.0)]
  ];
  CGFloat previousItemWidth = 0.0;

  for (NSValue *viewportSizeValue in viewportSizes) {
    CGSize viewportSize = viewportSizeValue.CGSizeValue;
    [self layoutOnboardingForWindowSize:viewportSize];
    [self.viewController.carouselCollectionView layoutIfNeeded];

    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.viewController.carouselCollectionView.collectionViewLayout;
    CGFloat carouselWidth = CGRectGetWidth(self.viewController.carouselCollectionView.bounds);
    CGFloat carouselHeight = CGRectGetHeight(self.viewController.carouselCollectionView.bounds);

    XCTAssertGreaterThanOrEqual(layout.itemSize.width, 120.0, @"%.0fx%.0f should keep a readable card width", viewportSize.width,
                                viewportSize.height);
    XCTAssertLessThanOrEqual(layout.itemSize.width, ((carouselWidth - layout.minimumLineSpacing) / 2.0) + 0.5,
                             @"%.0fx%.0f should size cards from carousel width", viewportSize.width, viewportSize.height);
    XCTAssertLessThanOrEqual(layout.itemSize.height, carouselHeight + 0.5, @"%.0fx%.0f should keep card height within the carousel",
                             viewportSize.width, viewportSize.height);

    if (previousItemWidth > 0.0) {
      XCTAssertGreaterThanOrEqual(layout.itemSize.width, previousItemWidth - 0.5, @"Wider common viewports should not shrink carousel cards");
    }
    previousItemWidth = layout.itemSize.width;
  }
}

- (void)testCarouselCardsAdaptInternalTypographyAcrossViewportSizes {
  [self layoutOnboardingForWindowSize:CGSizeMake(320.0, 568.0)];
  NSDictionary<NSString *, NSNumber *> *compactMetrics = [self currentAdaptiveOnboardingMetrics];

  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  NSDictionary<NSString *, NSNumber *> *expandedMetrics = [self currentAdaptiveOnboardingMetrics];

  XCTAssertGreaterThanOrEqual(expandedMetrics[@"carouselCellTitleFontSize"].doubleValue, compactMetrics[@"carouselCellTitleFontSize"].doubleValue);
  XCTAssertGreaterThanOrEqual(expandedMetrics[@"carouselCellMetadataFontSize"].doubleValue,
                              compactMetrics[@"carouselCellMetadataFontSize"].doubleValue);
  XCTAssertGreaterThanOrEqual(expandedMetrics[@"carouselCellTitleFontSize"].doubleValue,
                              expandedMetrics[@"carouselCellMetadataFontSize"].doubleValue);
}

- (void)testScalingOnlyUsesViewportRatiosOnSmallViewport {
  NSDictionary<NSString *, NSNumber *> *baseMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(390.0, 844.0)];
  NSDictionary<NSString *, NSNumber *> *compactMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(320.0, 568.0)];

  XCTAssertEqualWithAccuracy(compactMetrics[@"titleFontSize"].doubleValue / baseMetrics[@"titleFontSize"].doubleValue, 320.0 / 390.0, 0.03);
  XCTAssertEqualWithAccuracy(compactMetrics[@"horizontalInset"].doubleValue / baseMetrics[@"horizontalInset"].doubleValue, 320.0 / 390.0, 0.03);
  XCTAssertEqualWithAccuracy(compactMetrics[@"buttonHeight"].doubleValue / baseMetrics[@"buttonHeight"].doubleValue, 568.0 / 844.0, 0.03);
}

- (void)testScalingOnlyExpandsMetricsProportionallyOnLargeViewport {
  NSDictionary<NSString *, NSNumber *> *baseMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(390.0, 844.0)];
  NSDictionary<NSString *, NSNumber *> *expandedMetrics = [self adaptiveMetricsForWindowSize:CGSizeMake(430.0, 932.0)];

  XCTAssertEqualWithAccuracy(expandedMetrics[@"titleFontSize"].doubleValue / baseMetrics[@"titleFontSize"].doubleValue, 430.0 / 390.0, 0.03);
  XCTAssertGreaterThan(expandedMetrics[@"buttonHeight"].doubleValue, baseMetrics[@"buttonHeight"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"carouselItemWidth"].doubleValue, baseMetrics[@"carouselItemWidth"].doubleValue);
}

- (void)testRecipeDetailMetricsScaleWithViewportSize {
  NSDictionary<NSString *, NSNumber *> *compactMetrics = [self recipeDetailMetricsForWindowSize:CGSizeMake(320.0, 568.0)];
  NSDictionary<NSString *, NSNumber *> *expandedMetrics = [self recipeDetailMetricsForWindowSize:CGSizeMake(430.0, 932.0)];

  XCTAssertGreaterThan(expandedMetrics[@"startButtonHeight"].doubleValue, compactMetrics[@"startButtonHeight"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"titleFontSize"].doubleValue, compactMetrics[@"titleFontSize"].doubleValue);
  XCTAssertGreaterThan(expandedMetrics[@"closeButtonSize"].doubleValue, compactMetrics[@"closeButtonSize"].doubleValue);
}

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view {
  if ([view.accessibilityIdentifier isEqualToString:identifier]) {
    return view;
  }

  for (UIView *subview in view.subviews) {
    UIView *matchingView = [self findViewWithAccessibilityIdentifier:identifier inView:subview];
    if (matchingView != nil) {
      return matchingView;
    }
  }

  return nil;
}

- (UIView *)findViewWithAccessibilitySuffix:(NSString *)suffix inView:(UIView *)view {
  if ([view.accessibilityIdentifier hasSuffix:suffix]) {
    return view;
  }

  for (UIView *subview in view.subviews) {
    UIView *matchingView = [self findViewWithAccessibilitySuffix:suffix inView:subview];
    if (matchingView != nil) {
      return matchingView;
    }
  }

  return nil;
}

- (void)layoutOnboardingForWindowSize:(CGSize)size {
  self.window.frame = CGRectMake(0.0, 0.0, size.width, size.height);
  self.window.bounds = CGRectMake(0.0, 0.0, size.width, size.height);
  [self.window setNeedsLayout];
  [self.window layoutIfNeeded];
  [self.viewController.view setNeedsLayout];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
  [self.window layoutIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];
}

- (CGRect)frameForAccessibilityIdentifier:(NSString *)identifier {
  UIView *view = [self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view];
  XCTAssertNotNil(view, @"Missing %@", identifier);
  return [view convertRect:view.bounds toView:self.viewController.view];
}

- (CGFloat)fontSizeForAccessibilityIdentifier:(NSString *)identifier {
  UILabel *label = (UILabel *)[self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view];
  XCTAssertNotNil(label, @"Missing %@", identifier);
  if (label == nil) {
    return 0.0;
  }

  UIFont *font = label.font;
  if (label.attributedText.length > 0) {
    UIFont *attributedFont = [label.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    if (attributedFont != nil) {
      font = attributedFont;
    }
  }

  return font.pointSize;
}

- (NSDictionary<NSString *, NSNumber *> *)currentAdaptiveOnboardingMetrics {
  UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.viewController.carouselCollectionView.collectionViewLayout;
  return @{
    @"titleFontSize" : @([self fontSizeForAccessibilityIdentifier:@"onboarding.titleLabel"]),
    @"horizontalInset" : @(CGRectGetMinX([self frameForAccessibilityIdentifier:@"onboarding.carouselCollectionView"])),
    @"stackSpacing" : @(self.viewController.contentStackView.spacing),
    @"carouselItemWidth" : @(layout.itemSize.width),
    @"carouselItemHeight" : @(layout.itemSize.height),
    @"buttonHeight" : @(CGRectGetHeight([self frameForAccessibilityIdentifier:@"onboarding.emailButton"])),
    @"carouselCellTitleFontSize" : @([self visibleCarouselLabelFontSizeWithSuffix:@".titleLabel"]),
    @"carouselCellMetadataFontSize" : @([self visibleCarouselLabelFontSizeWithSuffix:@".metadataLabel"])
  };
}

- (NSDictionary<NSString *, NSNumber *> *)currentRecipeDetailMetrics {
  UIView *detailRootView = self.viewController.presentedViewController.view;
  UILabel *titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.titleLabel" inView:detailRootView];
  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton" inView:detailRootView];
  UIButton *closeButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:detailRootView];

  XCTAssertNotNil(titleLabel);
  XCTAssertNotNil(startButton);
  XCTAssertNotNil(closeButton);

  return @{
    @"titleFontSize" : @(titleLabel.font.pointSize),
    @"startButtonHeight" : @(CGRectGetHeight([startButton convertRect:startButton.bounds toView:detailRootView])),
    @"closeButtonSize" : @(CGRectGetWidth([closeButton convertRect:closeButton.bounds toView:detailRootView])),
  };
}

- (CGFloat)visibleCarouselLabelFontSizeWithSuffix:(NSString *)suffix {
  UIView *labelView = [self findViewWithAccessibilitySuffix:suffix inView:self.viewController.carouselCollectionView];
  XCTAssertNotNil(labelView, @"Missing visible carousel label ending with %@", suffix);
  if (![labelView isKindOfClass:[UILabel class]]) {
    return 0.0;
  }

  return ((UILabel *)labelView).font.pointSize;
}

- (void)assertPrimaryOnboardingContentFitsCurrentViewport {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.benefitTitleLabel", @"onboarding.benefitBodyLabel", @"onboarding.emailButton", @"onboarding.googleButton", @"onboarding.appleButton",
    @"onboarding.signinPromptLabel", @"onboarding.signinLabel"
  ];
  CGFloat viewportBottom = CGRectGetHeight(self.viewController.view.bounds) + 1.0;

  for (NSString *identifier in identifiers) {
    UIView *view = [self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view];
    XCTAssertNotNil(view, @"Missing %@", identifier);
    XCTAssertFalse(view.hidden, @"%@ should remain visible in the adaptive layout", identifier);
    CGRect frame = [self frameForAccessibilityIdentifier:identifier];
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(frame), 0.0, @"%@ should start on screen", identifier);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(frame), viewportBottom, @"%@ should stay above the fold", identifier);
  }
}

- (NSDictionary<NSString *, NSNumber *> *)adaptiveMetricsForWindowSize:(CGSize)size {
  UIWindow *previousWindow = self.window;
  OnboardingViewController *previousViewController = self.viewController;

  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
  OnboardingViewController *viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];

  self.window = window;
  self.viewController = viewController;
  [self.viewController loadViewIfNeeded];
  [self layoutOnboardingForWindowSize:size];

  NSDictionary<NSString *, NSNumber *> *metrics = [[self currentAdaptiveOnboardingMetrics] copy];

  window.hidden = YES;
  self.window = previousWindow;
  self.viewController = previousViewController;

  return metrics;
}

- (NSDictionary<NSString *, NSNumber *> *)recipeDetailMetricsForWindowSize:(CGSize)size {
  UIWindow *previousWindow = self.window;
  OnboardingViewController *previousViewController = self.viewController;

  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
  OnboardingViewController *viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];

  self.window = window;
  self.viewController = viewController;
  [self.viewController loadViewIfNeeded];
  [self layoutOnboardingForWindowSize:size];
  [self presentFirstRecipe];
  [self.viewController.presentedViewController.view setNeedsLayout];
  [self.viewController.presentedViewController.view layoutIfNeeded];
  [self spinMainRunLoop];

  NSDictionary<NSString *, NSNumber *> *metrics = [[self currentRecipeDetailMetrics] copy];

  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  window.hidden = YES;
  self.window = previousWindow;
  self.viewController = previousViewController;

  return metrics;
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
