#import <Foundation/Foundation.h>

#import "MRRUserRecipesCloudSyncing.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRUserRecipesStore;

@interface MRRUserRecipesSyncEngine : NSObject <MRRUserRecipesCloudSyncing>

- (instancetype)initWithStore:(MRRUserRecipesStore *)store;

@end

NS_ASSUME_NONNULL_END
