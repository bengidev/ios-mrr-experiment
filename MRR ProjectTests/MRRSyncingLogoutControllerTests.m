#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Authentication/MRRAuthenticationController.h"
#import "../MRR Project/Features/Authentication/MRRAuthSession.h"
#import "../MRR Project/Persistence/SavedRecipes/Sync/MRRSyncingLogoutController.h"

@interface MRRSyncingLogoutControllerAuthObservationSpy : NSObject <MRRAuthStateObservation>
@end

@implementation MRRSyncingLogoutControllerAuthObservationSpy

- (void)invalidate {
}

@end

@interface MRRSyncingLogoutControllerAuthSpy : NSObject <MRRAuthenticationController>

@property(nonatomic, assign) BOOL signOutCalled;
@property(nonatomic, retain, nullable) NSError *signOutError;

@end

@implementation MRRSyncingLogoutControllerAuthSpy

- (MRRAuthSession *)currentSession {
  return nil;
}

- (id<MRRAuthStateObservation>)observeAuthStateWithHandler:(MRRAuthStateChangeHandler)handler {
  return [[MRRSyncingLogoutControllerAuthObservationSpy alloc] init];
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

- (BOOL)signOut:(NSError *__autoreleasing  _Nullable *)error {
  self.signOutCalled = YES;
  if (self.signOutError != nil && error != nil) {
    *error = self.signOutError;
  }
  return self.signOutError == nil;
}

@end

@interface MRRSyncingLogoutControllerSyncEngineSpy : NSObject <MRRSavedRecipesCloudSyncing>

@property(nonatomic, copy, nullable) NSString *flushedUserID;
@property(nonatomic, retain, nullable) NSError *flushError;
@property(nonatomic, assign) NSUInteger flushInvocationCount;

@end

@implementation MRRSyncingLogoutControllerSyncEngineSpy

- (void)startSyncForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  if (completion != nil) {
    completion(nil);
  }
}

- (void)stopSync {
}

- (void)requestImmediateSyncForUserID:(NSString *)userID {
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  self.flushInvocationCount += 1;
  self.flushedUserID = userID;
  if (completion != nil) {
    completion(self.flushError);
  }
}

@end

@interface MRRSyncingLogoutControllerTests : XCTestCase
@end

@implementation MRRSyncingLogoutControllerTests

- (void)testPerformLogoutFlushesPendingChangesBeforeSignOut {
  MRRSyncingLogoutControllerAuthSpy *authenticationSpy = [[MRRSyncingLogoutControllerAuthSpy alloc] init];
  MRRSyncingLogoutControllerSyncEngineSpy *syncEngineSpy = [[MRRSyncingLogoutControllerSyncEngineSpy alloc] init];
  MRRSyncingLogoutController *logoutController =
      [[MRRSyncingLogoutController alloc] initWithAuthenticationController:authenticationSpy syncEngine:syncEngineSpy];
  MRRAuthSession *session = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                             email:@"cook@example.com"
                                                       displayName:@"Cook"
                                                      providerType:MRRAuthProviderTypeEmail
                                                     emailVerified:YES];

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"logout completion"];
  [logoutController performLogoutForSession:session completion:^(NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqual(syncEngineSpy.flushInvocationCount, 1u);
    XCTAssertEqualObjects(syncEngineSpy.flushedUserID, @"firebase-uid");
    XCTAssertTrue(authenticationSpy.signOutCalled);
    [completionExpectation fulfill];
  }];

  [self waitForExpectations:@[ completionExpectation ] timeout:1.0];
}

- (void)testPerformLogoutReturnsSyncErrorWithoutSigningOut {
  MRRSyncingLogoutControllerAuthSpy *authenticationSpy = [[MRRSyncingLogoutControllerAuthSpy alloc] init];
  MRRSyncingLogoutControllerSyncEngineSpy *syncEngineSpy = [[MRRSyncingLogoutControllerSyncEngineSpy alloc] init];
  syncEngineSpy.flushError = [NSError errorWithDomain:@"MRRSyncTests" code:42 userInfo:nil];
  MRRSyncingLogoutController *logoutController =
      [[MRRSyncingLogoutController alloc] initWithAuthenticationController:authenticationSpy syncEngine:syncEngineSpy];
  MRRAuthSession *session = [[MRRAuthSession alloc] initWithUserID:@"firebase-uid"
                                                             email:@"cook@example.com"
                                                       displayName:@"Cook"
                                                      providerType:MRRAuthProviderTypeEmail
                                                     emailVerified:YES];

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"logout completion"];
  [logoutController performLogoutForSession:session completion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(syncEngineSpy.flushInvocationCount, 1u);
    XCTAssertFalse(authenticationSpy.signOutCalled);
    [completionExpectation fulfill];
  }];

  [self waitForExpectations:@[ completionExpectation ] timeout:1.0];
}

@end
