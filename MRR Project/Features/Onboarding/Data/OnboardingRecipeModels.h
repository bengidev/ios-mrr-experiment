#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipeDetail;

@interface OnboardingRecipeInstruction : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *detailText;

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText;

@end

@interface OnboardingRecipeIngredient : NSObject

@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *displayText;

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText;

@end

@interface OnboardingRecipeProductContext : NSObject

@property(nonatomic, copy, readonly) NSString *productName;
@property(nonatomic, copy, readonly, nullable) NSString *brandText;
@property(nonatomic, copy, readonly, nullable) NSString *nutritionGradeText;
@property(nonatomic, copy, readonly, nullable) NSString *quantityText;

- (instancetype)initWithProductName:(NSString *)productName
                          brandText:(nullable NSString *)brandText
                 nutritionGradeText:(nullable NSString *)nutritionGradeText
                       quantityText:(nullable NSString *)quantityText;

@end

@interface OnboardingRecipeDetail : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readonly) NSString *durationText;
@property(nonatomic, copy, readonly) NSString *calorieText;
@property(nonatomic, copy, readonly) NSString *servingsText;
@property(nonatomic, copy, readonly) NSString *summaryText;
@property(nonatomic, copy, readonly) NSArray<OnboardingRecipeIngredient *> *ingredients;
@property(nonatomic, copy, readonly) NSArray<OnboardingRecipeInstruction *> *instructions;
@property(nonatomic, copy, readonly) NSArray<NSString *> *tools;
@property(nonatomic, copy, readonly) NSArray<NSString *> *tags;
@property(nonatomic, copy, readonly, nullable) NSString *sourceName;
@property(nonatomic, copy, readonly, nullable) NSString *sourceURLString;
@property(nonatomic, retain, readonly, nullable) OnboardingRecipeProductContext *productContext;

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                    assetName:(NSString *)assetName
             heroImageURLString:(nullable NSString *)heroImageURLString
                 durationText:(NSString *)durationText
                  calorieText:(NSString *)calorieText
                 servingsText:(NSString *)servingsText
                  summaryText:(NSString *)summaryText
                  ingredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients
                 instructions:(NSArray<OnboardingRecipeInstruction *> *)instructions
                        tools:(NSArray<NSString *> *)tools
                         tags:(NSArray<NSString *> *)tags
                   sourceName:(nullable NSString *)sourceName
              sourceURLString:(nullable NSString *)sourceURLString
               productContext:(nullable OnboardingRecipeProductContext *)productContext;

@end

@interface OnboardingRecipePreview : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly, nullable) NSString *openFoodFactsBarcode;
@property(nonatomic, retain, readonly) OnboardingRecipeDetail *fallbackDetail;

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                    assetName:(NSString *)assetName
         openFoodFactsBarcode:(nullable NSString *)openFoodFactsBarcode
               fallbackDetail:(OnboardingRecipeDetail *)fallbackDetail;

@end

NS_ASSUME_NONNULL_END
