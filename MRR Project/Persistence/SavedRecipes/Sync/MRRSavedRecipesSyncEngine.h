#import <Foundation/Foundation.h>

#import "MRRSavedRecipesCloudSyncing.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRSavedRecipesStore;

@interface MRRSavedRecipesSyncEngine : NSObject <MRRSavedRecipesCloudSyncing>

- (instancetype)initWithStore:(MRRSavedRecipesStore *)store;

@end

NS_ASSUME_NONNULL_END
