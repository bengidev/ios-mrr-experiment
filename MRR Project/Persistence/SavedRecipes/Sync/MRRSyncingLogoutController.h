#import <Foundation/Foundation.h>

#import "../../../Features/Authentication/MRRAuthenticationController.h"
#import "MRRSavedRecipesCloudSyncing.h"
#import "../../UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

typedef void (^MRRLogoutCompletion)(NSError *_Nullable error);

@protocol MRRLogoutCoordinating <NSObject>

- (void)performLogoutForSession:(MRRAuthSession *)session completion:(MRRLogoutCompletion)completion;

@end

@interface MRRSyncingLogoutController : NSObject <MRRLogoutCoordinating>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                      syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine;
- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                          savedRecipesSyncEngine:(id<MRRSavedRecipesCloudSyncing>)savedRecipesSyncEngine
                           userRecipesSyncEngine:(nullable id<MRRUserRecipesCloudSyncing>)userRecipesSyncEngine;

@end

NS_ASSUME_NONNULL_END
