#import <Foundation/Foundation.h>

#import "../../../Features/Home/HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipeDetail;
@class OnboardingRecipePreview;

FOUNDATION_EXPORT NSString *const MRRSavedRecipeMealTypeBreakfast;
FOUNDATION_EXPORT NSString *const MRRSavedRecipeMealTypeLunch;
FOUNDATION_EXPORT NSString *const MRRSavedRecipeMealTypeDinner;
FOUNDATION_EXPORT NSString *const MRRSavedRecipeMealTypeDessert;
FOUNDATION_EXPORT NSString *const MRRSavedRecipeMealTypeSnack;

@interface MRRSavedRecipeIngredientSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *displayText;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText orderIndex:(NSInteger)orderIndex;

@end

@interface MRRSavedRecipeInstructionSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *detailText;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText orderIndex:(NSInteger)orderIndex;

@end

@interface MRRSavedRecipeStringSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *value;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithValue:(NSString *)value orderIndex:(NSInteger)orderIndex;

@end

@interface MRRSavedRecipeProductContextSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *productName;
@property(nonatomic, copy, readonly, nullable) NSString *brandText;
@property(nonatomic, copy, readonly, nullable) NSString *nutritionGradeText;
@property(nonatomic, copy, readonly, nullable) NSString *quantityText;

- (instancetype)initWithProductName:(NSString *)productName
                          brandText:(nullable NSString *)brandText
                 nutritionGradeText:(nullable NSString *)nutritionGradeText
                       quantityText:(nullable NSString *)quantityText;

@end

@interface MRRSavedRecipeSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *userID;
@property(nonatomic, copy, readonly) NSString *recipeID;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readonly) NSString *summaryText;
@property(nonatomic, copy, readonly) NSString *mealType;
@property(nonatomic, copy, readonly, nullable) NSString *sourceName;
@property(nonatomic, copy, readonly, nullable) NSString *sourceURLString;
@property(nonatomic, assign, readonly) NSInteger readyInMinutes;
@property(nonatomic, assign, readonly) NSInteger servings;
@property(nonatomic, assign, readonly) NSInteger calorieCount;
@property(nonatomic, assign, readonly) NSInteger popularityScore;
@property(nonatomic, copy, readonly) NSString *durationText;
@property(nonatomic, copy, readonly) NSString *calorieText;
@property(nonatomic, copy, readonly) NSString *servingsText;
@property(nonatomic, copy, readonly) NSArray<MRRSavedRecipeIngredientSnapshot *> *ingredients;
@property(nonatomic, copy, readonly) NSArray<MRRSavedRecipeInstructionSnapshot *> *instructions;
@property(nonatomic, copy, readonly) NSArray<MRRSavedRecipeStringSnapshot *> *tools;
@property(nonatomic, copy, readonly) NSArray<MRRSavedRecipeStringSnapshot *> *tags;
@property(nonatomic, retain, readonly, nullable) MRRSavedRecipeProductContextSnapshot *productContext;
@property(nonatomic, retain, readonly) NSDate *savedAt;
@property(nonatomic, retain, readonly) NSDate *localModifiedAt;
@property(nonatomic, retain, readonly, nullable) NSDate *remoteUpdatedAt;

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                     assetName:(NSString *)assetName
            heroImageURLString:(nullable NSString *)heroImageURLString
                   summaryText:(NSString *)summaryText
                      mealType:(NSString *)mealType
                    sourceName:(nullable NSString *)sourceName
               sourceURLString:(nullable NSString *)sourceURLString
                readyInMinutes:(NSInteger)readyInMinutes
                      servings:(NSInteger)servings
                  calorieCount:(NSInteger)calorieCount
               popularityScore:(NSInteger)popularityScore
                  durationText:(NSString *)durationText
                   calorieText:(NSString *)calorieText
                  servingsText:(NSString *)servingsText
                   ingredients:(NSArray<MRRSavedRecipeIngredientSnapshot *> *)ingredients
                  instructions:(NSArray<MRRSavedRecipeInstructionSnapshot *> *)instructions
                         tools:(NSArray<MRRSavedRecipeStringSnapshot *> *)tools
                          tags:(NSArray<MRRSavedRecipeStringSnapshot *> *)tags
                productContext:(nullable MRRSavedRecipeProductContextSnapshot *)productContext
                       savedAt:(NSDate *)savedAt
               localModifiedAt:(NSDate *)localModifiedAt
               remoteUpdatedAt:(nullable NSDate *)remoteUpdatedAt;

+ (instancetype)snapshotWithUserID:(NSString *)userID
                        recipeCard:(HomeRecipeCard *)recipeCard
                      recipeDetail:(OnboardingRecipeDetail *)recipeDetail
                           savedAt:(NSDate *)savedAt
                   localModifiedAt:(NSDate *)localModifiedAt;
- (OnboardingRecipeDetail *)recipeDetailRepresentation;
- (OnboardingRecipePreview *)recipePreviewRepresentation;
- (NSString *)sectionIdentifier;
- (NSString *)sectionTitle;

@end

NS_ASSUME_NONNULL_END
