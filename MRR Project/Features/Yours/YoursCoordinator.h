#import <Foundation/Foundation.h>

#import "../MainMenu/MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRUserRecipesStore;
@protocol MRRUserRecipesCloudSyncing;

@interface YoursCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)init;
- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                     userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(nullable id<MRRUserRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
