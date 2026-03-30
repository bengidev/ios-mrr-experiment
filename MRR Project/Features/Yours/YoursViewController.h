#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRUserRecipesStore;
@protocol MRRUserRecipesCloudSyncing;

@interface YoursViewController : UIViewController

- (instancetype)init;
- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                     userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(nullable id<MRRUserRecipesCloudSyncing>)syncEngine;

@end

NS_ASSUME_NONNULL_END
