#import <Foundation/Foundation.h>

#import "Models/MRRUserRecipeSnapshot.h"
#import "Models/MRRUserRecipeSyncChange.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRCoreDataStack;

FOUNDATION_EXPORT NSNotificationName const MRRUserRecipesStoreDidChangeNotification;
FOUNDATION_EXPORT NSErrorDomain const MRRUserRecipesStoreErrorDomain;

@interface MRRUserRecipesStore : NSObject

- (instancetype)initWithCoreDataStack:(MRRCoreDataStack *)coreDataStack;

- (NSArray<MRRUserRecipeSnapshot *> *)userRecipesForUserID:(NSString *)userID error:(NSError *_Nullable *_Nullable)error;
- (nullable MRRUserRecipeSnapshot *)userRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)saveRecipeSnapshot:(MRRUserRecipeSnapshot *)snapshot error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (NSArray<MRRUserRecipeSyncChange *> *)pendingSyncChangesForUserID:(NSString *)userID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)hasPendingSyncChangeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)markPendingSyncChangeProcessedForUserID:(NSString *)userID
                                       recipeID:(NSString *)recipeID
                                remoteUpdatedAt:(nullable NSDate *)remoteUpdatedAt
                                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)applyRemoteSnapshot:(MRRUserRecipeSnapshot *)snapshot remoteUpdatedAt:(NSDate *)remoteUpdatedAt error:(NSError *_Nullable *_Nullable)error;
- (BOOL)applyRemoteDeletionForUserID:(NSString *)userID
                            recipeID:(NSString *)recipeID
                     remoteUpdatedAt:(NSDate *)remoteUpdatedAt
                               error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
