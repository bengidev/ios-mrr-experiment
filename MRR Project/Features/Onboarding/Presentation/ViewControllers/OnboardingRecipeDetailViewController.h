#import <UIKit/UIKit.h>

#import "../../Data/OnboardingRecipeModels.h"

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipeDetailViewController;

typedef NS_ENUM(NSInteger, OnboardingRecipeDetailDebugOrigin) {
  OnboardingRecipeDetailDebugOriginUnknown = 0,
  OnboardingRecipeDetailDebugOriginLive = 1,
  OnboardingRecipeDetailDebugOriginFallback = 2,
};

@protocol OnboardingRecipeDetailViewControllerDelegate <NSObject>

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController;
- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController;
- (void)recipeDetailViewController:(OnboardingRecipeDetailViewController *)viewController didRequestFavoriteState:(BOOL)favorite;

@end

@interface OnboardingRecipeDetailViewController : UIViewController

@property(nonatomic, assign, nullable) id<OnboardingRecipeDetailViewControllerDelegate> delegate;
@property(nonatomic, retain, readonly) OnboardingRecipePreview *recipePreview;
@property(nonatomic, retain, readonly, nullable) OnboardingRecipeDetail *recipeDetail;
@property(nonatomic, assign, readonly, getter=isLoading) BOOL loading;
@property(nonatomic, assign) OnboardingRecipeDetailDebugOrigin debugOrigin;
@property(nonatomic, assign) BOOL showsFavoriteButton;
@property(nonatomic, assign, getter=isFavoriteSelected) BOOL favoriteSelected;
@property(nonatomic, assign, getter=isFavoriteButtonEnabled) BOOL favoriteButtonEnabled;

- (instancetype)initWithRecipePreview:(OnboardingRecipePreview *)recipePreview loading:(BOOL)loading;
- (instancetype)initWithRecipePreview:(OnboardingRecipePreview *)recipePreview recipeDetail:(OnboardingRecipeDetail *)recipeDetail;
- (void)updateWithRecipeDetail:(OnboardingRecipeDetail *)recipeDetail;
- (void)updateWithRecipeDetail:(OnboardingRecipeDetail *)recipeDetail debugOrigin:(OnboardingRecipeDetailDebugOrigin)debugOrigin;

@end

NS_ASSUME_NONNULL_END
