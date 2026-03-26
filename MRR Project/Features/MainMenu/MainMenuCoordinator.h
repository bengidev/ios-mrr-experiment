#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthenticationController.h"
#import "MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@class MRRSavedRecipesStore;
@protocol MRRLogoutCoordinating;
@protocol MRRSavedRecipesCloudSyncing;

@interface MainMenuCoordinator : NSObject <MRRFeatureCoordinator>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;
- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                                savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                                      syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine
                                 logoutController:(nullable id<MRRLogoutCoordinating>)logoutController;

@end

NS_ASSUME_NONNULL_END
