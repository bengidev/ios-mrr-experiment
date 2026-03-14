#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRRAuthProviderType) {
  MRRAuthProviderTypeUnknown = 0,
  MRRAuthProviderTypeEmail = 1,
  MRRAuthProviderTypeGoogle = 2,
  MRRAuthProviderTypeApple = 3,
};

FOUNDATION_EXPORT NSString *MRRAuthDisplayNameForProviderType(MRRAuthProviderType providerType);

@interface MRRAuthSession : NSObject

@property(nonatomic, copy, readonly) NSString *userID;
@property(nonatomic, copy, readonly, nullable) NSString *email;
@property(nonatomic, copy, readonly, nullable) NSString *displayName;
@property(nonatomic, assign, readonly) MRRAuthProviderType providerType;

- (instancetype)initWithUserID:(NSString *)userID
                         email:(nullable NSString *)email
                   displayName:(nullable NSString *)displayName
                  providerType:(MRRAuthProviderType)providerType;

- (NSString *)displayNameOrFallback;

@end

NS_ASSUME_NONNULL_END
