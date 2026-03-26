#import "SavedCoordinator.h"

#import "../../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "SavedViewController.h"

@interface SavedCoordinator ()

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) id<MRRSavedRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain, nullable) SavedViewController *viewController;
@property(nonatomic, retain, nullable) UITabBarItem *tabBarItemValue;

@end

@implementation SavedCoordinator

- (instancetype)init {
  return [self initWithSessionUserID:nil savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                     savedRecipesStore:(MRRSavedRecipesStore *)savedRecipesStore
                           syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  self = [super init];
  if (self) {
    _sessionUserID = [sessionUserID copy];
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
  [_sessionUserID release];
  [super dealloc];
}

- (UIViewController *)rootViewController {
  if (self.viewController == nil) {
    self.viewController = [[[SavedViewController alloc] initWithSessionUserID:self.sessionUserID
                                                            savedRecipesStore:self.savedRecipesStore
                                                                  syncEngine:self.syncEngine] autorelease];
  }

  return self.viewController;
}

- (UITabBarItem *)tabBarItem {
  if (self.tabBarItemValue == nil) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:@"bookmark.fill"];
    }

    self.tabBarItemValue = [[[UITabBarItem alloc] initWithTitle:@"Saved" image:image tag:1] autorelease];
  }

  return self.tabBarItemValue;
}

@end
