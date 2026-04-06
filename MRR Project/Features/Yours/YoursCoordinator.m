#import "YoursCoordinator.h"

#import "../../Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../../Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"
#import "YoursViewController.h"

static NSString *const MRRYoursCoordinatorLogPrefix = @"[YoursCoordinator]";

@interface YoursCoordinator ()

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, retain, nullable) MRRUserRecipesStore *userRecipesStore;
@property(nonatomic, retain, nullable) id<MRRUserRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain, nullable) YoursViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation YoursCoordinator

- (instancetype)init {
  NSLog(@"%@ init called", MRRYoursCoordinatorLogPrefix);
  return [self initWithSessionUserID:nil userRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                     userRecipesStore:(MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(id<MRRUserRecipesCloudSyncing>)syncEngine {
  self = [super init];
  if (self) {
    _sessionUserID = [sessionUserID copy];
    _userRecipesStore = [userRecipesStore retain];
    _syncEngine = [syncEngine retain];
    
    NSLog(@"%@ Initialized with sessionUserID: %@, userRecipesStore: %@, syncEngine: %@",
          MRRYoursCoordinatorLogPrefix,
          sessionUserID ?: @"nil",
          userRecipesStore ? @"provided" : @"nil",
          syncEngine ? @"provided" : @"nil");
  }

  return self;
}

- (void)dealloc {
  NSLog(@"%@ dealloc called", MRRYoursCoordinatorLogPrefix);
  [_tabBarItemValue release];
  [_viewController release];
  [_syncEngine release];
  [_userRecipesStore release];
  [_sessionUserID release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[YoursViewController alloc] initWithSessionUserID:self.sessionUserID
                                                             userRecipesStore:self.userRecipesStore
                                                                   syncEngine:self.syncEngine] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"square.and.pencil"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Yours" image:image tag:2] autorelease];
  }

  return self.tabBarItemValue;
}

@end
