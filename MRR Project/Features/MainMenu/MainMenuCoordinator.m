#import "MainMenuCoordinator.h"

#import "../Authentication/MRRAuthSession.h"
#import "../Home/HomeCoordinator.h"
#import "../Profile/ProfileCoordinator.h"
#import "../Saved/SavedCoordinator.h"
#import "MainMenuTabBarController.h"

@interface MainMenuCoordinator ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain, nullable) HomeCoordinator *homeCoordinator;
@property(nonatomic, retain, nullable) SavedCoordinator *savedCoordinator;
@property(nonatomic, retain, nullable) ProfileCoordinator *profileCoordinator;
@property(nonatomic, retain, nullable) MainMenuTabBarController *tabBarController;

- (UINavigationController *)navigationControllerForTabFeatureCoordinator:(id<MRRTabFeatureCoordinator>)featureCoordinator;

@end

@implementation MainMenuCoordinator

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session {
  NSParameterAssert(authenticationController != nil);
  NSParameterAssert(session != nil);

  self = [super init];
  if (self) {
    _authenticationController = [authenticationController retain];
    _session = [session retain];
  }

  return self;
}

- (void)dealloc {
  [_tabBarController release];
  [_profileCoordinator release];
  [_savedCoordinator release];
  [_homeCoordinator release];
  [_session release];
  [_authenticationController release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.tabBarController == nil) {
    self.homeCoordinator = [[[HomeCoordinator alloc] init] autorelease];
    self.savedCoordinator = [[[SavedCoordinator alloc] init] autorelease];
    self.profileCoordinator =
        [[[ProfileCoordinator alloc] initWithAuthenticationController:self.authenticationController session:self.session] autorelease];

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
