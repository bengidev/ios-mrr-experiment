#import <XCTest/XCTest.h>

#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../MRR Project/Persistence/UserRecipes/Sync/MRRUserRecipesSyncEngine.h"

@class FIRFirestore;

@interface MRRUserRecipesSyncEngine (Testing)

- (instancetype)initWithStore:(MRRUserRecipesStore *)store firestore:(nullable FIRFirestore *)firestore;
- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRUserRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt;
- (nullable MRRUserRecipeSnapshot *)snapshotFromDictionary:(NSDictionary<NSString *, id> *)data
                                                    userID:(NSString *)userID
                                                documentID:(NSString *)documentID;

@end

@interface MRRUserRecipesSyncEngineTests : XCTestCase

@property(nonatomic, strong) MRRCoreDataStack *coreDataStack;
@property(nonatomic, strong) MRRUserRecipesStore *store;
@property(nonatomic, strong) MRRUserRecipesSyncEngine *syncEngine;

@end

@implementation MRRUserRecipesSyncEngineTests

- (void)setUp {
  [super setUp];

  NSError *error = nil;
  self.coreDataStack = [[MRRCoreDataStack alloc] initWithInMemoryStore:YES error:&error];
  XCTAssertNil(error);
  self.store = [[MRRUserRecipesStore alloc] initWithCoreDataStack:self.coreDataStack];
  self.syncEngine = [[MRRUserRecipesSyncEngine alloc] initWithStore:self.store firestore:nil];
}

- (void)tearDown {
  self.syncEngine = nil;
  self.store = nil;
  self.coreDataStack = nil;
  [super tearDown];
}

- (void)testFirestorePayloadWritesRemotePhotoURLsOnlyAndMirrorsCoverHero {
  NSArray<MRRUserRecipePhotoSnapshot *> *photos = @[
    [[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:@"photo-1"
                                             orderIndex:0
                                        remoteURLString:@"https://example.com/one.jpg"
                                      localRelativePath:nil],
    [[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:@"photo-2"
                                             orderIndex:1
                                        remoteURLString:nil
                                      localRelativePath:@"recipe-2/photo-2.jpg"],
    [[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:@"photo-3"
                                             orderIndex:2
                                        remoteURLString:@"https://example.com/three.jpg"
                                      localRelativePath:nil]
  ];

  MRRUserRecipeSnapshot *snapshot =
      [[MRRUserRecipeSnapshot alloc] initWithUserID:@"user-a"
                                           recipeID:@"recipe-1"
                                              title:@"Remote Gallery"
                                           subtitle:@"Subtitle"
                                        summaryText:@"Summary"
                                           mealType:MRRUserRecipeMealTypeDinner
                                     readyInMinutes:20
                                           servings:2
                                       calorieCount:400
                                          assetName:@"pasta-carbonara"
                                 heroImageURLString:nil
                                             photos:photos
                                        ingredients:@[
                                          [[MRRUserRecipeIngredientSnapshot alloc] initWithName:@"Pasta" displayText:@"Pasta" orderIndex:0]
                                        ]
                                       instructions:@[
                                         [[MRRUserRecipeInstructionSnapshot alloc] initWithTitle:@"Step 1" detailText:@"Cook." orderIndex:0]
                                       ]
                                              tools:@[]
                                               tags:@[]
                                          createdAt:[NSDate date]
                                    localModifiedAt:[NSDate date]
                                    remoteUpdatedAt:nil];

  NSDictionary<NSString *, id> *payload = [self.syncEngine firestorePayloadForSnapshot:snapshot updatedAt:[NSDate date]];
  XCTAssertEqualObjects(payload[@"photoURLStrings"], (@[ @"https://example.com/one.jpg", @"https://example.com/three.jpg" ]));
  XCTAssertEqualObjects(payload[@"heroImageURLString"], @"https://example.com/one.jpg");
}

- (void)testSnapshotFromDictionaryFallsBackToLegacyHeroImage {
  NSDictionary<NSString *, id> *data = @{
    @"recipeID" : @"recipe-legacy",
    @"title" : @"Legacy",
    @"subtitle" : @"Classic",
    @"summaryText" : @"Single hero legacy payload.",
    @"mealType" : @"lunch",
    @"readyInMinutes" : @15,
    @"servings" : @2,
    @"calorieCount" : @250,
    @"assetName" : @"green-curry",
    @"heroImageURLString" : @"https://example.com/legacy.jpg",
    @"ingredients" : @[ @{ @"name" : @"Broth", @"displayText" : @"2 cups broth", @"orderIndex" : @0 } ],
    @"instructions" : @[ @{ @"title" : @"Step 1", @"detailText" : @"Heat broth.", @"orderIndex" : @0 } ],
    @"tools" : @[],
    @"tags" : @[]
  };

  MRRUserRecipeSnapshot *snapshot = [self.syncEngine snapshotFromDictionary:data userID:@"user-a" documentID:@"doc-legacy"];
  XCTAssertNotNil(snapshot);
  XCTAssertEqual(snapshot.photos.count, 1);
  XCTAssertEqualObjects(snapshot.photos.firstObject.remoteURLString, @"https://example.com/legacy.jpg");
  XCTAssertEqualObjects(snapshot.heroImageURLString, @"https://example.com/legacy.jpg");
}

- (void)testSnapshotFromDictionaryUsesOrderedMultiPhotoURLsWhenPresent {
  NSDictionary<NSString *, id> *data = @{
    @"recipeID" : @"recipe-gallery",
    @"title" : @"Gallery",
    @"subtitle" : @"Multi",
    @"summaryText" : @"Photo URL payload.",
    @"mealType" : @"dinner",
    @"readyInMinutes" : @30,
    @"servings" : @4,
    @"calorieCount" : @520,
    @"assetName" : @"pizza",
    @"photoURLStrings" : @[ @"https://example.com/cover.jpg", @"https://example.com/detail.jpg" ],
    @"heroImageURLString" : @"https://example.com/outdated.jpg",
    @"ingredients" : @[ @{ @"name" : @"Flour", @"displayText" : @"2 cups flour", @"orderIndex" : @0 } ],
    @"instructions" : @[ @{ @"title" : @"Step 1", @"detailText" : @"Mix dough.", @"orderIndex" : @0 } ],
    @"tools" : @[],
    @"tags" : @[]
  };

  MRRUserRecipeSnapshot *snapshot = [self.syncEngine snapshotFromDictionary:data userID:@"user-a" documentID:@"doc-gallery"];
  XCTAssertNotNil(snapshot);
  XCTAssertEqual(snapshot.photos.count, 2);
  XCTAssertEqualObjects(snapshot.photos[0].remoteURLString, @"https://example.com/cover.jpg");
  XCTAssertEqualObjects(snapshot.photos[1].remoteURLString, @"https://example.com/detail.jpg");
  XCTAssertEqualObjects(snapshot.heroImageURLString, @"https://example.com/cover.jpg");
}

@end
