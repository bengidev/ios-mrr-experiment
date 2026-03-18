#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MRRHasCompletedOnboardingDefaultsKey;

@interface OnboardingStateController : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (BOOL)hasCompletedOnboarding;
- (void)markOnboardingCompleted;

@end

NS_ASSUME_NONNULL_END
