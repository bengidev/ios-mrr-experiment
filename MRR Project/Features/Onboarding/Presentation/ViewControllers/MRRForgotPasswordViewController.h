#import <UIKit/UIKit.h>

#import "../../../Authentication/MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRRForgotPasswordViewController : UIViewController

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                  prefilledEmail:(nullable NSString *)prefilledEmail;

@end

NS_ASSUME_NONNULL_END
