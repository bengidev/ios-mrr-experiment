#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Yours/YoursViewController.h"
#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../MRR Project/Persistence/UserRecipes/Models/MRRUserRecipeSnapshot.h"
#import "../MRR Project/Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"

@interface YoursViewController (Testing)

- (void)handleAddButtonTapped:(id)sender;
- (BOOL)persistRecipeWithTitle:(NSString *)title
                      subtitle:(NSString *)subtitle
                       summary:(NSString *)summary
                 mealTypeInput:(NSString *)mealTypeInput
            readyInMinutesText:(NSString *)readyInMinutesText
                  servingsText:(NSString *)servingsText
               ingredientsText:(NSString *)ingredientsText
              instructionsText:(NSString *)instructionsText
                 existingRecipe:(nullable MRRUserRecipeSnapshot *)existingRecipe
                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)deleteRecipeWithIdentifier:(NSString *)recipeIdentifier error:(NSError *_Nullable *_Nullable)error;

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
@property(nonatomic, strong) YoursViewController *viewController;
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIWindow *window;

- (NSArray<MRRUserRecipeSnapshot *> *)currentRecipes;
- (UIAlertController *)presentedAlertController;
- (void)invokeAlertActionWithTitle:(NSString *)title onAlert:(UIAlertController *)alertController;
- (UIView *)findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)view;
- (UILabel *)findLabelWithText:(NSString *)text inView:(UIView *)view;
- (MRRUserRecipeSnapshot *)createRecipeWithTitle:(NSString *)title;
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
  self.viewController = [[YoursViewController alloc] initWithSessionUserID:@"user-yours"
                                                          userRecipesStore:self.store
                                                                syncEngine:self.syncEngine];
  self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  [self.viewController loadViewIfNeeded];
  [self.viewController.view layoutIfNeeded];
  [self spinMainRunLoop];
}

- (void)tearDown {
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];
  self.window.hidden = YES;
  self.window = nil;
  self.navigationController = nil;
  self.viewController = nil;
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

- (void)testAddButtonPresentsCreateAlert {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"yours.createAlert");
}

- (void)testCreatingRecipeShowsCardAndRequestsSync {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  UIAlertController *alertController = [self presentedAlertController];
  XCTAssertNotNil(alertController);

  NSArray<UITextField *> *textFields = alertController.textFields;
  textFields[0].text = @"Nasi Goreng Rumahan";
  textFields[1].text = @"Cepat dan gurih";
  textFields[2].text = @"Versi sederhana untuk makan malam.";
  textFields[3].text = @"dinner";
  textFields[4].text = @"25";
  textFields[5].text = @"3";
  textFields[6].text = @"Nasi putih, telur, bawang putih";
  textFields[7].text = @"Tumis bumbu; Masukkan telur; Aduk dengan nasi";
  [self invokeAlertActionWithTitle:@"Save" onAlert:alertController];
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];

  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];

  NSArray<MRRUserRecipeSnapshot *> *recipes = [self currentRecipes];
  XCTAssertEqual(recipes.count, 1);
  MRRUserRecipeSnapshot *recipe = recipes.firstObject;
  XCTAssertEqualObjects(recipe.title, @"Nasi Goreng Rumahan");
  XCTAssertEqual(self.syncEngine.requestCount, 1);
  XCTAssertEqualObjects(self.syncEngine.lastRequestedUserID, @"user-yours");
  XCTAssertNil([self findViewWithAccessibilityIdentifier:@"yours.emptyStateLabel" inView:self.viewController.view]);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:[@"yours.recipeCard." stringByAppendingString:recipe.recipeID]
                                                     inView:self.viewController.view]);
}

- (void)testCreatingRecipeAllowsEmptySummary {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  UIAlertController *alertController = [self presentedAlertController];
  XCTAssertNotNil(alertController);

  NSArray<UITextField *> *textFields = alertController.textFields;
  textFields[0].text = @"Telur Dadar Keju";
  textFields[1].text = @"Padat dan praktis";
  textFields[2].text = @"";
  textFields[3].text = @"breakfast";
  textFields[4].text = @"10";
  textFields[5].text = @"1";
  textFields[6].text = @"Telur, keju, garam";
  textFields[7].text = @"Kocok telur; Masak di pan";
  [self invokeAlertActionWithTitle:@"Save" onAlert:alertController];
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];

  [self spinMainRunLoop];

  NSArray<MRRUserRecipeSnapshot *> *recipes = [self currentRecipes];
  XCTAssertEqual(recipes.count, 1);
  XCTAssertEqualObjects(recipes.firstObject.title, @"Telur Dadar Keju");
  XCTAssertEqualObjects(recipes.firstObject.summaryText, @"");
}

- (void)testValidationFailureRepresentsFormWithPreservedInput {
  [self.viewController handleAddButtonTapped:nil];
  [self spinMainRunLoop];

  UIAlertController *alertController = [self presentedAlertController];
  XCTAssertNotNil(alertController);

  NSArray<UITextField *> *textFields = alertController.textFields;
  textFields[0].text = @"Roti Bakar Cokelat";
  textFields[1].text = @"Manis cepat";
  textFields[2].text = @"Cocok untuk sarapan.";
  textFields[3].text = @"breakfast";
  textFields[4].text = @"8";
  textFields[5].text = @"1";
  textFields[6].text = @"";
  textFields[7].text = @"Oles cokelat; Panggang roti";
  [self invokeAlertActionWithTitle:@"Save" onAlert:alertController];

  [self spinMainRunLoop];

  UIAlertController *reopenedAlert = [self presentedAlertController];
  XCTAssertNotNil(reopenedAlert);
  XCTAssertEqualObjects(reopenedAlert.view.accessibilityIdentifier, @"yours.createAlert");

  NSArray<UITextField *> *reopenedFields = reopenedAlert.textFields;
  XCTAssertEqualObjects(reopenedFields[0].text, @"Roti Bakar Cokelat");
  XCTAssertEqualObjects(reopenedFields[1].text, @"Manis cepat");
  XCTAssertEqualObjects(reopenedFields[2].text, @"Cocok untuk sarapan.");
  XCTAssertEqualObjects(reopenedFields[3].text, @"breakfast");
  XCTAssertEqualObjects(reopenedFields[4].text, @"8");
  XCTAssertEqualObjects(reopenedFields[5].text, @"1");
  XCTAssertEqualObjects(reopenedFields[6].text, @"");
  XCTAssertEqualObjects(reopenedFields[7].text, @"Oles cokelat; Panggang roti");
}

- (void)testEditButtonPresentsAlertAndUpdatingRecipeRefreshesCard {
  MRRUserRecipeSnapshot *recipe = [self createRecipeWithTitle:@"Pasta Lemon"];
  UIButton *editButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.editButton." stringByAppendingString:recipe.recipeID]
                                                     inView:self.viewController.view];
  XCTAssertNotNil(editButton);

  [editButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"yours.editAlert");

  UIAlertController *alertController = [self presentedAlertController];
  NSArray<UITextField *> *textFields = alertController.textFields;
  textFields[0].text = @"Pasta Lemon Creamy";
  textFields[1].text = @"Lebih rich";
  textFields[2].text = @"Versi creamy untuk makan siang.";
  textFields[3].text = @"lunch";
  textFields[4].text = @"30";
  textFields[5].text = @"2";
  textFields[6].text = @"Pasta, lemon, cream";
  textFields[7].text = @"Rebus pasta; Buat saus; Campur rata";
  [self invokeAlertActionWithTitle:@"Save" onAlert:alertController];
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];

  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];

  NSArray<MRRUserRecipeSnapshot *> *recipes = [self currentRecipes];
  XCTAssertEqual(recipes.count, 1);
  MRRUserRecipeSnapshot *updatedRecipe = recipes.firstObject;
  XCTAssertEqualObjects(updatedRecipe.title, @"Pasta Lemon Creamy");
  XCTAssertNotNil([self findLabelWithText:@"Pasta Lemon Creamy" inView:self.viewController.view]);
}

- (void)testDeleteButtonPresentsAlertAndDeletingLastRecipeRestoresEmptyState {
  MRRUserRecipeSnapshot *recipe = [self createRecipeWithTitle:@"Soto Ayam Kilat"];
  UIButton *deleteButton =
      (UIButton *)[self findViewWithAccessibilityIdentifier:[@"yours.deleteButton." stringByAppendingString:recipe.recipeID]
                                                     inView:self.viewController.view];
  XCTAssertNotNil(deleteButton);

  [deleteButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  [self spinMainRunLoop];

  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  XCTAssertEqualObjects(self.viewController.presentedViewController.view.accessibilityIdentifier, @"yours.deleteAlert");
  [self invokeAlertActionWithTitle:@"Delete" onAlert:[self presentedAlertController]];
  [self.viewController dismissViewControllerAnimated:NO completion:nil];
  [self spinMainRunLoop];

  [self spinMainRunLoop];
  [self.viewController.view layoutIfNeeded];

  XCTAssertEqual([self currentRecipes].count, 0);
  XCTAssertNotNil([self findViewWithAccessibilityIdentifier:@"yours.emptyStateLabel" inView:self.viewController.view]);
  XCTAssertNil([self findViewWithAccessibilityIdentifier:[@"yours.recipeCard." stringByAppendingString:recipe.recipeID]
                                                  inView:self.viewController.view]);
  XCTAssertEqual(self.syncEngine.requestCount, 2);
}

- (NSArray<MRRUserRecipeSnapshot *> *)currentRecipes {
  NSError *error = nil;
  NSArray<MRRUserRecipeSnapshot *> *recipes = [self.store userRecipesForUserID:@"user-yours" error:&error];
  XCTAssertNil(error);
  return recipes ?: @[];
}

- (UIAlertController *)presentedAlertController {
  XCTAssertTrue([self.viewController.presentedViewController isKindOfClass:[UIAlertController class]]);
  return (UIAlertController *)self.viewController.presentedViewController;
}

- (void)invokeAlertActionWithTitle:(NSString *)title onAlert:(UIAlertController *)alertController {
  UIAlertAction *targetAction = nil;
  for (UIAlertAction *action in alertController.actions) {
    if ([action.title isEqualToString:title]) {
      targetAction = action;
      break;
    }
  }

  XCTAssertNotNil(targetAction);

  void (^handler)(UIAlertAction *) = [targetAction valueForKey:@"handler"];
  #pragma unused(alertController)
  if (handler != nil) {
    handler(targetAction);
  }
  [self spinMainRunLoop];
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

- (UILabel *)findLabelWithText:(NSString *)text inView:(UIView *)view {
  if ([view isKindOfClass:[UILabel class]] && [((UILabel *)view).text isEqualToString:text]) {
    return (UILabel *)view;
  }

  for (UIView *subview in view.subviews) {
    UILabel *match = [self findLabelWithText:text inView:subview];
    if (match != nil) {
      return match;
    }
  }

  return nil;
}

- (MRRUserRecipeSnapshot *)createRecipeWithTitle:(NSString *)title {
  NSError *error = nil;
  BOOL didCreate = [self.viewController persistRecipeWithTitle:title
                                                      subtitle:@"Subtitle"
                                                       summary:@"Ringkas dan enak."
                                                 mealTypeInput:@"breakfast"
                                            readyInMinutesText:@"15"
                                                  servingsText:@"2"
                                               ingredientsText:@"Bahan satu, Bahan dua"
                                              instructionsText:@"Langkah satu; Langkah dua"
                                                 existingRecipe:nil
                                                          error:&error];
  XCTAssertTrue(didCreate);
  XCTAssertNil(error);
  [self spinMainRunLoop];
  return [self currentRecipes].firstObject;
}

- (void)spinMainRunLoop {
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
}

@end
