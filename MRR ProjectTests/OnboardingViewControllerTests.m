#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"
#import "../MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h"

@interface OnboardingViewController (Testing) <UICollectionViewDelegate>

@property(nonatomic, readonly) UICollectionView *carouselCollectionView;

@end

@interface OnboardingViewControllerDelegateSpy : NSObject <OnboardingViewControllerDelegate>

@property(nonatomic, assign) BOOL didFinishOnboarding;

@end

@implementation OnboardingViewControllerDelegateSpy

- (void)onboardingViewControllerDidFinish:(OnboardingViewController *)viewController {
  self.didFinishOnboarding = YES;
}

@end

@interface OnboardingViewControllerTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) OnboardingStateController *stateController;
@property(nonatomic, strong) OnboardingViewController *viewController;
@property(nonatomic, strong) OnboardingViewControllerDelegateSpy *delegateSpy;
@property(nonatomic, strong) UIWindow *window;

@end

@implementation OnboardingViewControllerTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"OnboardingViewControllerTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.stateController = [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
  self.viewController = [[OnboardingViewController alloc] initWithStateController:self.stateController];
  self.delegateSpy = [[OnboardingViewControllerDelegateSpy alloc] init];
  self.viewController.delegate = self.delegateSpy;
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
  self.delegateSpy = nil;
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

- (void)testOnboardingExposesCoreAccessibilityIdentifiers {
  NSArray<NSString *> *identifiers = @[
    @"onboarding.titleLabel",
    @"onboarding.badgeLabel",
    @"onboarding.subtitleLabel",
    @"onboarding.carouselCaptionLabel",
    @"onboarding.carouselHelperLabel",
    @"onboarding.carouselCollectionView",
    @"onboarding.pageControl",
    @"onboarding.footerLabel"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier inView:self.viewController.view], @"Missing %@", identifier);
  }

  OnboardingRecipe *firstRecipe = [self.stateController onboardingRecipes].firstObject;
  NSString *carouselTitleIdentifier = [NSString stringWithFormat:@"onboarding.carouselCell.%@.titleLabel", firstRecipe.assetName];
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:carouselTitleIdentifier inView:self.viewController.view]);
}

- (void)testRecipeDetailExposesCoreAccessibilityIdentifiers {
  [self presentFirstRecipe];

  NSArray<NSString *> *identifiers = @[
    @"onboarding.recipeDetail.heroImageView",
    @"onboarding.recipeDetail.closeButton",
    @"onboarding.recipeDetail.subtitleLabel",
    @"onboarding.recipeDetail.titleLabel",
    @"onboarding.recipeDetail.durationChip",
    @"onboarding.recipeDetail.calorieChip",
    @"onboarding.recipeDetail.servingsChip",
    @"onboarding.recipeDetail.summaryLabel",
    @"onboarding.recipeDetail.ingredientsTitleLabel",
    @"onboarding.recipeDetail.ingredientChip.1",
    @"onboarding.recipeDetail.instructionsTitleLabel",
    @"onboarding.recipeDetail.instructionRow.1.indexLabel",
    @"onboarding.recipeDetail.instructionRow.1.titleLabel",
    @"onboarding.recipeDetail.instructionRow.1.bodyLabel",
    @"onboarding.recipeDetail.startCookingButton"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertNotNil([self findViewWithAccessibilityIdentifier:identifier
                                                       inView:self.viewController.presentedViewController.view],
                    @"Missing %@", identifier);
  }
}

- (void)testStartCookingInvokesFinishDelegate {
  [self presentFirstRecipe];

  UIButton *startButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.startCookingButton"
                                                     inView:self.viewController.presentedViewController.view];
  XCTAssertNotNil(startButton);

  [startButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue(self.delegateSpy.didFinishOnboarding);
}

- (void)testClosingDetailDoesNotInvokeFinishDelegate {
  [self presentFirstRecipe];

  UIButton *closeButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"onboarding.recipeDetail.closeButton"
                                                     inView:self.viewController.presentedViewController.view];
  XCTAssertNotNil(closeButton);

  [closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertFalse(self.delegateSpy.didFinishOnboarding);
  XCTAssertNil(self.viewController.presentedViewController);
}

- (void)presentFirstRecipe {
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  [self.viewController collectionView:self.viewController.carouselCollectionView didSelectItemAtIndexPath:indexPath];
  [self spinMainRunLoop];
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

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
