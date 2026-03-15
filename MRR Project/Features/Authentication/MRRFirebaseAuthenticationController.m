#import "MRRFirebaseAuthenticationController.h"

#import "MRRAuthSession.h"

#import <stdarg.h>

@import FirebaseAuth;
@import FirebaseCore;
#import <GoogleSignIn/GoogleSignIn.h>

NSErrorDomain const MRRAuthenticationErrorDomain = @"com.bengidev.mrrproject.authentication";
NSString *const MRRAuthPendingLinkEmailUserInfoKey = @"MRRAuthPendingLinkEmailUserInfoKey";

static NSString *const MRRGoogleServiceInfoResourceName = @"GoogleService-Info";
static NSString *const MRRGoogleServiceInfoResourceType = @"plist";
static NSInteger const MRRFirebaseAuthErrorCodeAccountExistsWithDifferentCredential = 17012;
static NSInteger const MRRFirebaseAuthErrorCodeUserNotFound = 17011;

#if DEBUG
static void MRRAuthDebugLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static void MRRAuthDebugLog(NSString *format, ...) {
  va_list arguments;
  va_start(arguments, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
  va_end(arguments);
  NSLog(@"[AuthDebug] %@", message);
}
#else
static void MRRAuthDebugLog(__unused NSString *format, ...) {}
#endif

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
- (NSString *)providerIdentifiersDescriptionForUser:(FIRUser *)user;
- (void)debugLogSessionSnapshotForUser:(FIRUser *)user source:(NSString *)source;
- (NSError *)authenticationErrorWithCode:(MRRAuthenticationErrorCode)code description:(NSString *)description;
- (void)clearPendingCredentialLinkState;

@end

@implementation MRRFirebaseAuthenticationController

+ (BOOL)configureFirebaseIfPossible {
  if ([FIRApp defaultApp] != nil) {
    MRRAuthDebugLog(@"Firebase already configured for project=%@.", [FIRApp defaultApp].options.projectID ?: @"(unknown)");
    return YES;
  }

  NSString *configurationPath = [[NSBundle mainBundle] pathForResource:MRRGoogleServiceInfoResourceName ofType:MRRGoogleServiceInfoResourceType];
  if (configurationPath.length == 0) {
    MRRAuthDebugLog(@"Firebase configure skipped because GoogleService-Info.plist is missing from the app bundle.");
    return NO;
  }

  @try {
    [FIRApp configure];
    MRRAuthDebugLog(@"Firebase configure finished. defaultApp=%@ project=%@", [FIRApp defaultApp] != nil ? @"YES" : @"NO",
                    [FIRApp defaultApp].options.projectID ?: @"(unknown)");
    return [FIRApp defaultApp] != nil;
  } @catch (__unused NSException *exception) {
    MRRAuthDebugLog(@"Firebase configure threw an exception.");
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

- (void)sendPasswordResetForEmail:(NSString *)email completion:(MRRAuthCompletion)completion {
  if (![self isFirebaseConfigured]) {
    completion([self authenticationErrorWithCode:MRRAuthenticationErrorCodeUnconfigured description:@"Firebase belum siap untuk reset password."]);
    return;
  }

  [[FIRAuth auth] sendPasswordResetWithEmail:email
                                  completion:^(NSError *_Nullable error) {
                                    if (error != nil &&
                                        !([error.domain isEqualToString:FIRAuthErrorDomain] && error.code == MRRFirebaseAuthErrorCodeUserNotFound)) {
                                      completion(error);
                                      return;
                                    }

                                    completion(nil);
                                  }];
}

- (void)signInWithGoogleFromPresentingViewController:(UIViewController *)viewController completion:(MRRAuthSessionCompletion)completion {
  MRRAuthDebugLog(@"Google Sign-In requested from presenter=%@.", NSStringFromClass([viewController class]));

  if (![self isFirebaseConfigured]) {
    MRRAuthDebugLog(@"Google Sign-In aborted because Firebase is not configured.");
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeUnconfigured
                                          description:@"Firebase belum siap untuk Google Sign-In."]);
    return;
  }

  NSString *clientID = [self googleClientID];
  if (clientID.length == 0) {
    MRRAuthDebugLog(@"Google Sign-In aborted because CLIENT_ID is missing.");
    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeMissingGoogleClientID
                                          description:@"Google client ID belum tersedia."]);
    return;
  }

  NSString *reversedClientID = [self googleReversedClientID];
  if (reversedClientID.length == 0 || ![self isRegisteredURLScheme:reversedClientID]) {
    MRRAuthDebugLog(@"Google Sign-In aborted because callback URL scheme is missing or not registered. reversedClientID=%@",
                    reversedClientID ?: @"(nil)");
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
                                    MRRAuthDebugLog(@"Google Sign-In was cancelled by the user.");
                                    completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeCancelled
                                                                          description:@"Google Sign-In dibatalkan."]);
                                    return;
                                  }

                                  MRRAuthDebugLog(@"Google Sign-In failed before Firebase handoff. domain=%@ code=%ld description=%@", error.domain,
                                                  (long)error.code, error.localizedDescription ?: @"");
                                  completion(nil, error);
                                  return;
                                }

                                MRRAuthDebugLog(@"Google Sign-In returned account email=%@.", signInResult.user.profile.email ?: @"(no email)");
                                NSString *idToken = signInResult.user.idToken.tokenString;
                                NSString *accessToken = signInResult.user.accessToken.tokenString;
                                if (idToken.length == 0 || accessToken.length == 0) {
                                  MRRAuthDebugLog(@"Google Sign-In finished but tokens were missing.");
                                  completion(nil, [self authenticationErrorWithCode:MRRAuthenticationErrorCodeMissingGoogleToken
                                                                        description:@"Token Google belum tersedia."]);
                                  return;
                                }

                                FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:idToken accessToken:accessToken];

                                [[FIRAuth auth]
                                    signInWithCredential:credential
                                              completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable authError) {
                                                if (authError != nil) {
                                                  if (authError.code == MRRFirebaseAuthErrorCodeAccountExistsWithDifferentCredential) {
                                                    self.pendingCredential = credential;
                                                    self.pendingLinkEmailValue = signInResult.user.profile.email;
                                                    MRRAuthDebugLog(@"Google Sign-In requires account linking for email=%@.",
                                                                    self.pendingLinkEmailValue ?: @"(no email)");

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

                                                  MRRAuthDebugLog(@"Firebase signInWithCredential failed. domain=%@ code=%ld description=%@",
                                                                  authError.domain, (long)authError.code, authError.localizedDescription ?: @"");
                                                  completion(nil, authError);
                                                  return;
                                                }

                                                [self clearPendingCredentialLinkState];
                                                [self debugLogSessionSnapshotForUser:authResult.user source:@"google_sign_in_success"];
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
  MRRAuthDebugLog(@"Attempting pending credential link for current uid=%@.", [FIRAuth auth].currentUser.uid ?: @"(no uid)");
  [[FIRAuth auth].currentUser linkWithCredential:pendingCredential
                                      completion:^(__unused FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error) {
                                        if (error == nil) {
                                          MRRAuthDebugLog(@"Pending credential link succeeded.");
                                          [self debugLogSessionSnapshotForUser:[FIRAuth auth].currentUser source:@"link_credential_success"];
                                          [self clearPendingCredentialLinkState];
                                        } else {
                                          MRRAuthDebugLog(@"Pending credential link failed. domain=%@ code=%ld description=%@", error.domain,
                                                          (long)error.code, error.localizedDescription ?: @"");
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
  NSString *configurationPath = [[NSBundle mainBundle] pathForResource:MRRGoogleServiceInfoResourceName ofType:MRRGoogleServiceInfoResourceType];
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
    MRRAuthDebugLog(@"currentSession requested but Firebase is not configured yet.");
    return nil;
  }

  FIRUser *currentUser = [FIRAuth auth].currentUser;
  if (currentUser == nil) {
    MRRAuthDebugLog(@"currentSession requested and no active Firebase user exists.");
    return nil;
  }

  [self debugLogSessionSnapshotForUser:currentUser source:@"current_session"];
  return [self sessionForUser:currentUser];
}

- (nullable MRRAuthSession *)sessionForUser:(FIRUser *)user {
  if (user == nil) {
    return nil;
  }

  return [[[MRRAuthSession alloc] initWithUserID:user.uid
                                           email:user.email
                                     displayName:user.displayName
                                    providerType:[self primaryProviderTypeForUser:user]
                                   emailVerified:user.emailVerified] autorelease];
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

- (NSString *)providerIdentifiersDescriptionForUser:(FIRUser *)user {
  NSMutableArray<NSString *> *providerIDs = [NSMutableArray array];
  for (id<FIRUserInfo> providerInfo in user.providerData) {
    if (providerInfo.providerID.length > 0) {
      [providerIDs addObject:providerInfo.providerID];
    }
  }

  if (providerIDs.count == 0) {
    return @"(none)";
  }

  return [providerIDs componentsJoinedByString:@", "];
}

- (void)debugLogSessionSnapshotForUser:(FIRUser *)user source:(NSString *)source {
  if (user == nil) {
    MRRAuthDebugLog(@"Session snapshot [%@]: user is nil.", source ?: @"unknown");
    return;
  }

  MRRAuthProviderType providerType = [self primaryProviderTypeForUser:user];
  MRRAuthDebugLog(@"Session snapshot [%@]: uid=%@ email=%@ displayName=%@ provider=%@ providerIDs=%@ emailVerified=%@", source ?: @"unknown",
                  user.uid ?: @"(no uid)", user.email ?: @"(no email)", user.displayName ?: @"(no display name)",
                  MRRAuthDisplayNameForProviderType(providerType), [self providerIdentifiersDescriptionForUser:user],
                  user.emailVerified ? @"YES" : @"NO");
}

- (NSError *)authenticationErrorWithCode:(MRRAuthenticationErrorCode)code description:(NSString *)description {
  return [NSError errorWithDomain:MRRAuthenticationErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : description}];
}

- (void)clearPendingCredentialLinkState {
  self.pendingCredential = nil;
  self.pendingLinkEmailValue = nil;
}

@end
