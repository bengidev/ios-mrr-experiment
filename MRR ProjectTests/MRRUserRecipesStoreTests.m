#import <XCTest/XCTest.h>

#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../MRR Project/Features/Home/HomeDataSource.h"

@interface MRRUserRecipesStoreTests : XCTestCase

@property(nonatomic, strong) MRRCoreDataStack *coreDataStack;
@property(nonatomic, strong) MRRUserRecipesStore *store;

- (MRRUserRecipeSnapshot *)snapshotWithUserID:(NSString *)userID
                                      recipeID:(NSString *)recipeID
                                         title:(NSString *)title
                                      mealType:(NSString *)mealType
                                   savedOffset:(NSTimeInterval)savedOffset;

@end

@implementation MRRUserRecipesStoreTests

- (void)setUp {
  [super setUp];

  NSError *error = nil;
  self.coreDataStack = [[MRRCoreDataStack alloc] initWithInMemoryStore:YES error:&error];
  XCTAssertNotNil(self.coreDataStack);
  XCTAssertNil(error);
  self.store = [[MRRUserRecipesStore alloc] initWithCoreDataStack:self.coreDataStack];
}

- (void)tearDown {
  self.store = nil;
  self.coreDataStack = nil;
  [super tearDown];
}

- (void)testSaveRecipeSnapshotPersistsAndFetchesChildrenInOrder {
  MRRUserRecipeSnapshot *snapshot = [self snapshotWithUserID:@"user-a"
                                                     recipeID:@"recipe-1"
                                                        title:@"Savory Oats"
                                                     mealType:MRRUserRecipeMealTypeBreakfast
                                                  savedOffset:10.0];

  NSError *saveError = nil;
  XCTAssertTrue([self.store saveRecipeSnapshot:snapshot error:&saveError]);
  XCTAssertNil(saveError);

  NSError *fetchError = nil;
  NSArray<MRRUserRecipeSnapshot *> *userRecipes = [self.store userRecipesForUserID:@"user-a" error:&fetchError];
  XCTAssertNil(fetchError);
  XCTAssertEqual(userRecipes.count, 1);

  MRRUserRecipeSnapshot *savedSnapshot = userRecipes.firstObject;
  XCTAssertEqualObjects(savedSnapshot.title, @"Savory Oats");
  XCTAssertEqualObjects(savedSnapshot.mealType, MRRUserRecipeMealTypeBreakfast);
  XCTAssertEqual(savedSnapshot.ingredients.count, 2);
  XCTAssertEqualObjects(savedSnapshot.ingredients[0].name, @"Rolled oats");
  XCTAssertEqualObjects(savedSnapshot.ingredients[1].name, @"Fried egg");
  XCTAssertEqual(savedSnapshot.instructions.count, 2);
  XCTAssertEqualObjects(savedSnapshot.instructions[0].title, @"Step 1");
  XCTAssertEqualObjects(savedSnapshot.instructions[1].title, @"Step 2");
  XCTAssertEqualObjects(savedSnapshot.tools[0].value, @"Saucepan");
  XCTAssertEqualObjects(savedSnapshot.tools[1].value, @"Spoon");
  XCTAssertEqualObjects(savedSnapshot.tags[0].value, @"breakfast");
  XCTAssertEqualObjects(savedSnapshot.tags[1].value, @"High Protein");
}

- (void)testSavingSameRecipeTwiceUpdatesWithoutDuplicatingRows {
  MRRUserRecipeSnapshot *initialSnapshot = [self snapshotWithUserID:@"user-a"
                                                            recipeID:@"recipe-1"
                                                               title:@"Savory Oats"
                                                            mealType:MRRUserRecipeMealTypeBreakfast
                                                         savedOffset:20.0];
  NSError *saveError = nil;
  XCTAssertTrue([self.store saveRecipeSnapshot:initialSnapshot error:&saveError]);
  XCTAssertNil(saveError);

  MRRUserRecipeSnapshot *updatedSnapshot = [self snapshotWithUserID:@"user-a"
                                                            recipeID:@"recipe-1"
                                                               title:@"Savory Oats Deluxe"
                                                            mealType:MRRUserRecipeMealTypeBreakfast
                                                         savedOffset:20.0];
  XCTAssertTrue([self.store saveRecipeSnapshot:updatedSnapshot error:&saveError]);
  XCTAssertNil(saveError);

  NSError *fetchError = nil;
  NSArray<MRRUserRecipeSnapshot *> *userRecipes = [self.store userRecipesForUserID:@"user-a" error:&fetchError];
  XCTAssertNil(fetchError);
  XCTAssertEqual(userRecipes.count, 1);
  XCTAssertEqualObjects(userRecipes.firstObject.title, @"Savory Oats Deluxe");
}

- (void)testRemoveRecipeDeletesSnapshotAndQueuesDeleteSyncChange {
  MRRUserRecipeSnapshot *snapshot = [self snapshotWithUserID:@"user-a"
                                                     recipeID:@"recipe-1"
                                                        title:@"Savory Oats"
                                                     mealType:MRRUserRecipeMealTypeBreakfast
                                                  savedOffset:5.0];
  NSError *error = nil;
  XCTAssertTrue([self.store saveRecipeSnapshot:snapshot error:&error]);
  XCTAssertNil(error);

  XCTAssertTrue([self.store removeRecipeForUserID:@"user-a" recipeID:@"recipe-1" error:&error]);
  XCTAssertNil(error);

  NSArray<MRRUserRecipeSnapshot *> *userRecipes = [self.store userRecipesForUserID:@"user-a" error:&error];
  XCTAssertNil(error);
  XCTAssertEqual(userRecipes.count, 0);

  NSArray<MRRUserRecipeSyncChange *> *pendingChanges = [self.store pendingSyncChangesForUserID:@"user-a" error:&error];
  XCTAssertNil(error);
  XCTAssertEqual(pendingChanges.count, 1);
  XCTAssertEqual(pendingChanges.firstObject.operation, MRRUserRecipeSyncChangeOperationDelete);
}

- (void)testUserRecipesStayScopedPerUser {
  NSError *error = nil;
  XCTAssertTrue([[self store] saveRecipeSnapshot:[self snapshotWithUserID:@"user-a"
                                                                 recipeID:@"recipe-1"
                                                                    title:@"User A Breakfast"
                                                                 mealType:MRRUserRecipeMealTypeBreakfast
                                                              savedOffset:4.0]
                                           error:&error]);
  XCTAssertNil(error);
  XCTAssertTrue([[self store] saveRecipeSnapshot:[self snapshotWithUserID:@"user-b"
                                                                 recipeID:@"recipe-1"
                                                                    title:@"User B Dinner"
                                                                 mealType:MRRUserRecipeMealTypeDinner
                                                              savedOffset:3.0]
                                           error:&error]);
  XCTAssertNil(error);

  NSArray<MRRUserRecipeSnapshot *> *userARecipes = [self.store userRecipesForUserID:@"user-a" error:&error];
  XCTAssertNil(error);
  NSArray<MRRUserRecipeSnapshot *> *userBRecipes = [self.store userRecipesForUserID:@"user-b" error:&error];
  XCTAssertNil(error);

  XCTAssertEqual(userARecipes.count, 1);
  XCTAssertEqual(userBRecipes.count, 1);
  XCTAssertEqualObjects(userARecipes.firstObject.title, @"User A Breakfast");
  XCTAssertEqualObjects(userBRecipes.firstObject.title, @"User B Dinner");
}

- (MRRUserRecipeSnapshot *)snapshotWithUserID:(NSString *)userID
                                      recipeID:(NSString *)recipeID
                                         title:(NSString *)title
                                      mealType:(NSString *)mealType
                                   savedOffset:(NSTimeInterval)savedOffset {
  HomeRecipeCard *recipeCard = [[HomeRecipeCard alloc] initWithRecipeID:recipeID
                                                                  title:title
                                                               subtitle:@"Comfort Bowl"
                                                              assetName:@"avocado-toast"
                                                         imageURLString:nil
                                                            summaryText:@"A cozy bowl for testing persistence."
                                                         readyInMinutes:18
                                                               servings:2
                                                           calorieCount:420
                                                        popularityScore:87
                                                             sourceName:@"MRR Tests"
                                                        sourceURLString:@"https://example.com/recipe"
                                                               mealType:mealType
                                                                   tags:@[ mealType, @"High Protein" ]];
  OnboardingRecipeIngredient *ingredientOne =
      [[OnboardingRecipeIngredient alloc] initWithName:@"Rolled oats" displayText:@"1 cup rolled oats"];
  OnboardingRecipeIngredient *ingredientTwo =
      [[OnboardingRecipeIngredient alloc] initWithName:@"Fried egg" displayText:@"1 fried egg"];
  OnboardingRecipeInstruction *instructionOne =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 1" detailText:@"Toast the oats in the pan."];
  OnboardingRecipeInstruction *instructionTwo =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 2" detailText:@"Finish with the fried egg."];
  OnboardingRecipeDetail *recipeDetail =
      [[OnboardingRecipeDetail alloc] initWithTitle:title
                                           subtitle:@"Comfort Bowl"
                                          assetName:@"avocado-toast"
                                 heroImageURLString:nil
                                       durationText:@"18 mins"
                                        calorieText:@"420 kcal"
                                       servingsText:@"2 servings"
                                        summaryText:@"A cozy bowl for testing persistence."
                                        ingredients:@[ ingredientOne, ingredientTwo ]
                                       instructions:@[ instructionOne, instructionTwo ]
                                              tools:@[ @"Saucepan", @"Spoon" ]
                                               tags:@[ mealType, @"High Protein" ]
                                         sourceName:@"MRR Tests"
                                    sourceURLString:@"https://example.com/recipe"
                                     productContext:nil];
  NSDate *createdAt = [NSDate dateWithTimeIntervalSince1970:1700000000.0 + savedOffset];
  NSDate *modifiedAt = [createdAt dateByAddingTimeInterval:30.0];
  return [MRRUserRecipeSnapshot snapshotWithUserID:userID
                                         recipeCard:recipeCard
                                       recipeDetail:recipeDetail
                                            createdAt:createdAt
                                    localModifiedAt:modifiedAt];
}

@end
