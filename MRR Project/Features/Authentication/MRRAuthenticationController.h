#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@class UIViewController;

typedef void (^MRRAuthSessionCompletion)(MRRAuthSession *_Nullable session, NSError *_Nullable error);
typedef void (^MRRAuthCompletion)(NSError *_Nullable error);

FOUNDATION_EXPORT NSErrorDomain const MRRAuthenticationErrorDomain;
FOUNDATION_EXPORT NSString *const MRRAuthPendingLinkEmailUserInfoKey;

typedef NS_ENUM(NSInteger, MRRAuthenticationErrorCode) {
  MRRAuthenticationErrorCodeUnconfigured = 1,
  MRRAuthenticationErrorCodeMissingGoogleClientID = 2,
  MRRAuthenticationErrorCodeMissingGoogleCallbackScheme = 3,
  MRRAuthenticationErrorCodeMissingGoogleToken = 4,
  MRRAuthenticationErrorCodeRequiresAccountLinking = 5,
  MRRAuthenticationErrorCodeCancelled = 6,
  MRRAuthenticationErrorCodeNoCurrentSession = 7,
};

@protocol MRRAuthenticationController <NSObject>

- (nullable MRRAuthSession *)currentSession;
- (BOOL)hasPendingCredentialLink;
- (nullable NSString *)pendingLinkEmail;
- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion;
- (void)signInWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion;
- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion;
- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion;
- (BOOL)signOut:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
