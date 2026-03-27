#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingRecipeCatalog.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface OnboardingViewController (Testing) <UICollectionViewDelegate>

@property(nonatomic, readonly) UICollectionView *carouselCollectionView;
@property(nonatomic, readonly) UICollectionView *secondaryCarouselCollectionView;
@property(nonatomic, readonly) UIStackView *contentStackView;
@property(nonatomic, readonly) UIScrollView *scrollView;
@property(nonatomic, readonly) NSArray<OnboardingRecipePreview *> *recipes;
@property(nonatomic, assign) NSInteger currentRecipeIndex;
@property(nonatomic, assign) NSInteger currentCarouselItemIndex;
@property(nonatomic, assign) NSInteger secondaryCurrentCarouselItemIndex;

- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex inCollectionView:(UICollectionView *)collectionView;
- (BOOL)isCarouselCollectionViewInteracting:(UICollectionView *)collectionView;
- (void)pauseCarouselAutoscroll;
- (void)recenterCarouselIfNeeded;
- (void)handleCarouselTimer:(NSTimer *)timer;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
- (void)scrollToRecipeAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;

@end

@interface InteractionAwareOnboardingViewController : OnboardingViewController

@property(nonatomic, assign) UICollectionView *forcedInteractingCollectionView;

@end

@implementation InteractionAwareOnboardingViewController

- (BOOL)isCarouselCollectionViewInteracting:(UICollectionView *)collectionView {
  if (collectionView == self.forcedInteractingCollectionView) {
    return YES;
  }

  return [super isCarouselCollectionViewInteracting:collectionView];
}

@end

@interface OnboardingViewControllerAuthStub : NSObject <MRRAuthenticationController>
@end

@interface OnboardingViewControllerAuthObservationStub : NSObject <MRRAuthStateObservation>
@end

@implementation OnboardingViewControllerAuthObservationStub

- (void)invalidate {
}

@end

@implementation OnboardingViewControllerAuthStub

- (MRRAuthSession *)currentSession {
  return nil;
}

- (id<MRRAuthStateObservation>)observeAuthStateWithHandler:(MRRAuthStateChangeHandler)handler {
  return [[OnboardingViewControllerAuthObservationStub alloc] init];
}

- (BOOL)hasPendingCredentialLink {
  return NO;
}

- (NSString *)pendingLinkEmail {
  return nil;
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(nil, nil);
}

- (void)signInWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  completion(nil, nil);
}

- (void)sendPasswordResetForEmail:(NSString *)email completion:(MRRAuthCompletion)completion {
  completion(nil);
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  completion(nil, nil);
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  completion(nil);
}

- (BOOL)signOut:(NSError *__autoreleasing _Nullable *)error {
  return YES;
}

@end

@interface OnboardingRecipeDetailViewController (Testing)

- (void)didTapCloseButton;
- (void)handlePressableButtonTouchDown:(UIButton *)sender;
- (void)handlePressableButtonTouchUp:(UIButton *)sender;

@end

@interface OnboardingViewControllerTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) OnboardingStateController *stateController;
@property(nonatomic, strong) OnboardingRecipeCatalog *recipeCatalog;
@property(nonatomic, strong) OnboardingViewControllerAuthStub *authenticationController;
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
- (NSString *)displayedTitleForButton:(UIButton *)button;
- (UIImage *)displayedImageForButton:(UIButton *)button;
- (UIViewController *)presentedRecipeContainerViewController;
- (OnboardingRecipeDetailViewController *)presentedRecipeDetailViewController;
- (UIView *)presentedRecipeDetailRootView;
- (void)presentFirstRecipe;
- (void)presentRecipeAtIndex:(NSInteger)index fromCollectionView:(UICollectionView *)collectionView;
- (NSArray<UICollectionView *> *)carouselCollectionViews;
- (nullable UICollectionView *)secondaryCarouselCollectionViewIfAvailable;
- (BOOL)isSecondaryCarouselCollectionViewAvailable;
- (void)assertPrimaryOnboardingContentFitsCurrentViewport;
- (NSDictionary<NSString *, NSNumber *> *)adaptiveMetricsForWindowSize:(CGSize)size;
- (NSDictionary<NSString *, NSNumber *> *)recipeDetailMetricsForWindowSize:(CGSize)size;
- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout;
- (void)spinMainRunLoop;
- (void)spinMainRunLoopForInterval:(NSTimeInterval)interval;

@end

@implementation OnboardingViewControllerTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"OnboardingViewControllerTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  self.recipeCatalog = [[OnboardingRecipeCatalog alloc] init];
  self.authenticationController = [[OnboardingViewControllerAuthStub alloc] init];
  self.viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController
                                                         authenticationController:self.authenticationController
                                                                     recipeCatalog:self.recipeCatalog];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.viewController;
  [self.window makeKeyAndVisible];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self.viewController pauseCarouselAutoscroll];
  [self spinMainRunLoop];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.window.hidden = YES;
  self.window = nil;
  self.viewController = nil;
  self.authenticationController = nil;
  self.recipeCatalog = nil;
  self.stateController = nil;
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testCarouselProvidesLoopingCopiesOfAllRecipeItems {
  NSInteger expectedCount = self.viewController.recipes.count;
  NSInteger actualCount = [self.viewController.carouselCollectionView numberOfItemsInSection:0];

  XCTAssertGreaterThan(actualCount, expectedCount);
  XCTAssertEqual(actualCount % expectedCount, 0);
}

- (void)testSelectingRecipePresentsDetailModal {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil([self presentedRecipeContainerViewController]);
  XCTAssertEqualObjects([self presentedRecipeDetailRootView].accessibilityIdentifier, @"onboarding.recipeDetail.view");
}

- (void)testSelectingLoopedRecipeCopyPresentsDetailModal {
  NSInteger recipeCount = self.viewController.recipes.count;
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:recipeCount inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil([self presentedRecipeContainerViewController]);
  XCTAssertEqualObjects([self presentedRecipeDetailRootView].accessibilityIdentifier, @"onboarding.recipeDetail.view");
}

- (void)testSelectingRecipeUsesCuratedDetailImmediately {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  OnboardingRecipePreview *firstRecipe = self.viewController.recipes.firstObject;

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  OnboardingRecipeDetailViewController *detailViewController = [self presentedRecipeDetailViewController];
  XCTAssertFalse(detailViewController.isLoading);
  UILabel *titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.titleLabel" inView:detailViewController.view];
  UILabel *summaryLabel =
      (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryLabel" inView:detailViewController.view];
  XCTAssertEqualObjects(titleLabel.text, firstRecipe.fallbackDetail.title);
  XCTAssertEqualObjects(summaryLabel.text, firstRecipe.fallbackDetail.summaryText);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.headerCardSkeletonView" inView:detailViewController.view]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.titleSkeletonView" inView:detailViewController.view]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryCardSkeletonView" inView:detailViewController.view]);
}

- (void)testCuratedRecipeDetailShowsStaticMetadataAndHidesSourceBadge {
  [self presentFirstRecipe];

  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.sourceTitleLabel"
                                                  inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.sourceButton"
                                                  inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.headerCardView"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryCardView"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryToggleButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  UILabel *instructionsTitleLabel =
      (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.instructionsTitleLabel"
                                                    inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(instructionsTitleLabel);
  XCTAssertEqualObjects(instructionsTitleLabel.text, @"Methods");
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.instructionsIconView"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.instructionsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsTitleLabel"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsIconView"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsToggleButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolRow.1"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsTitleLabel"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsIconView"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsToggleButton"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagChip.1"
                                                     inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryCardView.accentBar"
                                                  inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.debugSourceBadge.label"
                                                  inView:[self presentedRecipeDetailRootView]]);
}

- (void)testRecipeDetailSummaryCanExpandAndCollapse {
  [self presentFirstRecipe];

  UILabel *summaryLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryLabel"
                                                                        inView:[self presentedRecipeDetailRootView]];
  UIButton *summaryToggleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.summaryToggleButton"
                                                                                 inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(summaryLabel);
  XCTAssertNotNil(summaryToggleButton);
  XCTAssertEqual(summaryLabel.numberOfLines, 4);
  XCTAssertEqualObjects([self displayedTitleForButton:summaryToggleButton], @"Read more");

  [summaryToggleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(summaryLabel.numberOfLines, 0);
  XCTAssertEqualObjects([self displayedTitleForButton:summaryToggleButton], @"Show less");

  [summaryToggleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertEqual(summaryLabel.numberOfLines, 4);
  XCTAssertEqualObjects([self displayedTitleForButton:summaryToggleButton], @"Read more");
}

- (void)testRecipeDetailIngredientsSectionCanExpandAndCollapse {
  [self presentFirstRecipe];

  UIView *ingredientsBodyView = [self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.ingredientsSectionBodyView"
                                                                   inView:[self presentedRecipeDetailRootView]];
  UIButton *ingredientsHeaderButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.ingredientsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(ingredientsBodyView);
  XCTAssertNotNil(ingredientsHeaderButton);
  XCTAssertTrue(ingredientsBodyView.hidden);

  [ingredientsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse(ingredientsBodyView.hidden);

  [ingredientsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(ingredientsBodyView.hidden);
}

- (void)testRecipeDetailMethodSectionCanExpandAndCollapse {
  [self presentFirstRecipe];

  UIView *instructionsBodyView = [self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.instructionsSectionBodyView"
                                                                    inView:[self presentedRecipeDetailRootView]];
  UIButton *instructionsHeaderButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.instructionsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(instructionsBodyView);
  XCTAssertNotNil(instructionsHeaderButton);
  XCTAssertTrue(instructionsBodyView.hidden);

  [instructionsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse(instructionsBodyView.hidden);

  [instructionsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(instructionsBodyView.hidden);
}

- (void)testRecipeDetailToolsSectionCanExpandAndCollapse {
  [self presentFirstRecipe];

  UIView *toolsBodyView = [self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsSectionBodyView"
                                                             inView:[self presentedRecipeDetailRootView]];
  UIButton *toolsHeaderButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.toolsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(toolsBodyView);
  XCTAssertNotNil(toolsHeaderButton);
  XCTAssertTrue(toolsBodyView.hidden);

  [toolsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse(toolsBodyView.hidden);

  [toolsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(toolsBodyView.hidden);
}

- (void)testRecipeDetailTagsSectionCanExpandAndCollapse {
  [self presentFirstRecipe];

  UIView *tagsBodyView = [self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsSectionBodyView"
                                                            inView:[self presentedRecipeDetailRootView]];
  UIButton *tagsHeaderButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.tagsHeaderButton"
                                                     inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(tagsBodyView);
  XCTAssertNotNil(tagsHeaderButton);
  XCTAssertTrue(tagsBodyView.hidden);

  [tagsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse(tagsBodyView.hidden);

  [tagsHeaderButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(tagsBodyView.hidden);
}

- (void)testDuplicateTapWhileRecipeDetailIsPresentedKeepsSingleModal {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  UIViewController *presentedContainer = [self presentedRecipeContainerViewController];
  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertEqual([self presentedRecipeContainerViewController], presentedContainer);
}

- (void)testPresentedRecipeDetailPausesSyntheticAutoscroll {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeIndex = 2;
  NSInteger centeredIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];
  CGFloat initialOffset =
      [self.viewController contentOffsetXForCarouselItemIndex:centeredIndex inCollectionView:self.viewController.carouselCollectionView];
  [self.viewController.carouselCollectionView setContentOffset:CGPointMake(initialOffset, 0.0) animated:NO];
  self.viewController.currentRecipeIndex = recipeIndex;
  self.viewController.currentCarouselItemIndex = centeredIndex;

  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  CGFloat offsetWhilePresented = self.viewController.carouselCollectionView.contentOffset.x;
  [self.viewController handleCarouselTimer:nil];

  XCTAssertEqualWithAccuracy(initialOffset, offsetWhilePresented, 0.15);
  XCTAssertEqualWithAccuracy(self.viewController.carouselCollectionView.contentOffset.x, offsetWhilePresented, 0.01);
}

- (void)testClosingRecipeDetailDismissesModalCleanly {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];

  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] != nil;
  } timeout:1.0];

  OnboardingRecipeDetailViewController *detailViewController = [self presentedRecipeDetailViewController];
  [detailViewController didTapCloseButton];
  [self waitForCondition:^BOOL {
    return [self presentedRecipeContainerViewController] == nil;
  } timeout:1.0];

  XCTAssertNil([self presentedRecipeContainerViewController]);
}

- (void)testSecondaryCarouselProvidesLoopingCopiesOfAllRecipeItems {
  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary == nil) {
    XCTSkip(@"Secondary carousel row not implemented yet.");
  }

  NSInteger expectedCount = self.viewController.recipes.count;
  NSInteger actualCount = [secondary numberOfItemsInSection:0];

  XCTAssertGreaterThan(actualCount, expectedCount);
  XCTAssertEqual(actualCount % expectedCount, 0);
}

- (void)testSelectingRecipeInSecondaryCarouselPresentsDetailModal {
  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary == nil) {
    XCTSkip(@"Secondary carousel row not implemented yet.");
  }

  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:secondary didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];

  XCTAssertNotNil([self presentedRecipeContainerViewController]);
  XCTAssertEqualObjects([self presentedRecipeDetailRootView].accessibilityIdentifier, @"onboarding.recipeDetail.view");
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
  XCTAssertLessThanOrEqual(fabs(self.viewController.carouselCollectionView.contentOffset.x - expectedOffset), 24.0);
}

- (void)testRecenterMovesBoundaryCopyBackToMiddleLoopForSameRecipe {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeCount = self.viewController.recipes.count;
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

- (void)testContinuousAutoscrollMovesPrimaryCarouselForward {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeIndex = 2;
  NSInteger centeredIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];
  [self.viewController scrollToRecipeAtIndex:recipeIndex animated:NO];
  CGFloat initialOffset = self.viewController.carouselCollectionView.contentOffset.x;

  self.viewController.currentRecipeIndex = recipeIndex;
  self.viewController.currentCarouselItemIndex = centeredIndex;
  [self.viewController handleCarouselTimer:nil];
  [self spinMainRunLoop];

  XCTAssertGreaterThan(self.viewController.carouselCollectionView.contentOffset.x, initialOffset);
  XCTAssertEqual(self.viewController.currentRecipeIndex, recipeIndex);
}

- (void)testContinuousAutoscrollMovesSecondaryCarouselBackward {
  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary == nil) {
    XCTSkip(@"Secondary carousel row not implemented yet.");
  }

  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [secondary layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeIndex = 4;
  NSInteger centeredIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];
  [secondary setContentOffset:CGPointMake([self.viewController contentOffsetXForCarouselItemIndex:centeredIndex
                                                                                  inCollectionView:secondary],
                                          0.0)
                     animated:NO];
  CGFloat initialOffset = secondary.contentOffset.x;

  self.viewController.secondaryCurrentCarouselItemIndex = centeredIndex;
  [self.viewController handleCarouselTimer:nil];
  [self spinMainRunLoop];

  XCTAssertLessThan(secondary.contentOffset.x, initialOffset);
}

- (void)testContinuousAutoscrollUsesSameMagnitudeAcrossCarouselRows {
  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary == nil) {
    XCTSkip(@"Secondary carousel row not implemented yet.");
  }

  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [secondary layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger recipeIndex = 2;
  NSInteger centeredIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];
  CGFloat primaryInitialOffset =
      [self.viewController contentOffsetXForCarouselItemIndex:centeredIndex inCollectionView:self.viewController.carouselCollectionView];
  CGFloat secondaryInitialOffset =
      [self.viewController contentOffsetXForCarouselItemIndex:centeredIndex inCollectionView:secondary];

  [self.viewController.carouselCollectionView setContentOffset:CGPointMake(primaryInitialOffset, 0.0) animated:NO];
  [secondary setContentOffset:CGPointMake(secondaryInitialOffset, 0.0) animated:NO];

  self.viewController.currentRecipeIndex = recipeIndex;
  self.viewController.currentCarouselItemIndex = centeredIndex;
  self.viewController.secondaryCurrentCarouselItemIndex = centeredIndex;
  for (NSInteger tick = 0; tick < 24; tick++) {
    [self.viewController handleCarouselTimer:nil];
  }
  [self spinMainRunLoop];

  CGFloat primaryDelta = self.viewController.carouselCollectionView.contentOffset.x - primaryInitialOffset;
  CGFloat secondaryDelta = secondaryInitialOffset - secondary.contentOffset.x;

  XCTAssertGreaterThan(primaryDelta, 0.0);
  XCTAssertGreaterThan(secondaryDelta, 0.0);
  XCTAssertEqualWithAccuracy(primaryDelta, secondaryDelta, 0.35);
}

- (void)testInteractingPrimaryCarouselDoesNotStopSecondaryAutoscroll {
  UIWindow *previousWindow = self.window;
  OnboardingViewController *previousViewController = self.viewController;

  InteractionAwareOnboardingViewController *viewController =
      [[InteractionAwareOnboardingViewController alloc] initWithStateController:self.stateController
                                                       authenticationController:self.authenticationController
                                                                   recipeCatalog:self.recipeCatalog];
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, 430.0, 932.0)];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];

  self.window = window;
  self.viewController = viewController;
  [self.viewController loadViewIfNeeded];
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];

  UICollectionView *secondary = [viewController secondaryCarouselCollectionView];
  XCTAssertNotNil(secondary);

  NSInteger recipeIndex = 2;
  NSInteger centeredIndex = [viewController middleCarouselItemIndexForRecipeIndex:recipeIndex];
  CGFloat primaryInitialOffset =
      [viewController contentOffsetXForCarouselItemIndex:centeredIndex inCollectionView:viewController.carouselCollectionView];
  CGFloat secondaryInitialOffset = [viewController contentOffsetXForCarouselItemIndex:centeredIndex inCollectionView:secondary];

  [viewController.carouselCollectionView setContentOffset:CGPointMake(primaryInitialOffset, 0.0) animated:NO];
  [secondary setContentOffset:CGPointMake(secondaryInitialOffset, 0.0) animated:NO];
  viewController.currentCarouselItemIndex = centeredIndex;
  viewController.secondaryCurrentCarouselItemIndex = centeredIndex;
  viewController.forcedInteractingCollectionView = viewController.carouselCollectionView;

  [viewController handleCarouselTimer:nil];
  [self spinMainRunLoop];

  XCTAssertLessThanOrEqual(fabs(viewController.carouselCollectionView.contentOffset.x - primaryInitialOffset), 0.15);
  XCTAssertLessThan(secondary.contentOffset.x, secondaryInitialOffset);

  [viewController pauseCarouselAutoscroll];
  window.hidden = YES;
  self.window = previousWindow;
  self.viewController = previousViewController;
}

- (void)testDragDoesNotSnapCarouselToCenteredOffset {
  [self layoutOnboardingForWindowSize:CGSizeMake(430.0, 932.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger targetIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:2];
  CGFloat unsnappedOffset = [self.viewController contentOffsetXForCarouselItemIndex:targetIndex] + 9.0;
  CGPoint targetOffset = CGPointMake(unsnappedOffset, 0.0);

  [self.viewController scrollViewWillEndDragging:self.viewController.carouselCollectionView
                                    withVelocity:CGPointZero
                             targetContentOffset:&targetOffset];

  XCTAssertEqualWithAccuracy(targetOffset.x, unsnappedOffset, 0.001);
  XCTAssertEqual(self.viewController.currentCarouselItemIndex, targetIndex);
  XCTAssertEqual(self.viewController.currentRecipeIndex, 2);
}

- (void)testOnboardingExposesCoreAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.logoImageView", @"onboarding.titleLabel", @"onboarding.subtitleLabel", @"onboarding.carouselCaptionLabel",
    @"onboarding.carouselHelperLabel", @"onboarding.heroCarouselContainerView", @"onboarding.carouselCollectionView",
    @"onboarding.carouselCollectionView.secondary", @"onboarding.pageControl", @"onboarding.footerLabel", @"onboarding.benefitTitleLabel",
    @"onboarding.benefitBodyLabel", @"onboarding.signinPromptLabel", @"onboarding.signinLabel", @"onboarding.emailButton",
    @"onboarding.googleButton", @"onboarding.appleButton", @"onboarding.loadingOverlay", @"onboarding.loadingContainer",
    @"onboarding.loadingIndicator"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }

  OnboardingRecipePreview *firstRecipe = self.viewController.recipes.firstObject;
  NSString *carouselTitleIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.titleLabel", firstRecipe.assetName];
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:carouselTitleIdentifier inView:self.viewController.view]);
}

- (void)testOnboardingExposesDebugAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.scrollView",
    @"onboarding.contentView",
    @"onboarding.contentStackView",
    @"onboarding.heroCarouselContainerView",
    @"onboarding.heroCarouselRowsStackView",
    @"onboarding.heroCarouselPrimaryRowView",
    @"onboarding.heroCarouselSecondaryRowView",
    @"onboarding.logoWrapperView",
    @"onboarding.logoContainerView",
    @"onboarding.spacerView",
    @"onboarding.signinContainerView",
    @"onboarding.signinRowView",
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

  OnboardingRecipePreview *firstRecipe = self.viewController.recipes.firstObject;
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

- (void)testSecondaryCarouselUsesHalfCardPhaseOffset {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary == nil) {
    XCTSkip(@"Secondary carousel row not implemented yet.");
  }

  [self.viewController.carouselCollectionView layoutIfNeeded];
  [secondary layoutIfNeeded];

  NSInteger referenceIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:0];
  CGFloat primaryOffset =
      [self.viewController contentOffsetXForCarouselItemIndex:referenceIndex
                                             inCollectionView:self.viewController.carouselCollectionView];
  CGFloat secondaryOffset = [self.viewController contentOffsetXForCarouselItemIndex:referenceIndex inCollectionView:secondary];
  UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.viewController.carouselCollectionView.collectionViewLayout;
  CGFloat expectedPhaseOffset = (layout.itemSize.width + layout.minimumLineSpacing) * 0.5;

  XCTAssertEqualWithAccuracy(secondaryOffset - primaryOffset, expectedPhaseOffset, 1.0);
}

- (void)testCarouselRowsBleedPastHeroContainerEdgesForInfiniteMotion {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  CGRect heroFrame = [self frameForAccessibilityIdentifier:@"onboarding.heroCarouselContainerView"];
  CGRect primaryFrame = [self frameForAccessibilityIdentifier:@"onboarding.carouselCollectionView"];
  CGRect secondaryFrame = [self frameForAccessibilityIdentifier:@"onboarding.carouselCollectionView.secondary"];

  XCTAssertLessThan(CGRectGetMinX(primaryFrame), CGRectGetMinX(heroFrame));
  XCTAssertGreaterThan(CGRectGetMaxX(primaryFrame), CGRectGetMaxX(heroFrame));
  XCTAssertLessThan(CGRectGetMinX(secondaryFrame), CGRectGetMinX(heroFrame));
  XCTAssertGreaterThan(CGRectGetMaxX(secondaryFrame), CGRectGetMaxX(heroFrame));
}

- (void)testGoogleButtonUsesContinueCopy {
  UIButton *googleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.googleButton" inView:self.viewController.view];

  XCTAssertNotNil(googleButton);
  XCTAssertEqualObjects([self displayedTitleForButton:googleButton], @"Continue with Google");
}

- (void)testAuthButtonsExposeLeadingIcons {
  NSArray<NSString *> *identifiers = @[ @"onboarding.emailButton", @"onboarding.googleButton", @"onboarding.appleButton" ];

  for (NSString *identifier in identifiers) {
    UIButton *button = (UIButton *)[self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view];
    XCTAssertNotNil(button);
    XCTAssertNotNil([self displayedImageForButton:button], @"Missing icon for %@", identifier);
  }
}

- (void)testCarouselBackdropExpandsToContainWrappedBeefBourguignonText {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];

  NSArray<OnboardingRecipePreview *> *recipes = self.viewController.recipes;
  NSUInteger beefRecipeIndex = [recipes indexOfObjectPassingTest:^BOOL(OnboardingRecipePreview *recipe, NSUInteger idx, BOOL *stop) {
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

  NSArray<OnboardingRecipePreview *> *recipes = self.viewController.recipes;
  OnboardingRecipePreview *defaultRecipe = recipes.firstObject;
  NSUInteger beefRecipeIndex = [recipes indexOfObjectPassingTest:^BOOL(OnboardingRecipePreview *recipe, NSUInteger idx, BOOL *stop) {
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

  OnboardingRecipePreview *firstRecipe = self.viewController.recipes.firstObject;
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
  CGFloat expectedScale = UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.97;

  [self.viewController handlePressableButtonTouchDown:emailButton];
  XCTAssertEqualWithAccuracy(emailButton.transform.a, expectedScale, 0.001);
  XCTAssertEqualWithAccuracy(emailButton.transform.d, expectedScale, 0.001);
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
  CGFloat expectedScale = UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.97;

  [self.viewController handlePressableButtonTouchDown:signinButton];
  XCTAssertEqualWithAccuracy(signinButton.transform.a, expectedScale, 0.001);
  XCTAssertEqualWithAccuracy(signinButton.transform.d, expectedScale, 0.001);
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
    @"onboarding.recipeDetail.heroImageView", @"onboarding.recipeDetail.subtitleLabel", @"onboarding.recipeDetail.titleLabel",
    @"onboarding.recipeDetail.durationChip", @"onboarding.recipeDetail.calorieChip", @"onboarding.recipeDetail.servingsChip",
    @"onboarding.recipeDetail.summaryLabel", @"onboarding.recipeDetail.ingredientsTitleLabel", @"onboarding.recipeDetail.ingredientsHeaderButton",
    @"onboarding.recipeDetail.ingredientChip.1", @"onboarding.recipeDetail.instructionsTitleLabel",
    @"onboarding.recipeDetail.instructionsIconView", @"onboarding.recipeDetail.instructionsHeaderButton",
    @"onboarding.recipeDetail.instructionRow.1.indexLabel",
    @"onboarding.recipeDetail.instructionRow.1.titleLabel", @"onboarding.recipeDetail.instructionRow.1.bodyLabel",
    @"onboarding.recipeDetail.startCookingButton"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:[self presentedRecipeDetailRootView]], @"Missing %@",
                    identifier);
  }

  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:[self presentedRecipeDetailRootView]]);
  XCTAssertNil([self presentedRecipeDetailViewController].navigationItem.leftBarButtonItem);
}

- (void)testStartCookingMarksOnboardingCompletedAndDismissesDetail {
  [self presentFirstRecipe];

  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton"
                                                                         inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(startButton);

  [startButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self waitForCondition:^BOOL {
    return self.viewController.presentedViewController == nil;
  }
               timeout:1.0];

  XCTAssertTrue([self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey]);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testClosingDetailDoesNotMarkOnboardingCompleted {
  [self presentFirstRecipe];
  [[self presentedRecipeDetailViewController] didTapCloseButton];
  [self waitForCondition:^BOOL {
    return self.viewController.presentedViewController == nil;
  }
               timeout:1.0];

  XCTAssertFalse([self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey]);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)testRecipeDetailStartButtonShowsPressedFeedbackAndResets {
  [self presentFirstRecipe];

  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton"
                                                                         inView:[self presentedRecipeDetailRootView]];
  XCTAssertNotNil(startButton);

  BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
  [UIView setAnimationsEnabled:NO];
  CGFloat expectedScale = UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.97;

  OnboardingRecipeDetailViewController *detailViewController = [self presentedRecipeDetailViewController];
  [detailViewController handlePressableButtonTouchDown:startButton];
  XCTAssertEqualWithAccuracy(startButton.transform.a, expectedScale, 0.001);
  XCTAssertEqualWithAccuracy(startButton.transform.d, expectedScale, 0.001);
  XCTAssertEqualWithAccuracy(startButton.alpha, 0.88, 0.001);

  [detailViewController handlePressableButtonTouchUp:startButton];
  XCTAssertEqualWithAccuracy(startButton.transform.a, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(startButton.transform.d, 1.0, 0.001);
  XCTAssertEqualWithAccuracy(startButton.alpha, 1.0, 0.001);

  [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)testRecipeDetailFavoriteButtonKeepsStableWidthAcrossSavedStates {
  OnboardingRecipePreview *preview = self.viewController.recipes.firstObject;
  OnboardingRecipeDetailViewController *detailViewController =
      [[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:preview recipeDetail:preview.fallbackDetail];
  detailViewController.showsFavoriteButton = YES;

  UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
  navigationController.modalPresentationStyle = UIModalPresentationFullScreen;

  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController = navigationController;
  [window makeKeyAndVisible];
  [navigationController loadViewIfNeeded];
  [detailViewController loadViewIfNeeded];
  [detailViewController.view layoutIfNeeded];

  UIButton *favoriteButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.favoriteButton" inView:detailViewController.view];
  XCTAssertNotNil(favoriteButton);
  XCTAssertEqualObjects([self displayedTitleForButton:favoriteButton], @"Save");
  XCTAssertFalse(favoriteButton.adjustsImageWhenDisabled);

  CGFloat initialWidth = CGRectGetWidth(favoriteButton.bounds);

  detailViewController.favoriteButtonEnabled = NO;
  [detailViewController.view layoutIfNeeded];
  XCTAssertEqualWithAccuracy(favoriteButton.alpha, 0.58, 0.001);

  detailViewController.favoriteSelected = YES;
  UIButton *rerenderedFavoriteButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.favoriteButton" inView:detailViewController.view];
  XCTAssertNotNil(rerenderedFavoriteButton);
  XCTAssertTrue(favoriteButton != rerenderedFavoriteButton);
  XCTAssertFalse(rerenderedFavoriteButton.enabled);
  XCTAssertEqualObjects([rerenderedFavoriteButton titleForState:UIControlStateNormal], @"Saved");
  XCTAssertEqualObjects([rerenderedFavoriteButton titleForState:UIControlStateDisabled], @"Saved");

  detailViewController.favoriteButtonEnabled = YES;
  [detailViewController.view layoutIfNeeded];

  XCTAssertEqualWithAccuracy(CGRectGetWidth(rerenderedFavoriteButton.bounds), initialWidth, 0.5);
  XCTAssertTrue(rerenderedFavoriteButton.enabled);

  window.hidden = YES;
}

- (void)testRecipeDetailPresentationUsesSheetWrapperOnModernOS {
  if (@available(iOS 15.0, *)) {
    [self presentFirstRecipe];

    UIViewController *containerViewController = [self presentedRecipeContainerViewController];
    XCTAssertTrue([containerViewController isKindOfClass:[UINavigationController class]]);

    UINavigationController *navigationController = (UINavigationController *)containerViewController;
    XCTAssertEqual(navigationController.modalPresentationStyle, UIModalPresentationPageSheet);
    if (navigationController.sheetPresentationController != nil) {
      XCTAssertTrue(navigationController.sheetPresentationController.prefersGrabberVisible);
    }
    XCTAssertTrue(navigationController.isNavigationBarHidden);
    XCTAssertNil([self presentedRecipeDetailViewController].navigationItem.leftBarButtonItem);
    XCTAssertNil([self presentedRecipeDetailViewController].title);
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:[self presentedRecipeDetailRootView]]);
  } else {
    return;
  }
}

- (void)testRecipeDetailLegacyControllerBuildsCustomCloseChromeWhenNotWrapped {
  OnboardingRecipeDetailViewController *detailViewController =
      [[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:self.viewController.recipes.firstObject
                                                              recipeDetail:self.viewController.recipes.firstObject.fallbackDetail];
  [detailViewController loadViewIfNeeded];

  XCTAssertNil(detailViewController.navigationItem.leftBarButtonItem);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:detailViewController.view]);
}

- (void)testRecipeDetailSheetControllerUsesHeroCloseChromeWhenWrapped {
  if (@available(iOS 15.0, *)) {
    OnboardingRecipeDetailViewController *detailViewController =
        [[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:self.viewController.recipes.firstObject
                                                                recipeDetail:self.viewController.recipes.firstObject.fallbackDetail];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;

    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = navigationController;
    [window makeKeyAndVisible];
    [detailViewController loadViewIfNeeded];
    [detailViewController viewWillAppear:NO];

    XCTAssertNil(detailViewController.title);
    XCTAssertNil(detailViewController.navigationItem.leftBarButtonItem);
    XCTAssertTrue(navigationController.isNavigationBarHidden);
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton" inView:detailViewController.view]);

    window.hidden = YES;
  } else {
    return;
  }
}

- (void)testSelectingRecipeDoesNotRepositionPrimaryCarouselBeforePresentingDetail {
  [self layoutOnboardingForWindowSize:CGSizeMake(390.0, 844.0)];
  [self.viewController.carouselCollectionView layoutIfNeeded];
  [self spinMainRunLoop];

  NSInteger visibleIndex = [self.viewController middleCarouselItemIndexForRecipeIndex:4];
  CGFloat initialOffset = [self.viewController contentOffsetXForCarouselItemIndex:visibleIndex];
  [self.viewController.carouselCollectionView setContentOffset:CGPointMake(initialOffset, 0.0) animated:NO];
  self.viewController.currentCarouselItemIndex = visibleIndex;
  self.viewController.currentRecipeIndex = 4;

  NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:selectedIndexPath];
  [self spinMainRunLoop];

  XCTAssertEqualWithAccuracy(self.viewController.carouselCollectionView.contentOffset.x, initialOffset, 0.5);
  XCTAssertNotNil([self presentedRecipeContainerViewController]);
}

- (void)presentFirstRecipe {
  [self presentRecipeAtIndex:0 fromCollectionView:self.viewController.carouselCollectionView];
}

- (void)presentRecipeAtIndex:(NSInteger)index fromCollectionView:(UICollectionView *)collectionView {
  XCTAssertNotNil(collectionView, @"Carousel collection view is required for this helper.");
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
  [self.viewController collectionView:collectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];
}

- (NSArray<UICollectionView *> *)carouselCollectionViews {
  NSMutableArray<UICollectionView *> *collectionViews = [NSMutableArray array];

  UICollectionView *primary = self.viewController.carouselCollectionView;
  if (primary != nil) {
    [collectionViews addObject:primary];
  }

  UICollectionView *secondary = [self secondaryCarouselCollectionViewIfAvailable];
  if (secondary != nil && ![collectionViews containsObject:secondary]) {
    [collectionViews addObject:secondary];
  }

  return collectionViews;
}

- (UICollectionView *)secondaryCarouselCollectionViewIfAvailable {
  if (![self.viewController respondsToSelector:@selector(secondaryCarouselCollectionView)]) {
    return nil;
  }

  return [self.viewController secondaryCarouselCollectionView];
}

- (BOOL)isSecondaryCarouselCollectionViewAvailable {
  return [self secondaryCarouselCollectionViewIfAvailable] != nil;
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
    CGFloat carouselWidth = CGRectGetWidth([self frameForAccessibilityIdentifier:@"onboarding.heroCarouselContainerView"]);
    CGFloat carouselHeight = CGRectGetHeight(self.viewController.carouselCollectionView.bounds);

    XCTAssertGreaterThanOrEqual(layout.itemSize.width, 80.0, @"%.0fx%.0f should keep a readable card width", viewportSize.width,
                                viewportSize.height);
    XCTAssertLessThanOrEqual(layout.itemSize.width, ((carouselWidth - (layout.minimumLineSpacing * 2.2)) / 3.2) + 0.5,
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
  XCTAssertGreaterThan(expandedMetrics[@"heroHeight"].doubleValue, compactMetrics[@"heroHeight"].doubleValue);
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
    @"horizontalInset" : @(CGRectGetMinX([self frameForAccessibilityIdentifier:@"onboarding.heroCarouselContainerView"])),
    @"stackSpacing" : @(self.viewController.contentStackView.spacing),
    @"carouselItemWidth" : @(layout.itemSize.width),
    @"carouselItemHeight" : @(layout.itemSize.height),
    @"buttonHeight" : @(CGRectGetHeight([self frameForAccessibilityIdentifier:@"onboarding.emailButton"])),
    @"carouselCellTitleFontSize" : @([self visibleCarouselLabelFontSizeWithSuffix:@".titleLabel"]),
    @"carouselCellMetadataFontSize" : @([self visibleCarouselLabelFontSizeWithSuffix:@".metadataLabel"])
  };
}

- (NSDictionary<NSString *, NSNumber *> *)currentRecipeDetailMetrics {
  UIView *detailRootView = [self presentedRecipeDetailRootView];
  UILabel *titleLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.titleLabel" inView:detailRootView];
  UIImageView *heroImageView =
      (UIImageView *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.heroImageView" inView:detailRootView];
  UIButton *startButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton" inView:detailRootView];

  XCTAssertNotNil(titleLabel);
  XCTAssertNotNil(heroImageView);
  XCTAssertNotNil(startButton);

  return @{
    @"titleFontSize" : @(titleLabel.font.pointSize),
    @"heroHeight" : @(CGRectGetHeight([heroImageView convertRect:heroImageView.bounds toView:detailRootView])),
    @"startButtonHeight" : @(CGRectGetHeight([startButton convertRect:startButton.bounds toView:detailRootView])),
  };
}

- (CGFloat)visibleCarouselLabelFontSizeWithSuffix:(NSString *)suffix {
  for (UICollectionView *carousel in [self carouselCollectionViews]) {
    UIView *labelView = [self findViewWithAccessibilitySuffix:suffix inView:carousel];
    if (labelView == nil) {
      continue;
    }

    XCTAssertTrue([labelView isKindOfClass:[UILabel class]], @"%@ should resolve to a label", suffix);
    return ((UILabel *)labelView).font.pointSize;
  }

  XCTFail(@"Missing visible carousel label ending with %@", suffix);
  return 0.0;
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

- (NSString *)displayedTitleForButton:(UIButton *)button {
  if (@available(iOS 15.0, *)) {
    if (button.configuration.attributedTitle.length > 0) {
      return button.configuration.attributedTitle.string;
    }
    if (button.configuration.title.length > 0) {
      return button.configuration.title;
    }
  }

  return [button titleForState:UIControlStateNormal];
}

- (UIImage *)displayedImageForButton:(UIButton *)button {
  if (@available(iOS 15.0, *)) {
    if (button.configuration.image != nil) {
      return button.configuration.image;
    }
  }

  return [button imageForState:UIControlStateNormal];
}

- (UIViewController *)presentedRecipeContainerViewController {
  return self.viewController.presentedViewController;
}

- (OnboardingRecipeDetailViewController *)presentedRecipeDetailViewController {
  UIViewController *presentedViewController = [self presentedRecipeContainerViewController];
  XCTAssertNotNil(presentedViewController);

  if ([presentedViewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController = (UINavigationController *)presentedViewController;
    XCTAssertTrue([navigationController.topViewController isKindOfClass:[OnboardingRecipeDetailViewController class]]);
    OnboardingRecipeDetailViewController *detailViewController =
        (OnboardingRecipeDetailViewController *)navigationController.topViewController;
    [detailViewController loadViewIfNeeded];
    return detailViewController;
  }

  XCTAssertTrue([presentedViewController isKindOfClass:[OnboardingRecipeDetailViewController class]]);
  OnboardingRecipeDetailViewController *detailViewController = (OnboardingRecipeDetailViewController *)presentedViewController;
  [detailViewController loadViewIfNeeded];
  return detailViewController;
}

- (UIView *)presentedRecipeDetailRootView {
  return [self presentedRecipeDetailViewController].view;
}

- (NSDictionary<NSString *, NSNumber *> *)adaptiveMetricsForWindowSize:(CGSize)size {
  UIWindow *previousWindow = self.window;
  OnboardingViewController *previousViewController = self.viewController;

  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
  OnboardingViewController *viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController
                                                                             authenticationController:self.authenticationController
                                                                                         recipeCatalog:self.recipeCatalog];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];

  self.window = window;
  self.viewController = viewController;
  [self.viewController loadViewIfNeeded];
  [self layoutOnboardingForWindowSize:size];

  NSDictionary<NSString *, NSNumber *> *metrics = [[self currentAdaptiveOnboardingMetrics] copy];

  [self.viewController pauseCarouselAutoscroll];
  window.hidden = YES;
  self.window = previousWindow;
  self.viewController = previousViewController;

  return metrics;
}

- (NSDictionary<NSString *, NSNumber *> *)recipeDetailMetricsForWindowSize:(CGSize)size {
  UIWindow *previousWindow = self.window;
  OnboardingViewController *previousViewController = self.viewController;

  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
  OnboardingViewController *viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController
                                                                             authenticationController:self.authenticationController
                                                                                         recipeCatalog:self.recipeCatalog];
  window.rootViewController = viewController;
  [window makeKeyAndVisible];

  self.window = window;
  self.viewController = viewController;
  [self.viewController loadViewIfNeeded];
  [self layoutOnboardingForWindowSize:size];
  [self presentFirstRecipe];
  [[self presentedRecipeContainerViewController].view setNeedsLayout];
  [[self presentedRecipeContainerViewController].view layoutIfNeeded];
  [[self presentedRecipeDetailRootView] setNeedsLayout];
  [[self presentedRecipeDetailRootView] layoutIfNeeded];
  [self spinMainRunLoop];

  NSDictionary<NSString *, NSNumber *> *metrics = [[self currentRecipeDetailMetrics] copy];

  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  [self.viewController pauseCarouselAutoscroll];
  window.hidden = YES;
  self.window = previousWindow;
  self.viewController = previousViewController;

  return metrics;
}

- (void)spinMainRunLoop {
  [self spinMainRunLoopForInterval:0.15];
}

- (void)spinMainRunLoopForInterval:(NSTimeInterval)interval {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

- (void)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (condition != nil && !condition() && [deadline timeIntervalSinceNow] > 0.0) {
    [self spinMainRunLoop];
  }
}

@end
