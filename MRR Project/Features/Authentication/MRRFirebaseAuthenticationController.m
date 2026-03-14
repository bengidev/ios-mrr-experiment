#import "MRRFirebaseAuthenticationController.h"

#import "MRRAuthSession.h"

@import FirebaseAuth;
@import FirebaseCore;
#import <GoogleSignIn/GoogleSignIn.h>

NSErrorDomain const MRRAuthenticationErrorDomain = @"com.bengidev.mrrproject.authentication";
NSString *const MRRAuthPendingLinkEmailUserInfoKey = @"MRRAuthPendingLinkEmailUserInfoKey";

static NSString *const MRRGoogleServiceInfoResourceName = @"GoogleService-Info";
static NSString *const MRRGoogleServiceInfoResourceType = @"plist";
static NSInteger const MRRFirebaseAuthErrorCodeAccountExistsWithDifferentCredential = 17012;

@interface MRRFirebaseAuthenticationController ()

@property(nonatomic, retain, nullable) FIRAuthCredential *pendingCredential;
@property(nonatomic, copy, nullable) NSString *pendingLinkEmailValue;

- (BOOL)isFirebaseConfigured;
- (nullable NSDictionary *)googleServiceConfiguration;
- (nullable NSString *)googleClientID;
- (nullable NSString *)googleReversedClientID;
- (BOOL)isRegisteredURLScheme:(NSString *)candidateScheme;
- (nullable MRRAuthSession *)sessionForCurrentUser;
- (nullable MRRAuthSession *)sessionForUser:(FIRUser *)user;
- (MRRAuthProviderType)primaryProviderTypeForUser:(FIRUser *)user;
- (NSError *)authenticationErrorWithCode:(MRRAuthenticationErrorCode)code description:(NSString *)description;
- (void)clearPendingCredentialLinkState;

@end

@implementation MRRFirebaseAuthenticationController

+ (BOOL)configureFirebaseIfPossible {
  if ([FIRApp defaultApp] != nil) {
    return YES;
  }

  NSString *configurationPath =
      [[NSBundle mainBundle] pathForResource:MRRGoogleServiceInfoResourceName ofType:MRRGoogleServiceInfoResourceType];
  if (configurationPath.length == 0) {
    return NO;
  }

  @try {
    [FIRApp configure];
    return [FIRApp defaultApp] != nil;
  } @catch (__unused NSException *exception) {
    return NO;
  }
}

- (void)dealloc {
  [_pendingLinkEmailValue release];
  [_pendingCredential release];
  [super dealloc];
}

- (nullable MRRAuthSession *)currentSession {
  return [self sessionForCurrentUser];
}

- (BOOL)hasPendingCredentialLink {
  return self.pendingCredential != nil;
}

- (nullable NSString *)pendingLinkEmail {
  return self.pendingLinkEmailValue;
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  if (![self isFirebaseConfigured]) {
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeUnconfigured
                                          description:@"Firebase belum siap untuk email sign up."]);
    return;
  }

  [[FIRAuth auth] createUserWithEmail:email
                             password:password
                           completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                             if (error != nil) {
                               completion(nil, error);
                               return;
                             }

                             completion([self sessionForUser:authResult.user], nil);
                           }];
}

- (void)signInWithEmail:(NSString *)email password:(NSString *)password completion:(MRRAuthSessionCompletion)completion {
  if (![self isFirebaseConfigured]) {
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeUnconfigured
                                          description:@"Firebase belum siap untuk email sign in."]);
    return;
  }

  [[FIRAuth auth] signInWithEmail:email
                         password:password
                       completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                         if (error != nil) {
                           completion(nil, error);
                           return;
                         }

                         completion([self sessionForUser:authResult.user], nil);
                       }];
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  if (![self isFirebaseConfigured]) {
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeUnconfigured
                                          description:@"Firebase belum siap untuk Google Sign-In."]);
    return;
  }

  NSString *clientID = [self googleClientID];
  if (clientID.length == 0) {
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeMissingGoogleClientID
                                          description:@"Google client ID belum tersedia."]);
    return;
  }

  NSString *reversedClientID = [self googleReversedClientID];
  if (reversedClientID.length == 0 || ![self isRegisteredURLScheme:reversedClientID]) {
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeMissingGoogleCallbackScheme
                                          description:@"URL scheme Google Sign-In belum didaftarkan."]);
    return;
  }

  GIDConfiguration *configuration = [[[GIDConfiguration alloc] initWithClientID:clientID] autorelease];
  [GIDSignIn sharedInstance].configuration = configuration;

  [[GIDSignIn sharedInstance]
      signInWithPresentingViewController:viewController
                              completion:^(GIDSignInResult *_Nullable signInResult, NSError *_Nullable error) {
                                if (error != nil) {
                                  if (error.code == kGIDSignInErrorCodeCanceled) {
                                    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeCancelled
                                                                          description:@"Google Sign-In dibatalkan."]);
                                    return;
                                  }

                                  completion(nil, error);
                                  return;
                                }

                                NSString *idToken = signInResult.user.idToken.tokenString;
                                NSString *accessToken = signInResult.user.accessToken.tokenString;
                                if (idToken.length == 0 || accessToken.length == 0) {
                                  completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeMissingGoogleToken
                                                                        description:@"Token Google belum tersedia."]);
                                  return;
                                }

                                FIRAuthCredential *credential =
                                    [FIRGoogleAuthProvider credentialWithIDToken:idToken accessToken:accessToken];

                                [[FIRAuth auth] signInWithCredential:credential
                                                          completion:^(FIRAuthDataResult *_Nullable authResult,
                                                                       NSError *_Nullable authError) {
                                                            if (authError != nil) {
                                                              if (authError.code ==
                                                                  MRRFirebaseAuthErrorCodeAccountExistsWithDifferentCredential) {
                                                                self.pendingCredential = credential;
                                                                self.pendingLinkEmailValue = signInResult.user.profile.email;

                                                                NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                                                                if (self.pendingLinkEmailValue.length > 0) {
                                                                  userInfo[MRRAuthPendingLinkEmailUserInfoKey] = self.pendingLinkEmailValue;
                                                                }

                                                                NSError *linkError = [NSError errorWithDomain:MRRAuthenticationErrorDomain
                                                                                                         code:MRRAuthenticationErrorCodeRequiresAccountLinking
                                                                                                     userInfo:userInfo];
                                                                completion(nil, linkError);
                                                                return;
                                                              }

                                                              completion(nil, authError);
                                                              return;
                                                            }

                                                            [self clearPendingCredentialLinkState];
                                                            completion([self sessionForUser:authResult.user], nil);
                                                          }];
                              }];
}

- (void)linkCredentialIfNeededWithCompletion:(MRRAuthCompletion)completion {
  if (self.pendingCredential == nil) {
    completion(nil);
    return;
  }

  if (![self isFirebaseConfigured] || [FIRAuth auth].currentUser == nil) {
    completion([self authenticationErrorWithCode:MRRAuthenticationErrorCodeNoCurrentSession
                                     description:@"Tidak ada sesi aktif untuk menyelesaikan link akun."]);
    return;
  }

  FIRAuthCredential *pendingCredential = [[self.pendingCredential retain] autorelease];
  [[FIRAuth auth].currentUser linkWithCredential:pendingCredential
                                      completion:^(__unused FIRAuthDataResult *_Nullable authResult,
                                                   NSError *_Nullable error) {
                                        if (error == nil) {
                                          [self clearPendingCredentialLinkState];
                                        }

                                        completion(error);
                                      }];
}

- (BOOL)signOut:(NSError *_Nullable *_Nullable)error {
  [[GIDSignIn sharedInstance] signOut];
  [self clearPendingCredentialLinkState];

  if (![self isFirebaseConfigured]) {
    return YES;
  }

  return [[FIRAuth auth] signOut:error];
}

- (BOOL)isFirebaseConfigured {
  return [FIRApp defaultApp] != nil;
}

- (nullable NSDictionary *)googleServiceConfiguration {
  NSString *configurationPath =
      [[NSBundle mainBundle] pathForResource:MRRGoogleServiceInfoResourceName ofType:MRRGoogleServiceInfoResourceType];
  if (configurationPath.length == 0) {
    return nil;
  }

  return [NSDictionary dictionaryWithContentsOfFile:configurationPath];
}

- (nullable NSString *)googleClientID {
  if ([FIRApp defaultApp].options.clientID.length > 0) {
    return [FIRApp defaultApp].options.clientID;
  }

  return [self googleServiceConfiguration][@"CLIENT_ID"];
}

- (nullable NSString *)googleReversedClientID {
  return [self googleServiceConfiguration][@"REVERSED_CLIENT_ID"];
}

- (BOOL)isRegisteredURLScheme:(NSString *)candidateScheme {
  if (candidateScheme.length == 0) {
    return NO;
  }

  NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
  for (NSDictionary *urlType in urlTypes) {
    NSArray *schemes = urlType[@"CFBundleURLSchemes"];
    for (NSString *scheme in schemes) {
      if ([scheme isEqualToString:candidateScheme]) {
        return YES;
      }
    }
  }

  return NO;
}

- (nullable MRRAuthSession *)sessionForCurrentUser {
  if (![self isFirebaseConfigured]) {
    return nil;
  }

  FIRUser *currentUser = [FIRAuth auth].currentUser;
  if (currentUser == nil) {
    return nil;
  }

  return [self sessionForUser:currentUser];
}

- (nullable MRRAuthSession *)sessionForUser:(FIRUser *)user {
  if (user == nil) {
    return nil;
  }

  return [[[MRRAuthSession alloc] initWithUserID:user.uid
                                           email:user.email
                                     displayName:user.displayName
                                    providerType:[self primaryProviderTypeForUser:user]] autorelease];
}

- (MRRAuthProviderType)primaryProviderTypeForUser:(FIRUser *)user {
  for (id<FIRUserInfo> providerInfo in user.providerData) {
    if ([providerInfo.providerID isEqualToString:@"google.com"]) {
      return MRRAuthProviderTypeGoogle;
    }

    if ([providerInfo.providerID isEqualToString:@"password"]) {
      return MRRAuthProviderTypeEmail;
    }

    if ([providerInfo.providerID isEqualToString:@"apple.com"]) {
      return MRRAuthProviderTypeApple;
    }
  }

  return MRRAuthProviderTypeUnknown;
}

- (NSError *)authenticationErrorWithCode:(MRRAuthenticationErrorCode)code description:(NSString *)description {
  return [NSError errorWithDomain:MRRAuthenticationErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

- (void)clearPendingCredentialLinkState {
  self.pendingCredential = nil;
  self.pendingLinkEmailValue = nil;
}

@end
