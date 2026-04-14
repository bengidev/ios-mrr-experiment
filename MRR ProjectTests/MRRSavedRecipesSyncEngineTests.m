#import <XCTest/XCTest.h>

#import "../MRR Project/Persistence/CoreData/MRRCoreDataStack.h"
#import "../MRR Project/Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../MRR Project/Persistence/SavedRecipes/Sync/MRRSavedRecipesSyncEngine.h"

@import FirebaseFirestore;

@interface MRRSavedRecipesSyncEngine (Testing)

- (BOOL)shouldFallbackToLocalModeForError:(nullable NSError *)error;
- (void)disableCloudSyncForError:(NSError *)error context:(NSString *)context completePendingFlushes:(BOOL)completePendingFlushes;

@end

@interface MRRSavedRecipesSyncEngineTests : XCTestCase

@property(nonatomic, strong) MRRCoreDataStack *coreDataStack;
@property(nonatomic, strong) MRRSavedRecipesStore *store;
@property(nonatomic, strong) MRRSavedRecipesSyncEngine *syncEngine;

@end

@implementation MRRSavedRecipesSyncEngineTests

- (void)setUp {
  [super setUp];

  NSError *error = nil;
  self.coreDataStack = [[MRRCoreDataStack alloc] initWithInMemoryStore:YES error:&error];
  XCTAssertNil(error);
  self.store = [[MRRSavedRecipesStore alloc] initWithCoreDataStack:self.coreDataStack];
  self.syncEngine = [[MRRSavedRecipesSyncEngine alloc] initWithStore:self.store];
}

- (void)tearDown {
  self.syncEngine = nil;
  self.store = nil;
  self.coreDataStack = nil;
  [super tearDown];
}

- (void)testShouldFallbackToLocalModeForUnavailableFirestoreError {
  NSError *error = [NSError errorWithDomain:FIRFirestoreErrorDomain code:FIRFirestoreErrorCodeUnavailable userInfo:nil];

  XCTAssertTrue([self.syncEngine shouldFallbackToLocalModeForError:error]);
}

- (void)testShouldFallbackToLocalModeForDisabledAPIMessage {
  NSError *error = [NSError errorWithDomain:@"CustomTests"
                                       code:42
                                   userInfo:@{NSLocalizedDescriptionKey : @"Cloud Firestore API has not been used in project culina-mrr-project before."}];

  XCTAssertTrue([self.syncEngine shouldFallbackToLocalModeForError:error]);
}

- (void)testFlushPendingChangesCompletesImmediatelyAfterFallbackModeEnabled {
  NSError *error = [NSError errorWithDomain:FIRFirestoreErrorDomain code:FIRFirestoreErrorCodeFailedPrecondition userInfo:nil];
  [self.syncEngine disableCloudSyncForError:error context:@"test" completePendingFlushes:NO];

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"flush completion"];
  [self.syncEngine flushPendingChangesForUserID:@"user-a"
                                     completion:^(NSError *flushError) {
                                       XCTAssertNil(flushError);
                                       [completionExpectation fulfill];
                                     }];

  [self waitForExpectations:@[ completionExpectation ] timeout:1.0];
}

@end
