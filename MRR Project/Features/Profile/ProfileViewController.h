#import <UIKit/UIKit.h>

#import "../Authentication/MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

@interface ProfileViewController : UIViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;

@end

NS_ASSUME_NONNULL_END
