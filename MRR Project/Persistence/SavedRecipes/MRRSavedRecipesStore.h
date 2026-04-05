#import <Foundation/Foundation.h>

#import "Models/MRRSavedRecipeSnapshot.h"
#import "Models/MRRSavedRecipeSyncChange.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRCoreDataStack;

FOUNDATION_EXPORT NSNotificationName const MRRSavedRecipesStoreDidChangeNotification;
FOUNDATION_EXPORT NSErrorDomain const MRRSavedRecipesStoreErrorDomain;

@interface MRRSavedRecipesStore : NSObject

- (instancetype)initWithCoreDataStack:(MRRCoreDataStack *)coreDataStack;

- (NSArray<MRRSavedRecipeSnapshot *> *)savedRecipesForUserID:(NSString *)userID error:(NSError *_Nullable *_Nullable)error;
- (nullable MRRSavedRecipeSnapshot *)savedRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)isRecipeSavedForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)saveRecipeSnapshot:(MRRSavedRecipeSnapshot *)snapshot error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (NSArray<MRRSavedRecipeSyncChange *> *)pendingSyncChangesForUserID:(NSString *)userID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)hasPendingSyncChangeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;
- (BOOL)markPendingSyncChangeProcessedForUserID:(NSString *)userID
                                       recipeID:(NSString *)recipeID
                                remoteUpdatedAt:(nullable NSDate *)remoteUpdatedAt
                                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)applyRemoteSnapshot:(MRRSavedRecipeSnapshot *)snapshot remoteUpdatedAt:(NSDate *)remoteUpdatedAt error:(NSError *_Nullable *_Nullable)error;
- (BOOL)applyRemoteDeletionForUserID:(NSString *)userID
                            recipeID:(NSString *)recipeID
                     remoteUpdatedAt:(NSDate *)remoteUpdatedAt
                               error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
