#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipe;
@class OnboardingRecipeDetailViewController;

@protocol OnboardingRecipeDetailViewControllerDelegate <NSObject>

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController;
- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController;

@end

@interface OnboardingRecipeDetailViewController : UIViewController

@property(nonatomic, assign, nullable) id<OnboardingRecipeDetailViewControllerDelegate> delegate;
@property(nonatomic, retain, readonly) OnboardingRecipe *recipe;

- (instancetype)initWithRecipe:(OnboardingRecipe *)recipe;

@end

NS_ASSUME_NONNULL_END
