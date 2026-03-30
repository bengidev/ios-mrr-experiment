#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MRRUserRecipesSyncCompletion)(NSError *_Nullable error);

@protocol MRRUserRecipesCloudSyncing <NSObject>

- (void)startSyncForUserID:(NSString *)userID completion:(nullable MRRUserRecipesSyncCompletion)completion;
- (void)stopSync;
- (void)requestImmediateSyncForUserID:(NSString *)userID;
- (void)flushPendingChangesForUserID:(NSString *)userID completion:(nullable MRRUserRecipesSyncCompletion)completion;

@end

NS_ASSUME_NONNULL_END
