#import "MRRNoOpUserRecipesSyncEngine.h"

@implementation MRRNoOpUserRecipesSyncEngine

- (void)startSyncForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
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

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
#pragma unused(userID)
  if (completion != nil) {
    completion(nil);
  }
}

@end
