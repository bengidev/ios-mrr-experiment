#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthenticationController.h"
#import "MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

@interface MainMenuCoordinator : NSObject <MRRFeatureCoordinator>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;

@end

NS_ASSUME_NONNULL_END
