#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MRRSavedRecipesSyncCompletion)(NSError *_Nullable error);

@protocol MRRSavedRecipesCloudSyncing <NSObject>

- (void)startSyncForUserID:(NSString *)userID completion:(nullable MRRSavedRecipesSyncCompletion)completion;
- (void)stopSync;
- (void)requestImmediateSyncForUserID:(NSString *)userID;
- (void)flushPendingChangesForUserID:(NSString *)userID completion:(nullable MRRSavedRecipesSyncCompletion)completion;

@end

NS_ASSUME_NONNULL_END
