#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipe;

@interface OnboardingRecipeCarouselCell : UICollectionViewCell

- (void)configureWithRecipe:(OnboardingRecipe *)recipe;

@end

NS_ASSUME_NONNULL_END
