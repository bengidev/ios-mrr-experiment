#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Onboarding/Data/OnboardingRecipeService.h"

typedef void (^OnboardingRecipeServiceURLHandler)(NSURLRequest *request,
                                                  NSHTTPURLResponse *__autoreleasing *response,
                                                  NSData *__autoreleasing *data,
                                                  NSError *__autoreleasing *error);

@interface OnboardingRecipeServiceURLProtocol : NSURLProtocol

+ (void)setHandler:(nullable OnboardingRecipeServiceURLHandler)handler;

@end

@implementation OnboardingRecipeServiceURLProtocol

static OnboardingRecipeServiceURLHandler OnboardingRecipeServiceURLProtocolHandler = nil;

+ (void)setHandler:(OnboardingRecipeServiceURLHandler)handler {
  OnboardingRecipeServiceURLProtocolHandler = [handler copy];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
  NSString *scheme = request.URL.scheme.lowercaseString;
  return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
  return request;
}

- (void)startLoading {
  if (OnboardingRecipeServiceURLProtocolHandler == nil) {
    NSError *error = [NSError errorWithDomain:@"OnboardingRecipeServiceTests" code:1 userInfo:nil];
    [self.client URLProtocol:self didFailWithError:error];
    return;
  }

  NSHTTPURLResponse *response = nil;
  NSData *data = nil;
  NSError *error = nil;
  OnboardingRecipeServiceURLProtocolHandler(self.request, &response, &data, &error);

  if (error != nil) {
    [self.client URLProtocol:self didFailWithError:error];
    return;
  }

  if (response == nil) {
    response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                           statusCode:200
                                          HTTPVersion:@"HTTP/1.1"
                                         headerFields:@{@"Content-Type" : @"application/json"}];
  }

  [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
  if (data != nil) {
    [self.client URLProtocol:self didLoadData:data];
  }
  [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
}

@end

@interface OnboardingRecipeServiceTests : XCTestCase

@property(nonatomic, strong) NSURLSession *session;

@end

@implementation OnboardingRecipeServiceTests

- (void)setUp {
  [super setUp];

  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  configuration.protocolClasses = @[ OnboardingRecipeServiceURLProtocol.class ];
  self.session = [NSURLSession sessionWithConfiguration:configuration];
  [OnboardingRecipeServiceURLProtocol setHandler:nil];
}

- (void)tearDown {
  [OnboardingRecipeServiceURLProtocol setHandler:nil];
  [self.session invalidateAndCancel];
  self.session = nil;

  [super tearDown];
}

- (void)testFetchRecipeDetailPrefersExactCaseInsensitiveTitleMatch {
  __block NSInteger spoonacularCallCount = 0;
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    spoonacularCallCount += 1;
    XCTAssertEqualObjects(request.URL.host, @"api.spoonacular.com");
    *data = [self JSONDataFromObject:@{
      @"results" : @[
        [self recipeCandidateWithTitle:@"Avocado Toast Supreme" summaryHTML:@"<b>Starts with the same words.</b>" readyInMinutes:@25 calories:@420],
        [self recipeCandidateWithTitle:@"AVOCADO TOAST" summaryHTML:@"<b>Exact winner.</b>" readyInMinutes:@8 calories:@260]
      ]
    }];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"recipe detail"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;
  __block NSError *resolvedError = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Avocado Toast" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         resolvedDetail = detail;
                         resolvedError = error;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertNil(resolvedError);
  XCTAssertEqual(spoonacularCallCount, 1);
  XCTAssertEqualObjects(resolvedDetail.title, @"AVOCADO TOAST");
  XCTAssertEqualObjects(resolvedDetail.summaryText, @"Exact winner.");
  XCTAssertEqualObjects(resolvedDetail.durationText, @"8 min");
  XCTAssertEqualObjects(resolvedDetail.calorieText, @"260 kcal");
}

- (void)testFetchRecipeDetailUsesNormalizedTitleMatchBeforePrefixMatch {
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    XCTAssertEqualObjects(request.URL.host, @"api.spoonacular.com");
    *data = [self JSONDataFromObject:@{
      @"results" : @[
        [self recipeCandidateWithTitle:@"Avocado Toast with Egg" summaryHTML:@"<b>Prefix only.</b>" readyInMinutes:@14 calories:@390],
        [self recipeCandidateWithTitle:@"Avocado-Toast" summaryHTML:@"<b>Normalized exact winner.</b>" readyInMinutes:@11 calories:@310]
      ]
    }];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"normalized match"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Avocado Toast" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(error);
                         resolvedDetail = detail;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqualObjects(resolvedDetail.title, @"Avocado-Toast");
  XCTAssertEqualObjects(resolvedDetail.summaryText, @"Normalized exact winner.");
}

- (void)testFetchRecipeDetailReturnsNoMatchErrorWhenNoCandidatesExist {
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    *data = [self JSONDataFromObject:@{@"results" : @[]}];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"no match"];
  __block NSError *resolvedError = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Missing Recipe" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(detail);
                         resolvedError = error;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqualObjects(resolvedError.domain, MRROnboardingRecipeSearchErrorDomain);
  XCTAssertEqual(resolvedError.code, MRROnboardingRecipeSearchErrorCodeNoMatch);
}

- (void)testFetchRecipeDetailReturnsInvalidResponseForMalformedPayload {
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    *data = [@"not-json" dataUsingEncoding:NSUTF8StringEncoding];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"invalid response"];
  __block NSError *resolvedError = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Avocado Toast" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(detail);
                         resolvedError = error;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqualObjects(resolvedError.domain, MRROnboardingRecipeSearchErrorDomain);
  XCTAssertEqual(resolvedError.code, MRROnboardingRecipeSearchErrorCodeInvalidResponse);
}

- (void)testFetchRecipeDetailFallsBackToCuratedSummaryWhenLiveSummaryIsNoisy {
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    *data = [self JSONDataFromObject:@{
      @"results" : @[ [self recipeCandidateWithTitle:@"Beef Bourguignon"
                                         summaryHTML:@"<p>Beef Bourguignon might be a good recipe to expand your main course recipe box. This recipe serves 8. One portion of this dish contains around 39g of protein, 21g of fat, and 406 calories. It is brought to you by Foodista. Taking all factors into account, this recipe earns a spoonacular score of 58%. If you like this recipe, take a look at these similar recipes: Beef bourguignon.</p>"
                                      readyInMinutes:@45
                                            calories:@406] ]
    }];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"fallback summary"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Beef Bourguignon" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(error);
                         resolvedDetail = detail;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqualObjects(resolvedDetail.summaryText, @"Fallback summary.");
}

- (void)testFetchRecipeDetailMapsToolsAndTagsFromSpoonacularResponse {
  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    *data = [self JSONDataFromObject:@{
      @"results" : @[
        @{
          @"title" : @"Coconut Curry Ramen Noodles",
          @"summary" : @"<p>Rich broth with bright herbs.</p>",
          @"image" : @"https://img.example.com/recipe.jpg",
          @"readyInMinutes" : @35,
          @"servings" : @3,
          @"sourceName" : @"Culina Source",
          @"sourceUrl" : @"https://example.com/recipe",
          @"dishTypes" : @[ @"dinner", @"lunch" ],
          @"diets" : @[ @"vegan" ],
          @"cuisines" : @[ @"japanese" ],
          @"extendedIngredients" : @[
            @{@"name" : @"tofu", @"original" : @"200 g tofu"},
            @{@"name" : @"coconut milk", @"original" : @"400 ml coconut milk"}
          ],
          @"analyzedInstructions" : @[
            @{
              @"steps" : @[
                @{
                  @"number" : @1,
                  @"step" : @"Prep the broth.",
                  @"equipment" : @[
                    @{@"name" : @"knife"},
                    @{@"localizedName" : @"large stockpot"}
                  ]
                },
                @{
                  @"number" : @2,
                  @"step" : @"Simmer the noodles.",
                  @"equipment" : @[
                    @{@"name" : @"knife"},
                    @{@"name" : @"measuring spoons"}
                  ]
                }
              ]
            }
          ],
          @"nutrition" : @{@"nutrients" : @[ @{@"name" : @"Calories", @"amount" : @480} ]}
        }
      ]
    }];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"tools and tags"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:nil]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Coconut Curry Ramen Noodles" barcode:nil]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(error);
                         resolvedDetail = detail;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqualObjects(resolvedDetail.tools, (@[ @"Knife", @"Large Stockpot", @"Measuring Spoons" ]));
  XCTAssertEqualObjects(resolvedDetail.tags, (@[ @"Dinner", @"Vegan", @"Japanese" ]));
}

- (void)testFetchRecipeDetailAddsOpenFoodFactsProductContextWhenBarcodeExists {
  __block NSInteger spoonacularCallCount = 0;
  __block NSInteger openFoodFactsCallCount = 0;
  __block NSString *capturedUserAgent = nil;

  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    if ([request.URL.host isEqualToString:@"api.spoonacular.com"]) {
      spoonacularCallCount += 1;
      *data = [self JSONDataFromObject:@{
        @"results" : @[ [self recipeCandidateWithTitle:@"Green Curry" summaryHTML:@"<p>Fresh and fragrant.</p>" readyInMinutes:@28 calories:@470] ]
      }];
      return;
    }

    XCTAssertEqualObjects(request.URL.host, @"world.openfoodfacts.org");
    openFoodFactsCallCount += 1;
    capturedUserAgent = [request valueForHTTPHeaderField:@"User-Agent"];
    *data = [self JSONDataFromObject:@{
      @"product" : @{
        @"product_name" : @"Organic Coconut Milk",
        @"brands" : @"Thai Kitchen",
        @"quantity" : @"400 ml",
        @"nutrition_grades" : @"b"
      }
    }];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"product context"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:@"culina/1.0 (hello@example.com)"]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Green Curry" barcode:@"3017624010701"]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(error);
                         resolvedDetail = detail;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqual(spoonacularCallCount, 1);
  XCTAssertEqual(openFoodFactsCallCount, 1);
  XCTAssertEqualObjects(capturedUserAgent, @"culina/1.0 (hello@example.com)");
  XCTAssertEqualObjects(resolvedDetail.productContext.productName, @"Organic Coconut Milk");
  XCTAssertEqualObjects(resolvedDetail.productContext.brandText, @"Thai Kitchen");
  XCTAssertEqualObjects(resolvedDetail.productContext.quantityText, @"400 ml");
  XCTAssertEqualObjects(resolvedDetail.productContext.nutritionGradeText, @"B");
}

- (void)testFetchRecipeDetailIgnoresOpenFoodFactsFailureAndOmitsProductContext {
  __block NSInteger spoonacularCallCount = 0;
  __block NSInteger openFoodFactsCallCount = 0;

  [OnboardingRecipeServiceURLProtocol setHandler:^(NSURLRequest *request,
                                                   NSHTTPURLResponse *__autoreleasing *response,
                                                   NSData *__autoreleasing *data,
                                                   NSError *__autoreleasing *error) {
    if ([request.URL.host isEqualToString:@"api.spoonacular.com"]) {
      spoonacularCallCount += 1;
      *data = [self JSONDataFromObject:@{
        @"results" : @[ [self recipeCandidateWithTitle:@"Pizza Night" summaryHTML:@"<p>Still succeeds.</p>" readyInMinutes:@32 calories:@610] ]
      }];
      return;
    }

    openFoodFactsCallCount += 1;
    *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"off failure omission"];
  __block OnboardingRecipeDetail *resolvedDetail = nil;

  [[self makeRecipeSearcherWithSpoonacularKey:@"spoon-key" openFoodFactsUserAgent:@"culina/1.0 (hello@example.com)"]
      fetchRecipeDetailForPreview:[self previewWithTitle:@"Pizza Night" barcode:@"3017624010701"]
                       completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                         XCTAssertNil(error);
                         resolvedDetail = detail;
                         [expectation fulfill];
                       }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  XCTAssertEqual(spoonacularCallCount, 1);
  XCTAssertEqual(openFoodFactsCallCount, 1);
  XCTAssertNotNil(resolvedDetail);
  XCTAssertNil(resolvedDetail.productContext);
}

- (id<MRROnboardingRecipeSearching>)makeRecipeSearcherWithSpoonacularKey:(NSString *)spoonacularKey
                                                  openFoodFactsUserAgent:(NSString *)openFoodFactsUserAgent {
  MRRRecipeAPIConfiguration *configuration = [[MRRRecipeAPIConfiguration alloc] initWithSpoonacularAPIKey:spoonacularKey
                                                                                   openFoodFactsUserAgent:openFoodFactsUserAgent];
  return [[MRRRemoteOnboardingRecipeSearcher alloc] initWithSession:self.session configuration:configuration];
}

- (OnboardingRecipePreview *)previewWithTitle:(NSString *)title barcode:(nullable NSString *)barcode {
  OnboardingRecipeIngredient *ingredient = [[OnboardingRecipeIngredient alloc] initWithName:@"Bread" displayText:@"2 slices bread"];
  OnboardingRecipeInstruction *instruction =
      [[OnboardingRecipeInstruction alloc] initWithTitle:@"Toast" detailText:@"Toast until golden."];
  OnboardingRecipeDetail *fallbackDetail = [[OnboardingRecipeDetail alloc] initWithTitle:title
                                                                                subtitle:@"Fallback"
                                                                               assetName:@"avocado-toast"
                                                                      heroImageURLString:nil
                                                                            durationText:@"10 min"
                                                                             calorieText:@"280 kcal"
                                                                            servingsText:@"2 servings"
                                                                             summaryText:@"Fallback summary."
                                                                             ingredients:@[ ingredient ]
                                                                            instructions:@[ instruction ]
                                                                                   tools:@[]
                                                                                    tags:@[]
                                                                              sourceName:nil
                                                                         sourceURLString:nil
                                                                          productContext:nil];
  return [[OnboardingRecipePreview alloc] initWithTitle:title
                                               subtitle:@"Fallback"
                                              assetName:@"avocado-toast"
                                   openFoodFactsBarcode:barcode
                                         fallbackDetail:fallbackDetail];
}

- (NSDictionary *)recipeCandidateWithTitle:(NSString *)title
                               summaryHTML:(NSString *)summaryHTML
                            readyInMinutes:(NSNumber *)readyInMinutes
                                  calories:(NSNumber *)calories {
  return @{
    @"title" : title,
    @"summary" : summaryHTML,
    @"image" : @"https://img.example.com/recipe.jpg",
    @"readyInMinutes" : readyInMinutes,
    @"servings" : @2,
    @"sourceName" : @"Culina Source",
    @"sourceUrl" : @"https://example.com/recipe",
    @"extendedIngredients" : @[ @{@"name" : @"avocado", @"original" : @"1 ripe avocado"} ],
    @"analyzedInstructions" : @[ @{@"steps" : @[ @{@"number" : @1, @"step" : @"Mash the avocado."} ]} ],
    @"nutrition" : @{@"nutrients" : @[ @{@"name" : @"Calories", @"amount" : calories} ]}
  };
}

- (NSData *)JSONDataFromObject:(id)object {
  return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
}

@end
