#import <Foundation/Foundation.h>

#import "../../../Features/Home/HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class OnboardingRecipeDetail;

FOUNDATION_EXPORT NSString *const MRRUserRecipeMealTypeBreakfast;
FOUNDATION_EXPORT NSString *const MRRUserRecipeMealTypeLunch;
FOUNDATION_EXPORT NSString *const MRRUserRecipeMealTypeDinner;
FOUNDATION_EXPORT NSString *const MRRUserRecipeMealTypeDessert;
FOUNDATION_EXPORT NSString *const MRRUserRecipeMealTypeSnack;

@interface MRRUserRecipeIngredientSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *displayText;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText orderIndex:(NSInteger)orderIndex;

@end

@interface MRRUserRecipeInstructionSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *detailText;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText orderIndex:(NSInteger)orderIndex;

@end

@interface MRRUserRecipeStringSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *value;
@property(nonatomic, assign, readonly) NSInteger orderIndex;

- (instancetype)initWithValue:(NSString *)value orderIndex:(NSInteger)orderIndex;

@end

@interface MRRUserRecipePhotoSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *photoID;
@property(nonatomic, assign, readonly) NSInteger orderIndex;
@property(nonatomic, copy, readonly, nullable) NSString *remoteURLString;
@property(nonatomic, copy, readonly, nullable) NSString *localRelativePath;

- (instancetype)initWithPhotoID:(NSString *)photoID
                     orderIndex:(NSInteger)orderIndex
                remoteURLString:(nullable NSString *)remoteURLString
              localRelativePath:(nullable NSString *)localRelativePath;

@end

@interface MRRUserRecipeSnapshot : NSObject

@property(nonatomic, copy, readonly) NSString *userID;
@property(nonatomic, copy, readonly) NSString *recipeID;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *summaryText;
@property(nonatomic, copy, readonly) NSString *mealType;
@property(nonatomic, assign, readonly) NSInteger readyInMinutes;
@property(nonatomic, assign, readonly) NSInteger servings;
@property(nonatomic, assign, readonly) NSInteger calorieCount;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readonly) NSArray<MRRUserRecipePhotoSnapshot *> *photos;
@property(nonatomic, copy, readonly) NSArray<MRRUserRecipeIngredientSnapshot *> *ingredients;
@property(nonatomic, copy, readonly) NSArray<MRRUserRecipeInstructionSnapshot *> *instructions;
@property(nonatomic, copy, readonly) NSArray<MRRUserRecipeStringSnapshot *> *tools;
@property(nonatomic, copy, readonly) NSArray<MRRUserRecipeStringSnapshot *> *tags;
@property(nonatomic, retain, readonly) NSDate *createdAt;
@property(nonatomic, retain, readonly) NSDate *localModifiedAt;
@property(nonatomic, retain, readonly, nullable) NSDate *remoteUpdatedAt;

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                   summaryText:(NSString *)summaryText
                      mealType:(NSString *)mealType
                readyInMinutes:(NSInteger)readyInMinutes
                      servings:(NSInteger)servings
                  calorieCount:(NSInteger)calorieCount
                     assetName:(NSString *)assetName
              heroImageURLString:(nullable NSString *)heroImageURLString
                         photos:(NSArray<MRRUserRecipePhotoSnapshot *> *)photos
                   ingredients:(NSArray<MRRUserRecipeIngredientSnapshot *> *)ingredients
                  instructions:(NSArray<MRRUserRecipeInstructionSnapshot *> *)instructions
                         tools:(NSArray<MRRUserRecipeStringSnapshot *> *)tools
                          tags:(NSArray<MRRUserRecipeStringSnapshot *> *)tags
                     createdAt:(NSDate *)createdAt
               localModifiedAt:(NSDate *)localModifiedAt
               remoteUpdatedAt:(nullable NSDate *)remoteUpdatedAt;

+ (instancetype)snapshotWithUserID:(NSString *)userID
                        recipeCard:(HomeRecipeCard *)recipeCard
                      recipeDetail:(OnboardingRecipeDetail *)recipeDetail
                         createdAt:(NSDate *)createdAt
                   localModifiedAt:(NSDate *)localModifiedAt;
+ (NSString *)normalizedMealTypeFromString:(NSString *)mealType;
+ (NSString *)defaultAssetName;
- (nullable MRRUserRecipePhotoSnapshot *)coverPhotoSnapshot;
- (NSArray<NSString *> *)remotePhotoURLStrings;
- (OnboardingRecipeDetail *)recipeDetailRepresentation;
- (NSString *)sectionIdentifier;
- (NSString *)sectionTitle;
- (NSString *)durationText;
- (NSString *)calorieText;
- (NSString *)servingsText;

@end

NS_ASSUME_NONNULL_END
