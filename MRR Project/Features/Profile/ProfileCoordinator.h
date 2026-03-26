#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthenticationController.h"
#import "../MainMenu/MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@protocol MRRLogoutCoordinating;

@interface ProfileCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;
- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                                logoutController:(nullable id<MRRLogoutCoordinating>)logoutController;

@end

NS_ASSUME_NONNULL_END
