#import "MRRNoOpSavedRecipesSyncEngine.h"

@implementation MRRNoOpSavedRecipesSyncEngine

- (void)startSyncForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  #pragma unused(userID)
  if (completion != nil) {
    completion(nil);
  }
}

- (void)stopSync {
}

- (void)requestImmediateSyncForUserID:(NSString *)userID {
  #pragma unused(userID)
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  #pragma unused(userID)
  if (completion != nil) {
    completion(nil);
  }
}

@end
