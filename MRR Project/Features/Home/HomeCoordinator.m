#import "HomeCoordinator.h"

#import "HomeViewController.h"

@interface HomeCoordinator ()

@property(nonatomic, retain, nullable) MRRAuthSession *session;
@property(nonatomic, retain) id<HomeDataProviding> dataProvider;
@property(nonatomic, retain, nullable) HomeViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation HomeCoordinator

- (instancetype)init {
  return [self initWithSession:nil dataProvider:nil];
}

- (instancetype)initWithSession:(MRRAuthSession *)session {
  return [self initWithSession:session dataProvider:nil];
}

- (instancetype)initWithSession:(MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider {
  self = [super init];
  if (self) {
    _session = [session retain];
    _dataProvider = [dataProvider != nil ? dataProvider : [[[HomeCompositeDataProvider alloc] init] autorelease] retain];
  }

  return self;
}

- (void)dealloc {
  [_tabBarItemValue release];
  [_viewController release];
  [_dataProvider release];
  [_session release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[HomeViewController alloc] initWithSession:self.session dataProvider:self.dataProvider] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"house.fill"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Home" image:image tag:0] autorelease];
  }

  return self.tabBarItemValue;
}

@end
