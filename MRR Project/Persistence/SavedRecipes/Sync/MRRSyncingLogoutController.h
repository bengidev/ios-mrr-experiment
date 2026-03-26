#import <Foundation/Foundation.h>

#import "../../../Features/Authentication/MRRAuthenticationController.h"
#import "MRRSavedRecipesCloudSyncing.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

typedef void (^MRRLogoutCompletion)(NSError *_Nullable error);

@protocol MRRLogoutCoordinating <NSObject>

- (void)performLogoutForSession:(MRRAuthSession *)session completion:(MRRLogoutCompletion)completion;

@end

@interface MRRSyncingLogoutController : NSObject <MRRLogoutCoordinating>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                      syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
