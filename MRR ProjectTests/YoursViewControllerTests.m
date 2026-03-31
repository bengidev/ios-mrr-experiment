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
- (MRRYoursRecipeEditorViewController *)presentedEditor;
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
  UILabel *emptyStateLabel =
      (UILabel *)[self findViewWithAccessibilityIdentifier:@"yours.emptyStateLabel" inView:self.viewController.view];
  UIButton *emptyStateButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:@"yours.emptyStateButton" inView:self.viewController.view];

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
  UITextField *titleField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editor.view];
  UITextField *ingredientField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.ingredientField.0" inView:editor.view];
  UITextField *stepField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];

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
  UIButton *editButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.editButton." stringByAppendingString:recipe.recipeID]
                                                     inView:self.viewController.view];
  XCTAssertNotNil(editButton);

  [editButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  MRRYoursRecipeEditorViewController *editEditor = [self presentedEditor];
  UITextField *titleField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editEditor.view];
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

- (void)testDeleteButtonPresentsAlertAndDeletingLastRecipeRestoresEmptyState {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];
  MRRYoursRecipeEditorViewController *editor = [self presentedEditor];
  [self populateRequiredFieldsInEditor:editor title:@"Soto Ayam Kilat"];
  [editor handleSaveTapped:nil];
  [self spinMainRunLoop];

  MRRUserRecipeSnapshot *recipe = [self currentRecipes].firstObject;
  UIButton *deleteButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.deleteButton." stringByAppendingString:recipe.recipeID]
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
  UITextField *titleField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.titleField" inView:editor.view];
  UITextField *subtitleField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.subtitleField" inView:editor.view];
  UITextView *summaryTextView =
      (UITextView *)[self findViewWithAccessibilityIdentifier:@"yours.editor.summaryTextView" inView:editor.view];
  UITextField *readyField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.readyField" inView:editor.view];
  UITextField *servingsField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.servingsField" inView:editor.view];
  UITextField *caloriesField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.caloriesField" inView:editor.view];
  UITextField *ingredientField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.ingredientField.0" inView:editor.view];
  UITextField *stepField =
      (UITextField *)[self findViewWithAccessibilityIdentifier:@"yours.editor.stepField.0" inView:editor.view];

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
