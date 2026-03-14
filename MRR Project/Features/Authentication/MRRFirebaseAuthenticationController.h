#import <Foundation/Foundation.h>

#import "MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRRFirebaseAuthenticationController : NSObject <MRRAuthenticationController>

+ (BOOL)configureFirebaseIfPossible;

@end

NS_ASSUME_NONNULL_END
