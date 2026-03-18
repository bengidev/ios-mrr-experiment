#import <Foundation/Foundation.h>

#import "OnboardingRecipeModels.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MRROnboardingRecipeCataloging <NSObject>

- (NSArray<OnboardingRecipePreview *> *)allRecipePreviews;

@end

@interface OnboardingRecipeCatalog : NSObject <MRROnboardingRecipeCataloging>

@end

NS_ASSUME_NONNULL_END
