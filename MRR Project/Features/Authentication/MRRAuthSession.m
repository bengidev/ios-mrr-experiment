#import "MRRAuthSession.h"

NSString *MRRAuthDisplayNameForProviderType(MRRAuthProviderType providerType) {
  switch (providerType) {
    case MRRAuthProviderTypeEmail:
      return @"Email";
    case MRRAuthProviderTypeGoogle:
      return @"Google";
    case MRRAuthProviderTypeApple:
      return @"Apple";
    case MRRAuthProviderTypeUnknown:
    default:
      return @"Unknown";
  }
}

@interface MRRAuthSession ()

@property(nonatomic, copy, readwrite) NSString *userID;
@property(nonatomic, copy, readwrite, nullable) NSString *email;
@property(nonatomic, copy, readwrite, nullable) NSString *displayName;
@property(nonatomic, assign, readwrite) MRRAuthProviderType providerType;
@property(nonatomic, assign, readwrite) BOOL emailVerified;

@end

@implementation MRRAuthSession

- (instancetype)initWithUserID:(NSString *)userID
                         email:(NSString *)email
                   displayName:(NSString *)displayName
                  providerType:(MRRAuthProviderType)providerType
                 emailVerified:(BOOL)emailVerified {
  NSParameterAssert(userID.length > 0);

  self = [super init];
  if (self) {
    _userID = [userID copy];
    _email = [email copy];
    _displayName = [displayName copy];
    _providerType = providerType;
    _emailVerified = emailVerified;
  }

  return self;
}

- (void)dealloc {
  [_displayName release];
  [_email release];
  [_userID release];
  [super dealloc];
}

- (NSString *)displayNameOrFallback {
  if (self.displayName.length > 0) {
    return self.displayName;
  }

  if (self.email.length > 0) {
    return self.email;
  }

  return @"Culina Cook";
}

@end
