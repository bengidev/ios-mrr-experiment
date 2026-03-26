#import "MainMenuCoordinator.h"

#import "../Authentication/MRRAuthSession.h"
#import "../Home/HomeCoordinator.h"
#import "../Profile/ProfileCoordinator.h"
#import "../Saved/SavedCoordinator.h"
#import "../../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSyncingLogoutController.h"
#import "MainMenuTabBarController.h"

@interface MainMenuCoordinator ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) id<MRRSavedRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain, nullable) id<MRRLogoutCoordinating> logoutController;
@property(nonatomic, retain, nullable) HomeCoordinator *homeCoordinator;
@property(nonatomic, retain, nullable) SavedCoordinator *savedCoordinator;
@property(nonatomic, retain, nullable) ProfileCoordinator *profileCoordinator;
@property(nonatomic, retain, nullable) MainMenuTabBarController *tabBarController;

- (UINavigationController *)navigationControllerForTabFeatureCoordinator:(id<MRRTabFeatureCoordinator>)featureCoordinator;

@end

@implementation MainMenuCoordinator

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session {
  return [self initWithAuthenticationController:authenticationController
                                        session:session
                               savedRecipesStore:nil
                                     syncEngine:nil
                                logoutController:nil];
}

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session
                                savedRecipesStore:(MRRSavedRecipesStore *)savedRecipesStore
                                      syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine
                                 logoutController:(id<MRRLogoutCoordinating>)logoutController {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(session != nil);

  self = [super init];
  if (self) {
    _authenticationController = [authenticationController retain];
    _session = [session retain];
    _savedRecipesStore = [savedRecipesStore retain];
    _syncEngine = [syncEngine retain];
    _logoutController = [logoutController retain];
  }

  return self;
}

- (void)dealloc {
  [_tabBarController release];
  [_profileCoordinator release];
  [_savedCoordinator release];
  [_homeCoordinator release];
  [_logoutController release];
  [_syncEngine release];
  [_savedRecipesStore release];
  [_session release];
  [_authenticationController release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.tabBarController == nil) {
    self.homeCoordinator = [[[HomeCoordinator alloc] initWithSession:self.session
                                                        dataProvider:nil
                                                    savedRecipesStore:self.savedRecipesStore
                                                          syncEngine:self.syncEngine] autorelease];
    self.savedCoordinator = [[[SavedCoordinator alloc] initWithSessionUserID:self.session.userID
                                                            savedRecipesStore:self.savedRecipesStore
                                                                  syncEngine:self.syncEngine] autorelease];
    self.profileCoordinator =
        [[[ProfileCoordinator alloc] initWithAuthenticationController:self.authenticationController
                                                             session:self.session
                                                    logoutController:self.logoutController] autorelease];

    NSArray<UIViewController *> *tabViewControllers = @[
      [self navigationControllerForTabFeatureCoordinator:self.homeCoordinator],
      [self navigationControllerForTabFeatureCoordinator:self.savedCoordinator],
      [self navigationControllerForTabFeatureCoordinator:self.profileCoordinator]
    ];

    self.tabBarController = [[[MainMenuTabBarController alloc] initWithTabViewControllers:tabViewControllers] autorelease];
  }

  return self.tabBarController;
}

- (UINavigationController *)navigationControllerForTabFeatureCoordinator:(id<MRRTabFeatureCoordinator>)featureCoordinator {
  UIViewController *rootViewController = [featureCoordinator rootViewController];
  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:rootViewController] autorelease];
  navigationController.tabBarItem = [featureCoordinator tabBarItem];
  if (@available(iOS 11.0, *)) {
    navigationController.navigationBar.prefersLargeTitles = NO;
  }
  return navigationController;
}

@end
