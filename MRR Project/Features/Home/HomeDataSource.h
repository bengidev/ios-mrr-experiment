#import <Foundation/Foundation.h>

#import "../Onboarding/Data/OnboardingRecipeModels.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HomeSectionIdentifierRecommendation;
FOUNDATION_EXPORT NSString *const HomeSectionIdentifierWeekly;

FOUNDATION_EXPORT NSString *const HomeCategoryIdentifierBreakfast;
FOUNDATION_EXPORT NSString *const HomeCategoryIdentifierLunch;
FOUNDATION_EXPORT NSString *const HomeCategoryIdentifierDinner;
FOUNDATION_EXPORT NSString *const HomeCategoryIdentifierDessert;
FOUNDATION_EXPORT NSString *const HomeCategoryIdentifierSnack;

typedef NS_ENUM(NSInteger, HomeFilterOption) {
  HomeFilterOptionFeatured = 0,
  HomeFilterOptionFastest = 1,
  HomeFilterOptionPopular = 2,
  HomeFilterOptionLowCalorie = 3,
};

typedef NS_ENUM(NSInteger, HomeSearchState) {
  HomeSearchStateIdle = 0,
  HomeSearchStateSearching = 1,
  HomeSearchStateResults = 2,
  HomeSearchStateEmpty = 3,
};

@class HomeCategory;
@class HomeRecipeCard;
@class HomeSection;

typedef void (^HomeInitialSectionsCompletion)(NSArray<HomeSection *> *sections,
                                              NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier,
                                              BOOL usesLiveData);
typedef void (^HomeRecipeSearchCompletion)(NSArray<HomeRecipeCard *> *recipes, BOOL usesLiveData);
typedef void (^HomeRecipeDetailCompletion)(OnboardingRecipeDetail * _Nullable recipeDetail, BOOL usesLiveData);

@interface HomeCategory : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *badgeText;

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title badgeText:(NSString *)badgeText;

@end

@interface HomeRecipeCard : NSObject

@property(nonatomic, copy, readonly) NSString *recipeID;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *subtitle;
@property(nonatomic, copy, readonly) NSString *assetName;
@property(nonatomic, copy, readonly, nullable) NSString *imageURLString;
@property(nonatomic, copy, readonly) NSString *summaryText;
@property(nonatomic, assign, readonly) NSInteger readyInMinutes;
@property(nonatomic, assign, readonly) NSInteger servings;
@property(nonatomic, assign, readonly) NSInteger calorieCount;
@property(nonatomic, assign, readonly) NSInteger popularityScore;
@property(nonatomic, copy, readonly) NSString *sourceName;
@property(nonatomic, copy, readonly, nullable) NSString *sourceURLString;
@property(nonatomic, copy, readonly) NSString *mealType;
@property(nonatomic, copy, readonly) NSArray<NSString *> *tags;

- (instancetype)initWithRecipeID:(NSString *)recipeID
                           title:(NSString *)title
                        subtitle:(NSString *)subtitle
                       assetName:(NSString *)assetName
                  imageURLString:(nullable NSString *)imageURLString
                     summaryText:(NSString *)summaryText
                  readyInMinutes:(NSInteger)readyInMinutes
                        servings:(NSInteger)servings
                    calorieCount:(NSInteger)calorieCount
                 popularityScore:(NSInteger)popularityScore
                      sourceName:(NSString *)sourceName
                 sourceURLString:(nullable NSString *)sourceURLString
                        mealType:(NSString *)mealType
                            tags:(NSArray<NSString *> *)tags;

- (NSString *)durationText;
- (NSString *)calorieText;
- (NSString *)servingsText;

@end

@interface HomeSection : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSArray<HomeRecipeCard *> *recipes;

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title recipes:(NSArray<HomeRecipeCard *> *)recipes;

@end

@protocol HomeDataProviding <NSObject>

- (NSArray<HomeCategory *> *)availableCategories;
- (void)loadInitialSectionsForFilterOption:(HomeFilterOption)filterOption completion:(HomeInitialSectionsCompletion)completion;
- (void)searchRecipes:(NSString *)query
                limit:(NSUInteger)limit
         filterOption:(HomeFilterOption)filterOption
           completion:(HomeRecipeSearchCompletion)completion;
- (void)loadRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard completion:(HomeRecipeDetailCompletion)completion;

@end

@interface HomeMockDataProvider : NSObject <HomeDataProviding>

- (NSArray<HomeSection *> *)featuredSections;
- (NSArray<HomeRecipeCard *> *)recipesForCategory:(nullable HomeCategory *)category;
- (NSArray<HomeRecipeCard *> *)searchRecipes:(NSString *)query;
- (nullable OnboardingRecipeDetail *)recipeDetailForID:(NSString *)recipeID;

@end

@interface HomeCompositeDataProvider : NSObject <HomeDataProviding>

- (instancetype)init;
- (instancetype)initWithAPIKey:(nullable NSString *)apiKey
                    URLSession:(nullable NSURLSession *)URLSession
          fallbackDataProvider:(nullable HomeMockDataProvider *)fallbackDataProvider NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
