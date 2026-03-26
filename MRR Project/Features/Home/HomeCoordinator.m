#import "HomeCoordinator.h"

#import "../../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "HomeViewController.h"

@interface HomeCoordinator ()

@property(nonatomic, retain, nullable) MRRAuthSession *session;
@property(nonatomic, retain) id<HomeDataProviding> dataProvider;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) id<MRRSavedRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain, nullable) HomeViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation HomeCoordinator

- (instancetype)init {
  return [self initWithSession:nil dataProvider:nil savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSession:(MRRAuthSession *)session {
  return [self initWithSession:session dataProvider:nil savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSession:(MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider {
  return [self initWithSession:session dataProvider:dataProvider savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSession:(MRRAuthSession *)session
                   dataProvider:(id<HomeDataProviding>)dataProvider
               savedRecipesStore:(MRRSavedRecipesStore *)savedRecipesStore
                     syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  self = [super init];
  if (self) {
    _session = [session retain];
    _dataProvider = [dataProvider != nil ? dataProvider : [[[HomeCompositeDataProvider alloc] init] autorelease] retain];
    _savedRecipesStore = [savedRecipesStore retain];
    _syncEngine = [syncEngine retain];
  }

  return self;
}

- (void)dealloc {
  [_tabBarItemValue release];
  [_viewController release];
  [_syncEngine release];
  [_savedRecipesStore release];
  [_dataProvider release];
  [_session release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[HomeViewController alloc] initWithSession:self.session
                                                          dataProvider:self.dataProvider
                                                      savedRecipesStore:self.savedRecipesStore
                                                            syncEngine:self.syncEngine] autorelease];
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
