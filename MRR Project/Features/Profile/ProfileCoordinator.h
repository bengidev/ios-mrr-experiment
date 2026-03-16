#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthenticationController.h"
#import "../MainMenu/MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

@interface ProfileCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;

@end

NS_ASSUME_NONNULL_END
