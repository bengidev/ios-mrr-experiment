#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipe;

@interface OnboardingRecipeCarouselCell : UICollectionViewCell

@property(nonatomic, assign) BOOL showsTextOverlay;

- (void)configureWithRecipe:(OnboardingRecipe *)recipe;

@end

NS_ASSUME_NONNULL_END
