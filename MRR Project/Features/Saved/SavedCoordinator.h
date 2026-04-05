#import <Foundation/Foundation.h>

#import "../MainMenu/MRRFeatureCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRSavedRecipesStore;
@protocol MRRSavedRecipesCloudSyncing;

@interface SavedCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)init;
- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                    savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                           syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
