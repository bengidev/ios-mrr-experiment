#import "ProfileCoordinator.h"

#import "../Authentication/MRRAuthSession.h"
#import "ProfileViewController.h"

@interface ProfileCoordinator ()

@property(nonatomic, retain) id<MRRAuthenticationController> authenticationController;
@property(nonatomic, retain) MRRAuthSession *session;
@property(nonatomic, retain, nullable) ProfileViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation ProfileCoordinator

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
  [_tabBarItemValue release];
  [_viewController release];
  [_session release];
  [_authenticationController release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[ProfileViewController alloc] initWithAuthenticationController:self.authenticationController
                                                                                   session:self.session] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Profile" image:image tag:2] autorelease];
  }

  return self.tabBarItemValue;
}

@end
