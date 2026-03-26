#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthSession.h"
#import "../MainMenu/MRRFeatureCoordinator.h"
#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRSavedRecipesStore;
@protocol MRRSavedRecipesCloudSyncing;

@interface HomeCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)init;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session dataProvider:(nullable id<HomeDataProviding>)dataProvider;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session
                   dataProvider:(nullable id<HomeDataProviding>)dataProvider
               savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                     syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
