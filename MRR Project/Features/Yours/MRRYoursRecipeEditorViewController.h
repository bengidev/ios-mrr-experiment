#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRUserRecipeSnapshot;
@class MRRUserRecipesStore;
@protocol MRRUserRecipePhotoStorage;
@protocol MRRUserRecipesCloudSyncing;

@interface MRRYoursRecipeEditorViewController : UIViewController

- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                     userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(nullable id<MRRUserRecipesCloudSyncing>)syncEngine
                         photoStorage:(nullable id<MRRUserRecipePhotoStorage>)photoStorage
                       existingRecipe:(nullable MRRUserRecipeSnapshot *)existingRecipe;

@end

NS_ASSUME_NONNULL_END
