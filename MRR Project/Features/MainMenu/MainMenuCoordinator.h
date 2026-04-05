#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthenticationController.h"
#import "MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@class MRRSavedRecipesStore;
@class MRRUserRecipesStore;
@protocol MRRLogoutCoordinating;
@protocol MRRSavedRecipesCloudSyncing;
@protocol MRRUserRecipesCloudSyncing;

@interface MainMenuCoordinator : NSObject <MRRFeatureCoordinator>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController session:(MRRAuthSession *)session;
- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                               savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                                      syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine
                                userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                                  userSyncEngine:(nullable id<MRRUserRecipesCloudSyncing>)userSyncEngine
                                logoutController:(nullable id<MRRLogoutCoordinating>)logoutController;

@end

NS_ASSUME_NONNULL_END
