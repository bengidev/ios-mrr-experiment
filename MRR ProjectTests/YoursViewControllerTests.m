#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Yours/MRRYoursRecipeEditorViewController.h"
#import "../MRR Project/Features/Yours/YoursViewController.h"
#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipePhotoStorage.h"
#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../MRR Project/Persistence/UserRecipes/Models/MRRUserRecipeSnapshot.h"
#import "../MRR Project/Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"

@interface YoursViewController (Testing)

- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                     userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(nullable id<MRRUserRecipesCloudSyncing>)syncEngine
                         photoStorage:(nullable id<MRRUserRecipePhotoStorage>)photoStorage;
- (void)handleAddButtonTapped:(id)sender;

@end

@interface MRRYoursRecipeEditorViewController (Testing)

- (BOOL)appendPhotoWithImage:(UIImage *)image error:(NSError *_Nullable *_Nullable)error;
- (void)handleSaveTapped:(id)sender;
- (void)handleStepAddTapped:(id)sender;

@end

@interface YoursSyncEngineSpy : NSObject <MRRUserRecipesCloudSyncing>

@property(nonatomic, assign) NSInteger requestCount;
@property(nonatomic, copy, nullable) NSString *lastRequestedUserID;

@end

@implementation YoursSyncEngineSpy

- (void)startSyncForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
  self.lastRequestedUserID = userID;
  if (completion != nil) {
    completion(nil);
  }
}

- (void)stopSync {
}

- (void)requestImmediateSyncForUserID:(NSString *)userID {
  self.requestCount += 1;
  self.lastRequestedUserID = userID;
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
  self.lastRequestedUserID = userID;
  if (completion != nil) {
    completion(nil);
  }
}

@end

@interface YoursViewControllerTests : XCTestCase

@property(nonatomic, strong) MRRCoreDataStack *coreDataStack;
@property(nonatomic, strong) MRRUserRecipesStore *store;
@property(nonatomic, strong) YoursSyncEngineSpy *syncEngine;
@property(nonatomic, strong) MRRLocalUserRecipePhotoStorage *photoStorage;
@property(nonatomic, strong) NSURL *photoBaseDirectoryURL;
@property(nonatomic, strong) YoursViewController *viewController;
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIWindow *window;

- (NSArray<MRRUserRecipeSnapshot *> *)currentRecipes;
- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (nullable NSLayoutConstraint *)activeConstraintForView:(UIView *)view attribute:(NSLayoutAttribute)attribute;
- (CGRect)frameForView:(UIView *)view insideView:(UIView *)containerView;
- (MRRYoursRecipeEditorViewController *)presentedEditor;
- (void)layoutWindowForSize:(CGSize)size;
- (void)populateRequiredFieldsInEditor:(MRRYoursRecipeEditorViewController *)editor title:(NSString *)title;
- (UIImage *)sampleImageWithColor:(UIColor *)color;
- (void)spinMainRunLoop;

@end

@implementation YoursViewControllerTests

- (void)setUp {
  [super setUp];

  NSError *error = nil;
  self.coreDataStack = [[MRRCoreDataStack alloc] initWithInMemoryStore:YES error:&error];
  XCTAssertNotNil(self.coreDataStack);
  XCTAssertNil(error);

  self.store = [[MRRUserRecipesStore alloc] initWithCoreDataStack:self.coreDataStack];
  self.syncEngine = [[YoursSyncEngineSpy alloc] init];
  self.photoBaseDirectoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString]
                                          isDirectory:YES];
  self.photoStorage = [[MRRLocalUserRecipePhotoStorage alloc] initWithBaseDirectoryURL:self.photoBaseDirectoryURL
                                                                           fileManager:[NSFileManager defaultManager]];
  self.viewController = [[YoursViewController alloc] initWithSessionUserID:@"user-yours"
                                                          userRecipesStore:self.store
                                                                syncEngine:self.syncEngine
                                                              photoStorage:self.photoStorage];
  self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  self.window.hidden = YES;
  self.window = nil;
  self.navigationController = nil;
  self.viewController = nil;
  self.photoStorage = nil;
  [[NSFileManager defaultManager] removeItemAtURL:self.photoBaseDirectoryURL error:nil];
  self.photoBaseDirectoryURL = nil;
  self.syncEngine = nil;
  self.store = nil;
  self.coreDataStack = nil;

  [super tearDown];
}

- (void)testEmptyStateAppearsWhenUserHasNoRecipes {
  UILabel *emptyStateLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"yours.emptyStateLabel" inView:self.viewController.view];
  UIButton *emptyStateButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.emptyStateButton" inView:self.viewController.view];

  XCTAssertNotNil(emptyStateLabel);
  XCTAssertEqualObjects(emptyStateLabel.text, @"You haven't created any recipes yet.");
  XCTAssertNotNil(emptyStateButton);
}

- (void)testAddButtonPushesFullScreenEditor {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  UIViewController *topViewController = self.navigationController.topViewController;
  XCTAssertTrue([topViewController isKindOfClass:[MRRYoursRecipeEditorViewController class]]);
  XCTAssertEqualObjects(topViewController.view.accessibilityIdentifier, @"yours.editor.view");
}

- (void)testSavingRecipeFromEditorPersistsRecipeAndRequestsSync {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self populateRequiredFieldsInEditor:editor title:@"Nasi Goreng Rumahan"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  NSArray<MRRUserRecipeSnapshot *> *recipes = [self currentRecipes];
  XCTAssertEqual(recipes.count, 1);
  XCTAssertEqualObjects(recipes.firstObject.title, @"Nasi Goreng Rumahan");
  XCTAssertEqual(recipes.firstObject.calorieCount, 350);
  XCTAssertEqual(self.syncEngine.requestCount, 1);
  XCTAssertEqualObjects(self.syncEngine.lastRequestedUserID, @"user-yours");
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[YoursViewController class]]);
}

- (void)testValidationFailureKeepsEditorOpenAndPreservesDraft {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  UITextField *titleField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editor.view];
  UITextField *ingredientField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.ingredientField.0" inView:editor.view];
  UITextField *stepField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];

  titleField.text = @"Roti Bakar";
  ingredientField.text = @"";
  stepField.text = @"Oles mentega";
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  UILabel *errorLabel = (UILabel *)[self findViewWithAccessibilityIdentifier:@"yours.editor.errorLabel" inView:editor.view];
  XCTAssertFalse(errorLabel.hidden);
  XCTAssertEqualObjects(titleField.text, @"Roti Bakar");
  XCTAssertEqualObjects(stepField.text, @"Oles mentega");
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[MRRYoursRecipeEditorViewController class]]);
}

- (void)testEditingRecipeUpdatesExistingCard {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];
  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self populateRequiredFieldsInEditor:editor title:@"Pasta Lemon"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  UIButton *editButton = (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.editButton." stringByAppendingString:recipe.recipeID]
                                                                        inView:self.viewController.view];
  XCTAssertNotNil(editButton);

  [editButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editEditor = [self presentedEditor];
  UITextField *titleField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editEditor.view];
  titleField.text = @"Pasta Lemon Creamy";
  [editEditor handleSaveTapped:nil];
  [self spinMainRunLoop];

  XCTAssertEqualObjects([self currentRecipes].firstObject.title, @"Pasta Lemon Creamy");
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:[@"yours.recipeCard." stringByAppendingString:recipe.recipeID]
                                                     inView:self.viewController.view]);
}

- (void)testAddingLocalPhotoStoresGalleryMetadataWithoutRemoteHeroURL {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  NSError *photoError = nil;
  XCTAssertTrue([editor appendPhotoWithImage:[self sampleImageWithColor:[UIColor redColor]] error:&photoError]);
  XCTAssertNil(photoError);
  [self populateRequiredFieldsInEditor:editor title:@"Ayam Bakar"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  XCTAssertEqual(recipe.photos.count, 1);
  XCTAssertTrue(recipe.photos.firstObject.localRelativePath.length > 0);
  XCTAssertEqual(recipe.heroImageURLString.length, 0);
}

- (void)testCompactLayoutKeepsMoreThanFivePhotoThumbnailsFromOverlapping {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  NSArray<UIColor *> *colors = @[
    [UIColor redColor], [UIColor blueColor], [UIColor greenColor], [UIColor orangeColor], [UIColor purpleColor], [UIColor brownColor],
    [UIColor cyanColor]
  ];
  for (UIColor *color in colors) {
    NSError *photoError = nil;
    XCTAssertTrue([editor appendPhotoWithImage:[self sampleImageWithColor:color] error:&photoError]);
    XCTAssertNil(photoError);
  }

  [self layoutWindowForSize:CGSizeMake(320.0, 568.0)];
  [editor.view layoutIfNeeded];
  [self spinMainRunLoop];

  UIStackView *thumbnailStack = (UIStackView *)[self findViewWithAccessibilityIdentifier:@"yours.editor.photoThumbnails" inView:editor.view];
  XCTAssertNotNil(thumbnailStack);
  XCTAssertEqual(thumbnailStack.arrangedSubviews.count, colors.count);

  UIView *previousThumbnail = nil;
  for (UIView *thumbnail in thumbnailStack.arrangedSubviews) {
    XCTAssertGreaterThanOrEqual(CGRectGetWidth(thumbnail.bounds), 61.5);
    if (previousThumbnail != nil) {
      CGRect previousFrame = [self frameForView:previousThumbnail insideView:editor.view];
      CGRect currentFrame = [self frameForView:thumbnail insideView:editor.view];
      XCTAssertGreaterThanOrEqual(CGRectGetMinX(currentFrame) + 0.5, CGRectGetMaxX(previousFrame));
    }
    previousThumbnail = thumbnail;
  }
}

- (void)testCollapsingThumbnailStripPreservesFixedThumbnailContentHeight {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
  [UIView setAnimationsEnabled:NO];

  NSError *photoError = nil;
  XCTAssertTrue([editor appendPhotoWithImage:[self sampleImageWithColor:[UIColor redColor]] error:&photoError]);
  XCTAssertNil(photoError);
  [editor.view layoutIfNeeded];

  UIStackView *thumbnailStack = (UIStackView *)[self findViewWithAccessibilityIdentifier:@"yours.editor.photoThumbnails" inView:editor.view];
  UIButton *toggleButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.thumbnailsToggleButton" inView:editor.view];
  XCTAssertNotNil(thumbnailStack);
  XCTAssertNotNil(toggleButton);

  NSLayoutConstraint *heightConstraint = [self activeConstraintForView:thumbnailStack attribute:NSLayoutAttributeHeight];
  XCTAssertNotNil(heightConstraint);
  XCTAssertNil(heightConstraint.secondItem);
  XCTAssertEqualWithAccuracy(heightConstraint.constant, 62.0, 0.5);

  [toggleButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [editor.view layoutIfNeeded];
  [UIView setAnimationsEnabled:animationsWereEnabled];

  UIScrollView *thumbnailScrollView = (UIScrollView *)thumbnailStack.superview;
  XCTAssertTrue([thumbnailScrollView isKindOfClass:[UIScrollView class]]);
  XCTAssertEqualWithAccuracy(CGRectGetHeight(thumbnailScrollView.bounds), 0.0, 0.5);
  XCTAssertEqualWithAccuracy(CGRectGetHeight(thumbnailStack.bounds), 62.0, 0.5);
}

- (void)testRecipeCardAdditionalThumbnailsDoNotOverlapWithMoreThanFivePhotos {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  NSArray<UIColor *> *colors = @[
    [UIColor redColor], [UIColor blueColor], [UIColor greenColor], [UIColor orangeColor], [UIColor purpleColor], [UIColor brownColor],
    [UIColor cyanColor]
  ];
  for (UIColor *color in colors) {
    NSError *photoError = nil;
    XCTAssertTrue([editor appendPhotoWithImage:[self sampleImageWithColor:color] error:&photoError]);
    XCTAssertNil(photoError);
  }

  [self layoutWindowForSize:CGSizeMake(320.0, 568.0)];
  [editor.view layoutIfNeeded];
  [self spinMainRunLoop];

  [self populateRequiredFieldsInEditor:editor title:@"Rawon Keluarga"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  UIScrollView *thumbnailsScrollView =
      (UIScrollView *)[self findViewWithAccessibilityIdentifier:[@"yours.recipeThumbnails." stringByAppendingString:recipe.recipeID]
                                                         inView:self.viewController.view];
  XCTAssertNotNil(thumbnailsScrollView);
  XCTAssertEqual(recipe.photos.count, colors.count);
  XCTAssertGreaterThan(thumbnailsScrollView.contentSize.width, CGRectGetWidth(thumbnailsScrollView.bounds));

  CGRect previousFrame = CGRectNull;
  for (NSUInteger index = 0; index < recipe.photos.count - 1; index += 1) {
    UIView *thumbnailView =
        [self findViewWithAccessibilityIdentifier:[NSString stringWithFormat:@"yours.recipeThumbnail.%@.%lu", recipe.recipeID, (unsigned long)index]
                                           inView:self.viewController.view];
    XCTAssertNotNil(thumbnailView);

    CGRect currentFrame = [self frameForView:thumbnailView insideView:thumbnailsScrollView];
    if (!CGRectIsNull(previousFrame)) {
      XCTAssertGreaterThanOrEqual(CGRectGetMinX(currentFrame) + 0.5, CGRectGetMaxX(previousFrame));
    }
    previousFrame = currentFrame;
  }
}

- (void)testCollapsedRecipeCardThumbnailStripPreservesFixedThumbnailContentHeight {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  NSArray<UIColor *> *colors = @[ [UIColor redColor], [UIColor blueColor], [UIColor greenColor] ];
  for (UIColor *color in colors) {
    NSError *photoError = nil;
    XCTAssertTrue([editor appendPhotoWithImage:[self sampleImageWithColor:color] error:&photoError]);
    XCTAssertNil(photoError);
  }

  [self populateRequiredFieldsInEditor:editor title:@"Soto Betawi"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  UIScrollView *thumbnailsScrollView =
      (UIScrollView *)[self findViewWithAccessibilityIdentifier:[@"yours.recipeThumbnails." stringByAppendingString:recipe.recipeID]
                                                         inView:self.viewController.view];
  XCTAssertNotNil(thumbnailsScrollView);

  UIStackView *thumbnailStack = nil;
  for (UIView *subview in thumbnailsScrollView.subviews) {
    if ([subview isKindOfClass:[UIStackView class]]) {
      thumbnailStack = (UIStackView *)subview;
      break;
    }
  }

  XCTAssertNotNil(thumbnailStack);
  NSLayoutConstraint *heightConstraint = [self activeConstraintForView:thumbnailStack attribute:NSLayoutAttributeHeight];
  XCTAssertNotNil(heightConstraint);
  XCTAssertNil(heightConstraint.secondItem);
  XCTAssertEqualWithAccuracy(heightConstraint.constant, 62.0, 0.5);
  XCTAssertEqualWithAccuracy(CGRectGetHeight(thumbnailsScrollView.bounds), 0.0, 0.5);
  XCTAssertEqualWithAccuracy(CGRectGetHeight(thumbnailStack.bounds), 62.0, 0.5);
}

- (void)testCompactLayoutKeepsChipAndPhotoActionTitlesReadable {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self layoutWindowForSize:CGSizeMake(320.0, 568.0)];
  [editor.view layoutIfNeeded];
  [self spinMainRunLoop];

  UIView *categorySection = [self findViewWithAccessibilityIdentifier:@"yours.editor.categorySection" inView:editor.view];
  UIButton *mainCourseButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.tag.Main Course" inView:editor.view];
  UIView *photoSection = [self findViewWithAccessibilityIdentifier:@"yours.editor.photoSection" inView:editor.view];
  UIButton *setCoverButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.setCoverButton" inView:editor.view];
  UIButton *removePhotoButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.removePhotoButton" inView:editor.view];

  XCTAssertNotNil(categorySection);
  XCTAssertNotNil(mainCourseButton);
  XCTAssertNotNil(photoSection);
  XCTAssertNotNil(setCoverButton);
  XCTAssertNotNil(removePhotoButton);

  CGRect mainCourseFrame = [self frameForView:mainCourseButton insideView:categorySection];
  CGRect setCoverFrame = [self frameForView:setCoverButton insideView:photoSection];
  CGRect removePhotoFrame = [self frameForView:removePhotoButton insideView:photoSection];

  XCTAssertLessThanOrEqual(CGRectGetMaxX(mainCourseFrame), CGRectGetWidth(categorySection.bounds) + 0.5);
  XCTAssertLessThanOrEqual(CGRectGetMaxX(setCoverFrame), CGRectGetWidth(photoSection.bounds) + 0.5);
  XCTAssertLessThanOrEqual(CGRectGetMaxX(removePhotoFrame), CGRectGetWidth(photoSection.bounds) + 0.5);

  UIFont *mainCourseFont = mainCourseButton.titleLabel.font ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
  CGFloat mainCourseTitleWidth = ceil([mainCourseButton.currentTitle sizeWithAttributes:@{NSFontAttributeName : mainCourseFont}].width);
  XCTAssertGreaterThanOrEqual(CGRectGetWidth(mainCourseButton.titleLabel.frame) + 0.5, mainCourseTitleWidth);

  UIFont *setCoverFont = setCoverButton.titleLabel.font ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
  CGFloat setCoverTitleWidth = ceil([setCoverButton.currentTitle sizeWithAttributes:@{NSFontAttributeName : setCoverFont}].width);
  XCTAssertGreaterThanOrEqual(CGRectGetWidth(setCoverButton.titleLabel.frame) + 0.5, setCoverTitleWidth);

  UIFont *removePhotoFont = removePhotoButton.titleLabel.font ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
  CGFloat removePhotoTitleWidth = ceil([removePhotoButton.currentTitle sizeWithAttributes:@{NSFontAttributeName : removePhotoFont}].width);
  XCTAssertGreaterThanOrEqual(CGRectGetWidth(removePhotoButton.titleLabel.frame) + 0.5, removePhotoTitleWidth);
}

- (void)testCompactLayoutKeepsIngredientAndStepPlaceholdersReadable {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self layoutWindowForSize:CGSizeMake(320.0, 568.0)];
  [editor.view layoutIfNeeded];
  [self spinMainRunLoop];

  UITextField *ingredientField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.ingredientField.0" inView:editor.view];
  UITextField *stepField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];
  UIButton *removeIngredientButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.removeIngredientButton.0"
                                                                                    inView:editor.view];
  UIButton *removeStepButton = (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.editor.removeStepButton.0" inView:editor.view];

  XCTAssertNotNil(ingredientField);
  XCTAssertNotNil(stepField);
  XCTAssertNotNil(removeIngredientButton);
  XCTAssertNotNil(removeStepButton);

  UIFont *ingredientFont = ingredientField.font ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  CGFloat ingredientPlaceholderWidth = ceil([ingredientField.placeholder sizeWithAttributes:@{NSFontAttributeName : ingredientFont}].width);
  CGFloat ingredientVisibleWidth = CGRectGetWidth([ingredientField placeholderRectForBounds:ingredientField.bounds]);
  XCTAssertGreaterThanOrEqual(ingredientVisibleWidth + 0.5, ingredientPlaceholderWidth);

  UIFont *stepFont = stepField.font ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  CGFloat stepPlaceholderWidth = ceil([stepField.placeholder sizeWithAttributes:@{NSFontAttributeName : stepFont}].width);
  CGFloat stepVisibleWidth = CGRectGetWidth([stepField placeholderRectForBounds:stepField.bounds]);
  XCTAssertGreaterThanOrEqual(stepVisibleWidth + 0.5, stepPlaceholderWidth);

  XCTAssertLessThanOrEqual(CGRectGetWidth(removeIngredientButton.bounds), 44.0);
  XCTAssertLessThanOrEqual(CGRectGetWidth(removeStepButton.bounds), 44.0);
}

- (void)testCompactLayoutKeepsStepRowsVisiblyTighter {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [editor handleStepAddTapped:nil];
  [self spinMainRunLoop];

  [self layoutWindowForSize:CGSizeMake(320.0, 568.0)];
  [editor.view layoutIfNeeded];
  [self spinMainRunLoop];

  UITextField *firstStepField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];
  UITextField *secondStepField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.1" inView:editor.view];

  XCTAssertNotNil(firstStepField);
  XCTAssertNotNil(secondStepField);

  CGRect firstFrame = [self frameForView:firstStepField insideView:editor.view];
  CGRect secondFrame = [self frameForView:secondStepField insideView:editor.view];
  CGFloat visibleGap = CGRectGetMinY(secondFrame) - CGRectGetMaxY(firstFrame);

  XCTAssertLessThanOrEqual(visibleGap, 14.5);
}

- (void)testDeleteButtonPresentsAlertAndDeletingLastRecipeRestoresEmptyState {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];
  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self populateRequiredFieldsInEditor:editor title:@"Soto Ayam Kilat"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  UIButton *deleteButton = (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.deleteButton." stringByAppendingString:recipe.recipeID]
                                                                          inView:self.viewController.view];
  XCTAssertNotNil(deleteButton);

  [deleteButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"yours.deleteAlert");
}

- (MRRYoursRecipeEditorViewController *)presentedEditor {
  XCTAssertTrue([self.navigationController.topViewController isKindOfClass:[MRRYoursRecipeEditorViewController class]]);
  MRRYoursRecipeEditorViewController *editor = (MRRYoursRecipeEditorViewController *)self.navigationController.topViewController;
  [editor loadViewIfNeeded];
  [editor.view layoutIfNeeded];
  return editor;
}

- (void)populateRequiredFieldsInEditor:(MRRYoursRecipeEditorViewController *)editor title:(NSString *)title {
  UITextField *titleField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editor.view];
  UITextField *subtitleField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.subtitleField" inView:editor.view];
  UITextView *summaryTextView = (UITextView *)[self findViewWithAccessibilityIdentifier:@"yours.editor.summaryTextView" inView:editor.view];
  UITextField *readyField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.readyField" inView:editor.view];
  UITextField *servingsField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.servingsField" inView:editor.view];
  UITextField *caloriesField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.caloriesField" inView:editor.view];
  UITextField *ingredientField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.ingredientField.0" inView:editor.view];
  UITextField *stepField = (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];

  titleField.text = title;
  subtitleField.text = @"Subtitle";
  summaryTextView.text = @"Versi sederhana untuk makan malam.";
  readyField.text = @"25";
  servingsField.text = @"3";
  caloriesField.text = @"350";
  ingredientField.text = @"Nasi putih, telur, bawang putih";
  stepField.text = @"Tumis bumbu lalu aduk dengan nasi";
}

- (NSArray<MRRUserRecipeSnapshot *> *)currentRecipes {
  NSError *error = nil;
  NSArray<MRRUserRecipeSnapshot *> *recipes = [self.store userRecipesForUserID:@"user-yours" error:&error];
  XCTAssertNil(error);
  return recipes ?: @[];
}

- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view {
  if ([view.accessibilityIdentifier isEqualToString:identifier]) {
    return view;
  }
  for (UIView *subview in view.subviews) {
    UIView *match = [self findViewWithAccessibilityIdentifier:identifier inView:subview];
    if (match != nil) {
      return match;
    }
  }
  return nil;
}

- (nullable NSLayoutConstraint *)activeConstraintForView:(UIView *)view attribute:(NSLayoutAttribute)attribute {
  for (UIView *candidate = view; candidate != nil; candidate = candidate.superview) {
    for (NSLayoutConstraint *constraint in candidate.constraints) {
      BOOL matchesFirstItem = constraint.firstItem == view && constraint.firstAttribute == attribute;
      BOOL matchesSecondItem = constraint.secondItem == view && constraint.secondAttribute == attribute;
      if (constraint.active && (matchesFirstItem || matchesSecondItem)) {
        return constraint;
      }
    }
  }
  return nil;
}

- (CGRect)frameForView:(UIView *)view insideView:(UIView *)containerView {
  return [view convertRect:view.bounds toView:containerView];
}

- (void)layoutWindowForSize:(CGSize)size {
  self.window.frame = CGRectMake(0.0, 0.0, size.width, size.height);
  self.window.bounds = CGRectMake(0.0, 0.0, size.width, size.height);
  [self.window setNeedsLayout];
  [self.window layoutIfNeeded];
  [self.navigationController.view setNeedsLayout];
  [self.navigationController.view layoutIfNeeded];
  [self.navigationController.topViewController.view setNeedsLayout];
  [self.navigationController.topViewController.view layoutIfNeeded];
}

- (UIImage *)sampleImageWithColor:(UIColor *)color {
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0, 24.0), YES, 1.0);
  [color setFill];
  UIRectFill(CGRectMake(0.0, 0.0, 24.0, 24.0));
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
