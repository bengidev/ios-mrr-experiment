#import "MRRSyncingLogoutController.h"

#import "../../../Features/Authentication/MRRAuthSession.h"

@interface MRRSyncingLogoutController ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) id<MRRSavedRecipesCloudSyncing> syncEngine;

@end

@implementation MRRSyncingLogoutController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                      syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(syncEngine != nil);

  self = [super init];
  if (self) {
    _authenticationController = [authenticationController retain];
    _syncEngine = [syncEngine retain];
  }
  return self;
}

- (void)dealloc {
  [_syncEngine release];
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

  [self.syncEngine flushPendingChangesForUserID:session.userID completion:^(NSError *syncError) {
    if (syncError != nil) {
      if (completion != nil) {
        completion(syncError);
      }
      return;
    }

    NSError *signOutError = nil;
    BOOL didSignOut = [self.authenticationController signOut:&signOutError];
    if (completion != nil) {
      completion((didSignOut && signOutError == nil) ? nil : signOutError);
    }
  }];
}

@end
