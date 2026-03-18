#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipePreview;

@interface OnboardingRecipeCarouselCell : UICollectionViewCell

@property(nonatomic, assign) BOOL showsTextOverlay;
@property(nonatomic, assign) BOOL showsShimmerLoading;

- (void)configureWithRecipePreview:(OnboardingRecipePreview *)recipePreview;

@end

NS_ASSUME_NONNULL_END
