#import "MRRSyncingLogoutController.h"

#import "../../../Features/Authentication/MRRAuthSession.h"

@interface MRRSyncingLogoutController ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) id<MRRSavedRecipesCloudSyncing> savedRecipesSyncEngine;
@property(nonatomic, retain, nullable) id<MRRUserRecipesCloudSyncing> userRecipesSyncEngine;

- (nullable NSError *)resolvedSignOutErrorWithSuccess:(BOOL)didSignOut error:(nullable NSError *)signOutError;
- (BOOL)shouldProceedWithForcedLogoutForSyncError:(nullable NSError *)syncError;
- (void)completeSignOutByStoppingSyncIfNeeded:(BOOL)shouldStopSync completion:(MRRLogoutCompletion)completion;

@end

@implementation MRRSyncingLogoutController

static NSString *const MRRSyncingLogoutControllerDomain = @"MRRSyncingLogoutController";
static const NSInteger MRRSyncingLogoutControllerSignOutFailedErrorCode = -3001;
static NSString *const MRRSavedRecipesSyncEngineDomain = @"MRRSavedRecipesSyncEngine";
static NSString *const MRRUserRecipesSyncEngineDomain = @"MRRUserRecipesSyncEngine";
static const NSInteger MRRSyncingLogoutControllerSyncTimeoutErrorCode = -2001;

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                      syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  return [self initWithAuthenticationController:authenticationController savedRecipesSyncEngine:syncEngine userRecipesSyncEngine:nil];
}

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                          savedRecipesSyncEngine:(id<MRRSavedRecipesCloudSyncing>)savedRecipesSyncEngine
                           userRecipesSyncEngine:(id<MRRUserRecipesCloudSyncing>)userRecipesSyncEngine {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(savedRecipesSyncEngine != nil);

  self = [super init];
  if (self) {
    _authenticationController = [authenticationController retain];
    _savedRecipesSyncEngine = [savedRecipesSyncEngine retain];
    _userRecipesSyncEngine = [userRecipesSyncEngine retain];
  }
  return self;
}

- (void)dealloc {
  [_userRecipesSyncEngine release];
  [_savedRecipesSyncEngine release];
  [_authenticationController release];
  [super dealloc];
}

- (void)performLogoutForSession:(MRRAuthSession *)session completion:(MRRLogoutCompletion)completion {
  if (session.userID.length == 0) {
    NSError *signOutError = nil;
    BOOL didSignOut = [self.authenticationController signOut:&signOutError];
    if (completion != nil) {
      completion([self resolvedSignOutErrorWithSuccess:didSignOut error:signOutError]);
    }
    return;
  }

  [self.savedRecipesSyncEngine flushPendingChangesForUserID:session.userID
                                                 completion:^(NSError *syncError) {
                                                   if (syncError != nil) {
                                                     if ([self shouldProceedWithForcedLogoutForSyncError:syncError]) {
                                                       [self completeSignOutByStoppingSyncIfNeeded:YES completion:completion];
                                                       return;
                                                     }

                                                     if (completion != nil) {
                                                       completion(syncError);
                                                     }
                                                     return;
                                                   }

                                                   if (self.userRecipesSyncEngine == nil) {
                                                     [self completeSignOutByStoppingSyncIfNeeded:NO completion:completion];
                                                     return;
                                                   }

                                                   [self.userRecipesSyncEngine flushPendingChangesForUserID:session.userID
                                                                                                 completion:^(NSError *userSyncError) {
                                                                                                   if (userSyncError != nil) {
                                                                                                     if ([self shouldProceedWithForcedLogoutForSyncError:userSyncError]) {
                                                                                                       [self completeSignOutByStoppingSyncIfNeeded:YES completion:completion];
                                                                                                       return;
                                                                                                     }

                                                                                                     if (completion != nil) {
                                                                                                       completion(userSyncError);
                                                                                                     }
                                                                                                     return;
                                                                                                   }

                                                                                                   [self completeSignOutByStoppingSyncIfNeeded:NO completion:completion];
                                                                                                 }];
                                                 }];
}

- (void)proceedWithForcedLogoutForSession:(MRRAuthSession *)session error:(NSError **)error {
#pragma unused(session)
  [self.savedRecipesSyncEngine stopSync];
  [self.userRecipesSyncEngine stopSync];
  NSError *signOutError = nil;
  BOOL didSignOut = [self.authenticationController signOut:&signOutError];
  NSError *resolvedError = [self resolvedSignOutErrorWithSuccess:didSignOut error:signOutError];
  if (error != NULL) {
    *error = resolvedError;
  }
}

- (BOOL)shouldProceedWithForcedLogoutForSyncError:(NSError *)syncError {
  if (syncError == nil) {
    return NO;
  }

  BOOL isSyncTimeout = (syncError.code == MRRSyncingLogoutControllerSyncTimeoutErrorCode &&
                        ([syncError.domain isEqualToString:MRRSavedRecipesSyncEngineDomain] ||
                         [syncError.domain isEqualToString:MRRUserRecipesSyncEngineDomain]));
  return isSyncTimeout;
}

- (void)completeSignOutByStoppingSyncIfNeeded:(BOOL)shouldStopSync completion:(MRRLogoutCompletion)completion {
  if (shouldStopSync) {
    [self.savedRecipesSyncEngine stopSync];
    [self.userRecipesSyncEngine stopSync];
  }

  NSError *signOutError = nil;
  BOOL didSignOut = [self.authenticationController signOut:&signOutError];
  if (completion != nil) {
    completion([self resolvedSignOutErrorWithSuccess:didSignOut error:signOutError]);
  }
}

- (nullable NSError *)resolvedSignOutErrorWithSuccess:(BOOL)didSignOut error:(NSError *)signOutError {
  if (didSignOut && signOutError == nil) {
    return nil;
  }

  if (signOutError != nil) {
    return signOutError;
  }

  return [NSError errorWithDomain:MRRSyncingLogoutControllerDomain
                             code:MRRSyncingLogoutControllerSignOutFailedErrorCode
                         userInfo:@{NSLocalizedDescriptionKey : @"Logout did not complete. Please try again."}];
}

@end
