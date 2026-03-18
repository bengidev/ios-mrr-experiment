#import <Foundation/Foundation.h>

#import "OnboardingRecipeModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^MRROnboardingRecipeDetailCompletion)(OnboardingRecipeDetail *_Nullable detail, NSError *_Nullable error);
typedef void (^MRROnboardingRecipeProductContextCompletion)(OnboardingRecipeProductContext *_Nullable productContext,
                                                            NSError *_Nullable error);

FOUNDATION_EXPORT NSErrorDomain const MRROnboardingRecipeSearchErrorDomain;

typedef NS_ENUM(NSInteger, MRROnboardingRecipeSearchErrorCode) {
  MRROnboardingRecipeSearchErrorCodeUnconfigured = 1,
  MRROnboardingRecipeSearchErrorCodeNoMatch = 2,
  MRROnboardingRecipeSearchErrorCodeInvalidResponse = 3,
  MRROnboardingRecipeSearchErrorCodeRequestFailed = 4,
};

@protocol MRROpenFoodFactsContextFetching <NSObject>

- (void)fetchProductContextForBarcode:(NSString *)barcode completion:(MRROnboardingRecipeProductContextCompletion)completion;

@end

@protocol MRROnboardingRecipeSearching <NSObject>

- (void)fetchRecipeDetailForPreview:(OnboardingRecipePreview *)preview completion:(MRROnboardingRecipeDetailCompletion)completion;

@end

@interface MRRRecipeAPIConfiguration : NSObject

@property(nonatomic, copy, readonly, nullable) NSString *spoonacularAPIKey;
@property(nonatomic, copy, readonly, nullable) NSString *openFoodFactsUserAgent;

- (instancetype)initWithSpoonacularAPIKey:(nullable NSString *)spoonacularAPIKey
                  openFoodFactsUserAgent:(nullable NSString *)openFoodFactsUserAgent;
+ (instancetype)configurationFromMainBundle;

@end

@interface MRRRemoteOnboardingRecipeSearcher : NSObject <MRROnboardingRecipeSearching>

- (instancetype)initWithSession:(NSURLSession *)session configuration:(MRRRecipeAPIConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
