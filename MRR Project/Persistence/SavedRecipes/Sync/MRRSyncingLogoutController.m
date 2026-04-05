#import "MRRSyncingLogoutController.h"

#import "../../../Features/Authentication/MRRAuthSession.h"

@interface MRRSyncingLogoutController ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) id<MRRSavedRecipesCloudSyncing> savedRecipesSyncEngine;
@property(nonatomic, retain, nullable) id<MRRUserRecipesCloudSyncing> userRecipesSyncEngine;

@end

@implementation MRRSyncingLogoutController

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
      completion((didSignOut && signOutError == nil) ? nil : signOutError);
    }
    return;
  }

  [self.savedRecipesSyncEngine flushPendingChangesForUserID:session.userID
                                                 completion:^(NSError *syncError) {
                                                   if (syncError != nil) {
                                                     if (completion != nil) {
                                                       completion(syncError);
                                                     }
                                                     return;
                                                   }

                                                   void (^completeSignOut)(void) = ^{
                                                     NSError *signOutError = nil;
                                                     BOOL didSignOut = [self.authenticationController signOut:&signOutError];
                                                     if (completion != nil) {
                                                       completion((didSignOut && signOutError == nil) ? nil : signOutError);
                                                     }
                                                   };

                                                   if (self.userRecipesSyncEngine == nil) {
                                                     completeSignOut();
                                                     return;
                                                   }

                                                   [self.userRecipesSyncEngine flushPendingChangesForUserID:session.userID
                                                                                                 completion:^(NSError *userSyncError) {
                                                                                                   if (userSyncError != nil) {
                                                                                                     if (completion != nil) {
                                                                                                       completion(userSyncError);
                                                                                                     }
                                                                                                     return;
                                                                                                   }

                                                                                                   completeSignOut();
                                                                                                 }];
                                                 }];
}

@end
