#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRSavedRecipesStore;
@protocol MRRSavedRecipesCloudSyncing;

@interface SavedViewController : UIViewController

- (instancetype)init;
- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                    savedRecipesStore:(nullable MRRSavedRecipesStore *)savedRecipesStore
                           syncEngine:(nullable id<MRRSavedRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
