#import <UIKit/UIKit.h>

#import "../Authentication/MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@protocol MRRLogoutCoordinating;

@interface ProfileViewController : UIViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController session:(MRRAuthSession *)session;
- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                                logoutController:(nullable id<MRRLogoutCoordinating>)logoutController;

@end

NS_ASSUME_NONNULL_END
