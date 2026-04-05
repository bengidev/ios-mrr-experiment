#import <UIKit/UIKit.h>

#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;
@class MRRSavedRecipesStore;
@protocol MRRSavedRecipesCloudSyncing;

@interface HomeViewController : UIViewController

- (instancetype)init;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session
                   dataProvider:(id<HomeDataProviding>)dataProvider
              savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                     syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
