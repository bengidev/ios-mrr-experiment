#import "OnboardingStateController.h"

NSString *const MRRHasCompletedOnboardingDefaultsKey = @"com.mrrlearning.hasCompletedOnboarding";

@interface OnboardingStateController ()

@property(nonatomic, retain) NSUserDefaults *userDefaults;

@end

@implementation OnboardingStateController

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
  NSParameterAssert(userDefaults != nil);

  self = [super init];
  if (self) {
    _userDefaults = [userDefaults retain];
  }

  return self;
}

- (void)dealloc {
  [_userDefaults release];
  [super dealloc];
}

- (BOOL)hasCompletedOnboarding {
  return [self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey];
}

- (void)markOnboardingCompleted {
  [self.userDefaults setBool:YES forKey:MRRHasCompletedOnboardingDefaultsKey];
}

@end
