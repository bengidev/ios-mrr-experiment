#import "OnboardingViewController.h"

#include <math.h>

#import "../../Data/OnboardingStateController.h"
#import "../Views/OnboardingRecipeCarouselCell.h"
#import "OnboardingRecipeDetailViewController.h"

static NSString *const MRRRecipeCarouselCellReuseIdentifier = @"MRRRecipeCarouselCell";
static NSInteger const MRRCarouselLoopMultiplier = 5;

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

@interface OnboardingViewController ()
    <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate,
     OnboardingRecipeDetailViewControllerDelegate>

@property(nonatomic, retain) OnboardingStateController *stateController;
@property(nonatomic, copy) NSArray<OnboardingRecipe *> *recipes;
@property(nonatomic, retain) UICollectionView *carouselCollectionView;
@property(nonatomic, retain) UIPageControl *pageControl;
@property(nonatomic, retain) NSTimer *carouselTimer;
@property(nonatomic, assign) NSInteger currentRecipeIndex;
@property(nonatomic, assign) NSInteger currentCarouselItemIndex;
@property(nonatomic, assign, getter=isDetailPresented) BOOL detailPresented;
@property(nonatomic, assign, getter=isViewVisible) BOOL viewVisible;

- (NSArray<OnboardingRecipe *> *)loadRecipes;
- (void)buildViewHierarchy;
- (UIView *)badgeViewWithText:(NSString *)text
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              labelIdentifier:(NSString *)labelIdentifier;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UICollectionViewFlowLayout *)carouselLayout;
- (void)updateCarouselLayoutIfNeeded;
- (NSInteger)virtualCarouselItemCount;
- (NSInteger)recipeIndexForCarouselItemIndex:(NSInteger)itemIndex;
- (NSInteger)middleCarouselItemIndexForRecipeIndex:(NSInteger)recipeIndex;
- (NSInteger)carouselItemIndexForRecipeIndex:(NSInteger)recipeIndex nearCarouselItemIndex:(NSInteger)referenceIndex;
- (NSInteger)nearestCarouselItemIndexForOffsetX:(CGFloat)offsetX;
- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex;
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
  return [self initWithStateController:stateController];
}

- (instancetype)initWithStateController:(OnboardingStateController *)stateController {
  NSParameterAssert(stateController != nil);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _stateController = [stateController retain];
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
  _carouselCollectionView.delegate = nil;
  _carouselCollectionView.dataSource = nil;
  [_carouselCollectionView release];
  [_pageControl release];
  [_recipes release];
  [_stateController release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"Onboarding";
  self.view.backgroundColor = MRRNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0],
                                            [UIColor colorWithWhite:0.07 alpha:1.0]);
  self.view.tintColor = MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                      [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  self.view.accessibilityIdentifier = @"onboarding.view";

  [self buildViewHierarchy];
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
  [self updateCarouselLayoutIfNeeded];
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
  [self.view addSubview:scrollView];

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];

  UIStackView *stackView = [[[UIStackView alloc] init] autorelease];
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 18.0;
  [contentView addSubview:stackView];

  [stackView addArrangedSubview:[self badgeViewWithText:@"CURATED RECIPE ONBOARDING"
                                accessibilityIdentifier:nil
                                        labelIdentifier:@"onboarding.badgeLabel"]];

  UILabel *titleLabel = [self labelWithText:@"Culina"
                                       font:[UIFont boldSystemFontOfSize:42.0]
                                      color:MRRNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.08 alpha:1.0],
                                                          [UIColor colorWithWhite:0.96 alpha:1.0])];
  titleLabel.accessibilityIdentifier = @"onboarding.titleLabel";
  [stackView addArrangedSubview:titleLabel];

  UILabel *subtitleLabel =
      [self labelWithText:@"Swipe through a live recipe carousel, open any dish, and finish onboarding when you are ready to cook."
                    font:[UIFont systemFontOfSize:18.0]
                   color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                       [UIColor colorWithWhite:0.70 alpha:1.0])];
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.accessibilityIdentifier = @"onboarding.subtitleLabel";
  [stackView addArrangedSubview:subtitleLabel];

  UILabel *captionLabel = [self labelWithText:@"Recipe carousel"
                                         font:[UIFont boldSystemFontOfSize:16.0]
                                        color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  captionLabel.accessibilityIdentifier = @"onboarding.carouselCaptionLabel";
  [stackView addArrangedSubview:captionLabel];

  UILabel *helperLabel = [self labelWithText:@"Auto-scroll keeps moving until you interact. Tap a card to inspect ingredients, steps, and the Start Cooking finish action."
                                        font:[UIFont systemFontOfSize:15.0]
                                       color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                           [UIColor colorWithWhite:0.70 alpha:1.0])];
  helperLabel.numberOfLines = 0;
  helperLabel.accessibilityIdentifier = @"onboarding.carouselHelperLabel";
  [stackView addArrangedSubview:helperLabel];

  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.minimumLineSpacing = 16.0;
  layout.sectionInset = UIEdgeInsetsMake(0.0, 24.0, 0.0, 24.0);

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.showsHorizontalScrollIndicator = NO;
  collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
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
  pageControl.accessibilityIdentifier = @"onboarding.pageControl";
  pageControl.currentPageIndicatorTintColor =
      MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                    [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
  pageControl.pageIndicatorTintColor = [MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                      [UIColor colorWithWhite:0.70 alpha:1.0]) colorWithAlphaComponent:0.24];
  [stackView addArrangedSubview:pageControl];
  self.pageControl = pageControl;

  UILabel *footerLabel = [self labelWithText:@"Onboarding completes only after you tap Start Cooking inside a recipe detail card."
                                        font:[UIFont systemFontOfSize:15.0]
                                       color:MRRNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.40 alpha:1.0],
                                                           [UIColor colorWithWhite:0.70 alpha:1.0])];
  footerLabel.numberOfLines = 0;
  footerLabel.accessibilityIdentifier = @"onboarding.footerLabel";
  [stackView addArrangedSubview:footerLabel];

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

    [stackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:28.0],
    [stackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [stackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [stackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30.0],

    [collectionView.heightAnchor constraintEqualToConstant:360.0]
  ]];
}

- (UIView *)badgeViewWithText:(NSString *)text
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              labelIdentifier:(NSString *)labelIdentifier {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.accessibilityIdentifier = accessibilityIdentifier;
  containerView.backgroundColor = [MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                 [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]) colorWithAlphaComponent:0.12];
  containerView.layer.cornerRadius = 16.0;

  UILabel *label = [self labelWithText:text
                                  font:[UIFont boldSystemFontOfSize:12.0]
                                 color:MRRNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                                     [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0])];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.accessibilityIdentifier = labelIdentifier;
  [containerView addSubview:label];

  [NSLayoutConstraint activateConstraints:@[
    [label.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:10.0],
    [label.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:14.0],
    [label.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-14.0],
    [label.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-10.0]
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
  UICollectionViewFlowLayout *layout = [self carouselLayout];
  CGFloat pageWidth = layout.itemSize.width + layout.minimumLineSpacing;
  if (pageWidth <= 0.0) {
    return 0;
  }

  NSInteger index = (NSInteger)llround((offsetX + layout.sectionInset.left) / pageWidth);
  NSInteger maxIndex = MAX([self virtualCarouselItemCount] - 1, 0);
  return MIN(MAX(index, 0), maxIndex);
}

- (CGFloat)contentOffsetXForCarouselItemIndex:(NSInteger)itemIndex {
  UICollectionViewFlowLayout *layout = [self carouselLayout];
  CGFloat pageWidth = layout.itemSize.width + layout.minimumLineSpacing;
  if (pageWidth <= 0.0) {
    return 0.0;
  }

  return MAX((itemIndex * pageWidth) - layout.sectionInset.left, 0.0);
}

- (void)updateCarouselLayoutIfNeeded {
  UICollectionViewFlowLayout *layout = [self carouselLayout];
  CGFloat desiredWidth = MAX(CGRectGetWidth(self.carouselCollectionView.bounds) - 72.0, 240.0);
  CGFloat desiredHeight = MAX(CGRectGetHeight(self.carouselCollectionView.bounds) - 12.0, 320.0);

  if (fabs(layout.itemSize.width - desiredWidth) < 0.5 && fabs(layout.itemSize.height - desiredHeight) < 0.5) {
    return;
  }

  layout.itemSize = CGSizeMake(desiredWidth, desiredHeight);
  [layout invalidateLayout];
  [self.carouselCollectionView layoutIfNeeded];
  [self scrollToRecipeAtIndex:self.currentRecipeIndex animated:NO];
}

- (void)scrollToCarouselItemAtIndex:(NSInteger)itemIndex animated:(BOOL)animated {
  NSInteger totalItemCount = [self virtualCarouselItemCount];
  if (itemIndex < 0 || itemIndex >= totalItemCount) {
    return;
  }

  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
  [self.carouselCollectionView scrollToItemAtIndexPath:indexPath
                                      atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
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
  [self.carouselCollectionView setContentOffset:CGPointMake([self contentOffsetXForCarouselItemIndex:recenteredItemIndex],
                                                            self.carouselCollectionView.contentOffset.y)
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
  if (!self.isViewVisible || self.isDetailPresented || self.carouselTimer != nil || self.recipes.count < 2 ||
      self.carouselCollectionView.dragging || self.carouselCollectionView.decelerating) {
    return;
  }

  self.carouselTimer = [NSTimer scheduledTimerWithTimeInterval:3.6
                                                        target:self
                                                      selector:@selector(handleCarouselTimer:)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)handleCarouselTimer:(NSTimer *)timer {
  if (self.recipes.count < 2 || self.isDetailPresented) {
    return;
  }

  NSInteger nextItemIndex = self.currentCarouselItemIndex + 1;
  if (nextItemIndex >= [self virtualCarouselItemCount]) {
    nextItemIndex = [self middleCarouselItemIndexForRecipeIndex:self.currentRecipeIndex];
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

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  OnboardingRecipeCarouselCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:MRRRecipeCarouselCellReuseIdentifier forIndexPath:indexPath];
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

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
  if (scrollView != self.carouselCollectionView) {
    return;
  }

  UICollectionViewFlowLayout *layout = [self carouselLayout];
  CGFloat pageWidth = layout.itemSize.width + layout.minimumLineSpacing;
  NSInteger targetItemIndex = [self nearestCarouselItemIndexForOffsetX:targetContentOffset->x];
  targetContentOffset->x = MAX((targetItemIndex * pageWidth) - layout.sectionInset.left, 0.0);
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
  [self dismissViewControllerAnimated:[self shouldAnimateModalTransitions]
                           completion:^{
                             [self.delegate onboardingViewControllerDidFinish:self];
                           }];
}

@end
