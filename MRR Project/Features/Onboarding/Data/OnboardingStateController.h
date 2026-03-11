#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MRRHasCompletedOnboardingDefaultsKey;

@interface OnboardingRecipeInstruction : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *detailText;

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText;

@end

@interface OnboardingRecipe : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly) NSString *durationText;
@property(nonatomic, copy, readonly) NSString *calorieText;
@property(nonatomic, copy, readonly) NSString *servingsText;
@property(nonatomic, copy, readonly) NSString *summaryText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *ingredients;
@property(nonatomic, copy, readonly) NSArray<OnboardingRecipeInstruction *> *instructions;

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                    assetName:(NSString *)assetName
                 durationText:(NSString *)durationText
                  calorieText:(NSString *)calorieText
                 servingsText:(NSString *)servingsText
                  summaryText:(NSString *)summaryText
                  ingredients:(NSArray<NSString *> *)ingredients
                 instructions:(NSArray<OnboardingRecipeInstruction *> *)instructions;

@end

@interface OnboardingStateController : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (NSArray<OnboardingRecipe *> *)onboardingRecipes;
- (BOOL)hasCompletedOnboarding;
- (void)markOnboardingCompleted;

@end

NS_ASSUME_NONNULL_END
